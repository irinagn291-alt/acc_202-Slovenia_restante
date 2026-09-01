import Foundation

/// Role: Network. Typed transport failures. This product has no remote catalog.
enum FrankingFault: Error, Equatable, Sendable {
    case missing
    case garbled
    case dropped
    case withdrawn
    case oddReply
}

/// Role: Network. Sends one HTTP request. Injected so tests never hit the wire.
protocol OutboundLink: Sendable {
    func exchange(_ request: URLRequest) async throws -> (Data, URLResponse)
}

/// Role: Network. URLSession link with a 15 s timeout and this app's User-Agent.
struct SessionLink: OutboundLink {
    let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 15
        configuration.httpAdditionalHeaders = ["User-Agent": FrankingClient.userAgent]
        self.session = URLSession(configuration: configuration)
    }

    func exchange(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

/// Role: Network. Accepts a JSON number or a numeric string. Missing stays nil.
struct OptionalMeasure: Sendable, Equatable {
    var amount: Double?
}

extension OptionalMeasure: Decodable {
    init(from decoder: Decoder) throws {
        let box = try decoder.singleValueContainer()
        if box.decodeNil() {
            amount = nil
            return
        }
        if let number = try? box.decode(Double.self) {
            amount = number
            return
        }
        if let whole = try? box.decode(Int.self) {
            amount = Double(whole)
            return
        }
        if let text = try? box.decode(String.self) {
            amount = Double(text)
            return
        }
        amount = nil
    }
}

/// Role: Network. Owns URLSession. Offline product; this is the transport seam only.
actor FrankingClient {
    static let userAgent = "Restante/1.0 (iOS; +https://restante.pro)"

    private let link: any OutboundLink

    init(link: any OutboundLink) {
        self.link = link
    }

    init() {
        self.link = SessionLink()
    }

    func pull<DTO: Decodable>(_ type: DTO.Type, from url: URL) async throws -> DTO {
        try Task.checkCancellation()
        let body = try await deliver(stamped(url))
        do {
            return try JSONDecoder().decode(DTO.self, from: body)
        } catch is CancellationError {
            throw FrankingFault.withdrawn
        } catch {
            throw FrankingFault.garbled
        }
    }

    private func stamped(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private func deliver(_ request: URLRequest) async throws -> Data {
        var last: Error = FrankingFault.dropped
        for attempt in 1 ... 2 {
            do {
                return try await hop(request)
            } catch let fault as FrankingFault {
                throw fault
            } catch is CancellationError {
                throw FrankingFault.withdrawn
            } catch {
                if withdrawn(error) { throw FrankingFault.withdrawn }
                last = error
                if attempt == 1, transient(error) {
                    continue
                }
                throw FrankingFault.dropped
            }
        }
        throw last as? FrankingFault ?? FrankingFault.dropped
    }

    private func hop(_ request: URLRequest) async throws -> Data {
        try Task.checkCancellation()
        let (body, reply) = try await link.exchange(request)
        guard let http = reply as? HTTPURLResponse else {
            throw FrankingFault.oddReply
        }
        if http.statusCode == 404 {
            throw FrankingFault.missing
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw FrankingFault.dropped
        }
        return body
    }
}

private func transient(_ error: Error) -> Bool {
    guard let urlError = error as? URLError else { return false }
    switch urlError.code {
    case .timedOut, .networkConnectionLost, .notConnectedToInternet,
         .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
        return true
    default:
        return false
    }
}

private func withdrawn(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    return (error as? URLError)?.code == .cancelled
}
