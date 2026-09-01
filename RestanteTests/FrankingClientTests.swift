import XCTest
@testable import Restante

private struct ProbeDTO: Decodable {
    var energy: OptionalMeasure
}

private actor PlaybackLink: OutboundLink {
    private var results: [Result<(Data, URLResponse), Error>]
    private var log: [URLRequest] = []

    init(results: [Result<(Data, URLResponse), Error>]) {
        self.results = results
    }

    func exchange(_ request: URLRequest) async throws -> (Data, URLResponse) {
        log.append(request)
        guard !results.isEmpty else { throw URLError(.cannotConnectToHost) }
        return try results.removeFirst().get()
    }

    func recorded() -> [URLRequest] { log }
}

final class FrankingClientTests: XCTestCase {
    private let url = URL(string: "https://restante.pro/probe")!

    func test_setsUserAgentOnEveryRequest() async throws {
        let link = PlaybackLink(results: [
            .success((Data("{\"energy\":1}".utf8), http(200))),
        ])
        let client = FrankingClient(link: link)
        _ = try await client.pull(ProbeDTO.self, from: url)
        let request = await link.recorded().first
        XCTAssertEqual(request?.value(forHTTPHeaderField: "User-Agent"), FrankingClient.userAgent)
        XCTAssertEqual(request?.timeoutInterval, 15)
    }

    func test_retriesTransientTransportOnce() async throws {
        let link = PlaybackLink(results: [
            .failure(URLError(.timedOut)),
            .success((Data("{\"energy\":\"4.5\"}".utf8), http(200))),
        ])
        let client = FrankingClient(link: link)
        let dto = try await client.pull(ProbeDTO.self, from: url)
        XCTAssertEqual(dto.energy.amount, 4.5)
        let count = await link.recorded().count
        XCTAssertEqual(count, 2)
    }

    func test_doesNotRetry404() async {
        let link = PlaybackLink(results: [
            .success((Data(), http(404))),
            .success((Data("{\"energy\":1}".utf8), http(200))),
        ])
        let client = FrankingClient(link: link)
        do {
            _ = try await client.pull(ProbeDTO.self, from: url)
            XCTFail("expected missing")
        } catch {
            XCTAssertEqual(error as? FrankingFault, .missing)
        }
        let count = await link.recorded().count
        XCTAssertEqual(count, 1)
    }

    func test_malformedJSONIsGarbled() async {
        let link = PlaybackLink(results: [
            .success((Data("{".utf8), http(200))),
        ])
        let client = FrankingClient(link: link)
        do {
            _ = try await client.pull(ProbeDTO.self, from: url)
            XCTFail("expected garbled")
        } catch {
            XCTAssertEqual(error as? FrankingFault, .garbled)
        }
    }

    func test_optionalMeasureAcceptsNumberAndString() throws {
        let number = try JSONDecoder().decode(ProbeDTO.self, from: Data("{\"energy\":12.5}".utf8))
        let string = try JSONDecoder().decode(ProbeDTO.self, from: Data("{\"energy\":\"12.5\"}".utf8))
        let missing = try JSONDecoder().decode(ProbeDTO.self, from: Data("{\"energy\":null}".utf8))
        XCTAssertEqual(number.energy.amount, 12.5)
        XCTAssertEqual(string.energy.amount, 12.5)
        XCTAssertNil(missing.energy.amount)
    }

    private func http(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}
