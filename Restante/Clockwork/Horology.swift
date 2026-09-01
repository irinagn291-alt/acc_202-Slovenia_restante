import Foundation

/// Role: Domain. Fixed epoch and hour conversions. Controls store TimeInterval only.
enum Horology {
    static func instant(from date: Date) -> TimeInterval {
        date.timeIntervalSinceReferenceDate
    }

    static func date(from instant: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: instant)
    }

    static func hours(from interval: TimeInterval) -> Double {
        interval / 3600
    }

    static func interval(hours: Double) -> TimeInterval {
        hours * 3600
    }
}
