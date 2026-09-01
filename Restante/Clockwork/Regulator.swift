import Foundation

/// Role: Domain. Payday weekday, pay interval and monthly impulse limit.
struct Regulator: Hashable, Sendable, Equatable {
    var weekday: Int
    var intervalDays: Int
    var monthlyImpulseLimit: Double
    var anchorPayday: TimeInterval

    static let friday = 6
    static let defaultLimit = 400.0
    static let defaultInterval = 14

    static func factoryDefault(now: Date, calendar: Calendar) -> Regulator {
        var match = DateComponents()
        match.weekday = friday
        let start = calendar.startOfDay(for: now)
        let probe = start.addingTimeInterval(-1)
        let payday = calendar.nextDate(
            after: probe,
            matching: match,
            matchingPolicy: .nextTime
        ) ?? start
        return Regulator(
            weekday: friday,
            intervalDays: defaultInterval,
            monthlyImpulseLimit: defaultLimit,
            anchorPayday: Horology.instant(from: calendar.startOfDay(for: payday))
        )
    }
}

/// Role: Domain. Validates a regulator before Controls persist it.
enum Regulation {
    static func validated(_ regulator: Regulator) throws -> Regulator {
        guard (1 ... 7).contains(regulator.weekday) else {
            throw CarriageError.invalidWeekday
        }
        guard regulator.intervalDays >= 1 else {
            throw CarriageError.invalidInterval
        }
        guard regulator.monthlyImpulseLimit.isFinite, regulator.monthlyImpulseLimit > 0 else {
            throw CarriageError.invalidLimit
        }
        guard regulator.anchorPayday.isFinite else {
            throw CarriageError.invalidInterval
        }
        return regulator
    }
}
