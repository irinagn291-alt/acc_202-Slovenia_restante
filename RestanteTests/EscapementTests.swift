import XCTest
@testable import Restante

/// Twist: computed hours snap forward to the next payday, never a fixed 24h/7d timer.
final class EscapementTests: XCTestCase {
    func test_snapMovesUnlockToNextPayday() throws {
        let calendar = gmtCalendar()
        let filed = date(2026, 1, 5, 12, calendar: calendar)
        let regulator = Regulator(
            weekday: 6,
            intervalDays: 7,
            monthlyImpulseLimit: 10_000,
            anchorPayday: Horology.instant(from: date(2026, 1, 2, calendar: calendar))
        )
        let want = try Filing.mainspring(
            title: "Held letter",
            price: 1,
            necessity: 100,
            discretion: 100,
            priority: 1,
            at: Horology.instant(from: filed),
            regulator: regulator,
            calendar: calendar
        )
        XCTAssertEqual(want.coolingHours, 6)
        let payday = date(2026, 1, 9, calendar: calendar)
        XCTAssertEqual(want.unlockAt, Horology.instant(from: payday), accuracy: 0.5)
        let remaining = want.remainingHours(at: Horology.instant(from: filed))
        XCTAssertEqual(remaining, 84, accuracy: 0.01)
        XCTAssertNotEqual(remaining, 24)
        XCTAssertNotEqual(remaining, 168)
        XCTAssertNotEqual(remaining, 6)
    }

    func test_biweeklyAnchorSkipsTheInBetweenFriday() {
        let calendar = gmtCalendar()
        let regulator = Regulator(
            weekday: 6,
            intervalDays: 14,
            monthlyImpulseLimit: 400,
            anchorPayday: Horology.instant(from: date(2026, 1, 2, calendar: calendar))
        )
        let raw = Horology.instant(from: date(2026, 1, 5, 18, calendar: calendar))
        let snapped = Escapement.snap(rawUnlock: raw, regulator: regulator, calendar: calendar)
        XCTAssertEqual(snapped, Horology.instant(from: date(2026, 1, 16, calendar: calendar)), accuracy: 0.5)
    }
}
