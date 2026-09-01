import Foundation

/// Role: Domain (owned by Controls). Payday snap. Hours never fire mid-cycle.
enum Escapement {
    static func snap(
        rawUnlock: TimeInterval,
        regulator: Regulator,
        calendar: Calendar
    ) -> TimeInterval {
        let raw = Horology.date(from: rawUnlock)
        let payday = nextPayday(onOrAfter: raw, regulator: regulator, calendar: calendar)
        return Horology.instant(from: payday)
    }

    static func nextPayday(
        onOrAfter date: Date,
        regulator: Regulator,
        calendar: Calendar
    ) -> Date {
        let threshold = calendar.startOfDay(for: date)
        var cursor = calendar.startOfDay(for: Horology.date(from: regulator.anchorPayday))
        let step = max(regulator.intervalDays, 1)

        if cursor > threshold {
            while true {
                guard let previous = calendar.date(byAdding: .day, value: -step, to: cursor) else {
                    break
                }
                let previousStart = calendar.startOfDay(for: previous)
                if previousStart >= threshold {
                    cursor = previousStart
                } else {
                    break
                }
            }
            return cursor
        }

        while cursor < threshold {
            guard let next = calendar.date(byAdding: .day, value: step, to: cursor) else {
                break
            }
            cursor = calendar.startOfDay(for: next)
        }
        return cursor
    }
}
