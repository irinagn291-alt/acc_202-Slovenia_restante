import Foundation

/// Role: Domain. Terminal halt of a held want. Cooling versus open is derived from payday.
enum Halt: String, Sendable, Hashable, Codable {
    case struck
    case sacrificed
}

/// Role: Domain. Wait phase shown on the pendulum. Presentations never compute this.
enum WaitPhase: String, Sendable, Hashable {
    case cooling
    case open
    case struck
    case sacrificed
}

/// Role: Domain. A filed want. Named Mainspring per the clockmaker lexicon.
struct Mainspring: Identifiable, Hashable, Sendable, Equatable {
    var id: UUID
    var title: String
    var price: Double
    var necessity: Double
    var discretion: Double
    var priority: Double
    var filedAt: TimeInterval
    var coolingHours: Double
    var unlockAt: TimeInterval
    var halt: Halt?

    func phase(at instant: TimeInterval) -> WaitPhase {
        switch halt {
        case .struck:
            return .struck
        case .sacrificed:
            return .sacrificed
        case nil:
            return instant >= unlockAt ? .open : .cooling
        }
    }

    func remainingHours(at instant: TimeInterval) -> Double {
        max(0, Horology.hours(from: unlockAt - instant))
    }
}

/// Role: Domain. Primary verb — file a want. Fusee hours then payday snap.
enum Filing {
    static func mainspring(
        id: UUID = UUID(),
        title: String,
        price: Double,
        necessity: Double,
        discretion: Double,
        priority: Double,
        at filedAt: TimeInterval,
        regulator: Regulator,
        calendar: Calendar
    ) throws -> Mainspring {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CarriageError.emptyTitle }
        let hours = try Fusee.coolingHours(
            price: price,
            monthlyLimit: regulator.monthlyImpulseLimit,
            priority: priority,
            necessity: necessity,
            discretion: discretion
        )
        let rawUnlock = filedAt + Horology.interval(hours: hours)
        let unlockAt = Escapement.snap(
            rawUnlock: rawUnlock,
            regulator: regulator,
            calendar: calendar
        )
        return Mainspring(
            id: id,
            title: trimmed,
            price: price,
            necessity: necessity,
            discretion: discretion,
            priority: priority,
            filedAt: filedAt,
            coolingHours: hours,
            unlockAt: unlockAt,
            halt: nil
        )
    }
}
