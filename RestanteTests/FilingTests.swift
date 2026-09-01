import XCTest
@testable import Restante

final class FilingTests: XCTestCase {
    func test_fileWant_emptyPopulatedInvalid() throws {
        let calendar = gmtCalendar()
        let regulator = Regulator(
            weekday: 6,
            intervalDays: 7,
            monthlyImpulseLimit: 400,
            anchorPayday: Horology.instant(from: date(2026, 1, 2, calendar: calendar))
        )
        let filedAt = Horology.instant(from: date(2026, 1, 5, 12, calendar: calendar))

        XCTAssertThrowsError(
            try Filing.mainspring(
                title: "   ",
                price: 40,
                necessity: 20,
                discretion: 20,
                priority: 1,
                at: filedAt,
                regulator: regulator,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? CarriageError, .emptyTitle)
        }

        let held = try Filing.mainspring(
            title: "  Held letter  ",
            price: 80,
            necessity: 25,
            discretion: 40,
            priority: 1,
            at: filedAt,
            regulator: regulator,
            calendar: calendar
        )
        XCTAssertEqual(held.title, "Held letter")
        XCTAssertGreaterThan(held.coolingHours, 0)
        XCTAssertEqual(held.phase(at: filedAt), .cooling)
        XCTAssertGreaterThan(held.unlockAt, filedAt)

        XCTAssertThrowsError(
            try Filing.mainspring(
                title: "Bad",
                price: -4,
                necessity: 20,
                discretion: 20,
                priority: 1,
                at: filedAt,
                regulator: regulator,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? CarriageError, .invalidPrice)
        }
        XCTAssertThrowsError(
            try Filing.mainspring(
                title: "Bad",
                price: 40,
                necessity: 140,
                discretion: 20,
                priority: 1,
                at: filedAt,
                regulator: regulator,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? CarriageError, .invalidNecessity)
        }
        XCTAssertThrowsError(
            try Filing.mainspring(
                title: "Bad",
                price: 40,
                necessity: 20,
                discretion: 20,
                priority: 0,
                at: filedAt,
                regulator: regulator,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? CarriageError, .invalidPriority)
        }
    }

    func test_regulatorRejectsBadLimitAndWeekday() {
        XCTAssertThrowsError(
            try Regulation.validated(
                Regulator(weekday: 9, intervalDays: 7, monthlyImpulseLimit: 100, anchorPayday: 0)
            )
        ) { error in
            XCTAssertEqual(error as? CarriageError, .invalidWeekday)
        }
        XCTAssertThrowsError(
            try Regulation.validated(
                Regulator(weekday: 6, intervalDays: 7, monthlyImpulseLimit: 0, anchorPayday: 0)
            )
        ) { error in
            XCTAssertEqual(error as? CarriageError, .invalidLimit)
        }
    }
}
