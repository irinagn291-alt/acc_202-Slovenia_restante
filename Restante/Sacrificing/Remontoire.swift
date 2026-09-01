import Foundation

/// Role: Domain. Result of sacrificing one cooling mainspring so another can strike.
struct RemontoireResult: Equatable, Sendable {
    var advanced: Mainspring
    var sacrificed: Mainspring
    var sacrifice: Strike
}

/// Role: Domain (owned by Controls). Buy early only by covering the payday gap.
enum Remontoire {
    static func covers(
        gapOf target: Mainspring,
        with donor: Mainspring,
        at instant: TimeInterval
    ) -> Bool {
        guard target.halt == nil, donor.halt == nil else { return false }
        guard target.id != donor.id else { return false }
        guard target.phase(at: instant) == .cooling else { return false }
        guard donor.phase(at: instant) == .cooling else { return false }
        let gap = target.remainingHours(at: instant)
        return donor.remainingHours(at: instant) >= gap
    }

    static func advance(
        _ target: Mainspring,
        sacrificing donor: Mainspring,
        at instant: TimeInterval
    ) throws -> RemontoireResult {
        guard target.id != donor.id else { throw CarriageError.sameMainspring }
        guard target.halt == nil else { throw CarriageError.alreadyHalted }
        guard donor.halt == nil else { throw CarriageError.alreadyHalted }
        guard target.phase(at: instant) == .cooling else { throw CarriageError.alreadyOpen }
        guard donor.phase(at: instant) == .cooling else { throw CarriageError.donorNotCooling }
        let gap = target.remainingHours(at: instant)
        guard donor.remainingHours(at: instant) >= gap else { throw CarriageError.gapNotCovered }

        var advanced = target
        advanced.unlockAt = instant

        var sacrificed = donor
        sacrificed.halt = .sacrificed
        sacrificed.unlockAt = instant

        let sacrifice = Strike(
            id: UUID(),
            mainspringID: donor.id,
            title: donor.title,
            price: donor.price,
            kind: .sacrificed,
            struckAt: instant,
            remainingHours: donor.remainingHours(at: instant)
        )
        return RemontoireResult(advanced: advanced, sacrificed: sacrificed, sacrifice: sacrifice)
    }
}
