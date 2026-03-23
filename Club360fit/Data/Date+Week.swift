import Foundation

extension Calendar {
    /// Matches Android `WorkoutSessionLogRepository.weekStartSunday` → Java `LocalDate.with(DayOfWeek.SUNDAY)` (ISO week: Sunday is the last day of the week).
    static func weekStartSunday(containing date: Date) -> Date {
        let cal = Calendar(identifier: .iso8601)
        let day = cal.startOfDay(for: date)
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day)
        guard let monday = cal.date(from: comps) else { return day }
        return cal.date(byAdding: .day, value: 6, to: monday) ?? day
    }
}

enum Club360DateFormats {
    static let postgresDay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayString(_ date: Date) -> String {
        postgresDay.string(from: date)
    }

    /// Matches Android `LocalDate.toDisplayDate()` (`MMM dd yyyy`).
    static func displayDay(fromPostgresDay s: String) -> String {
        guard let d = postgresDay.date(from: s) else { return s }
        let f = DateFormatter()
        f.locale = .current
        f.timeZone = .current
        f.dateFormat = "MMM dd yyyy"
        return f.string(from: d)
    }
}
