import XCTest
@testable import Restante

final class RestanteTests: XCTestCase {
    func test_clockworkTypesArePresent() {
        XCTAssertEqual(Fusee.floorHours, 6)
        XCTAssertEqual(Fusee.ceilingHours, 720)
        XCTAssertEqual(FrankingClient.userAgent, "Restante/1.0 (iOS; +https://restante.pro)")
        XCTAssertEqual(PostageKey.demoSeed, "rst.demo.v1")
        XCTAssertEqual(PostageArt.emptyHome, "rst_EmptyHome")
        XCTAssertEqual(PostageArt.twist, "rst_TwistHero")
    }
}
