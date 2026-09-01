import XCTest
@testable import Restante

/// Family invariant: base from price vs monthly limit; clamp 6…720; not a 24h/7d timer.
final class FuseeTests: XCTestCase {
    func test_hoursFollowPriceLimitPriorityNecessityDiscretion() throws {
        let hours = try Fusee.coolingHours(
            price: 100,
            monthlyLimit: 400,
            priority: 1,
            necessity: 50,
            discretion: 50
        )
        XCTAssertEqual(hours, 270, accuracy: 0.0001)

        let base = try Fusee.baseHours(price: 100, monthlyLimit: 400)
        XCTAssertEqual(base, 180, accuracy: 0.0001)
        XCTAssertEqual(
            base * 1 * (1.5 - 50.0 / 100) * (2 - 50.0 / 100),
            270,
            accuracy: 0.0001
        )
    }

    func test_higherPriceLengthensWait() throws {
        let cheap = try Fusee.coolingHours(
            price: 40,
            monthlyLimit: 400,
            priority: 1,
            necessity: 40,
            discretion: 40
        )
        let dear = try Fusee.coolingHours(
            price: 200,
            monthlyLimit: 400,
            priority: 1,
            necessity: 40,
            discretion: 40
        )
        XCTAssertGreaterThan(dear, cheap)
        XCTAssertNotEqual(cheap, 24)
        XCTAssertNotEqual(cheap, 168)
        XCTAssertNotEqual(dear, 24)
        XCTAssertNotEqual(dear, 168)
    }

    func test_clampSixToSevenHundredTwenty() throws {
        let floor = try Fusee.coolingHours(
            price: 1,
            monthlyLimit: 10_000,
            priority: 1,
            necessity: 100,
            discretion: 100
        )
        XCTAssertEqual(floor, Fusee.floorHours)

        let ceiling = try Fusee.coolingHours(
            price: 240,
            monthlyLimit: 480,
            priority: 1.2,
            necessity: 20,
            discretion: 40
        )
        XCTAssertEqual(ceiling, Fusee.ceilingHours)
    }

    func test_necessityAndDiscretionScaleTheSpan() throws {
        let lowNeed = try Fusee.coolingHours(
            price: 80,
            monthlyLimit: 400,
            priority: 1,
            necessity: 0,
            discretion: 0
        )
        let highNeed = try Fusee.coolingHours(
            price: 80,
            monthlyLimit: 400,
            priority: 1,
            necessity: 100,
            discretion: 100
        )
        XCTAssertGreaterThan(lowNeed, highNeed)
    }
}
