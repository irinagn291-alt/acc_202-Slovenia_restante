import XCTest
@testable import Restante

/// Buy early only by sacrificing another cooling want whose remaining hours cover the gap.
final class RemontoireTests: XCTestCase {
    private let now: TimeInterval = 10_000

    func test_cannotStrikeWhileCooling() {
        let held = cooling(unlockAt: now + Horology.interval(hours: 80))
        XCTAssertEqual(held.phase(at: now), .cooling)
        XCTAssertThrowsError(try Releasing.strike(held, as: .bought, at: now)) { error in
            XCTAssertEqual(error as? CarriageError, .stillCooling)
        }
    }

    func test_donorMustCoverThePaydayGap() {
        let longWait = cooling(id: UUID(), unlockAt: now + Horology.interval(hours: 200))
        let shortWait = cooling(id: UUID(), unlockAt: now + Horology.interval(hours: 50))
        XCTAssertFalse(Remontoire.covers(gapOf: longWait, with: shortWait, at: now))
        XCTAssertTrue(Remontoire.covers(gapOf: shortWait, with: longWait, at: now))
        XCTAssertThrowsError(try Remontoire.advance(longWait, sacrificing: shortWait, at: now)) { error in
            XCTAssertEqual(error as? CarriageError, .gapNotCovered)
        }
    }

    func test_sacrificeOpensTheGateThenStrikeWorks() throws {
        let target = cooling(id: UUID(), title: "Desk", unlockAt: now + Horology.interval(hours: 40))
        let donor = cooling(id: UUID(), title: "Lamp", unlockAt: now + Horology.interval(hours: 90))
        let result = try Remontoire.advance(target, sacrificing: donor, at: now)
        XCTAssertEqual(result.advanced.phase(at: now), .open)
        XCTAssertEqual(result.sacrificed.phase(at: now), .sacrificed)
        XCTAssertEqual(result.sacrifice.kind, .sacrificed)
        let (struck, record) = try Releasing.strike(result.advanced, as: .bought, at: now)
        XCTAssertEqual(struck.halt, .struck)
        XCTAssertEqual(record.kind, .bought)
    }

    func test_rejectsSelfAndHaltedDonor() {
        let target = cooling(unlockAt: now + Horology.interval(hours: 20))
        XCTAssertThrowsError(try Remontoire.advance(target, sacrificing: target, at: now)) { error in
            XCTAssertEqual(error as? CarriageError, .sameMainspring)
        }
        var halted = cooling(id: UUID(), unlockAt: now + Horology.interval(hours: 80))
        halted.halt = .struck
        XCTAssertThrowsError(try Remontoire.advance(target, sacrificing: halted, at: now)) { error in
            XCTAssertEqual(error as? CarriageError, .alreadyHalted)
        }
    }

    private func cooling(
        id: UUID = UUID(),
        title: String = "Want",
        unlockAt: TimeInterval
    ) -> Mainspring {
        Mainspring(
            id: id,
            title: title,
            price: 40,
            necessity: 40,
            discretion: 40,
            priority: 1,
            filedAt: now - 100,
            coolingHours: 80,
            unlockAt: unlockAt,
            halt: nil
        )
    }
}
