import Foundation

func gmtCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.firstWeekday = 1
    return calendar
}

func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, calendar: Calendar) -> Date {
    var parts = DateComponents()
    parts.year = year
    parts.month = month
    parts.day = day
    parts.hour = hour
    return calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
}
