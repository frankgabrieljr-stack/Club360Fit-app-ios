import Foundation

/// Mirrors Android `formatPaymentInstant` for ISO-8601 timestamps from Postgres.
enum Club360Formatting {
    static func formatPaymentInstant(_ iso: String) -> String {
        let parsers: [ISO8601DateFormatter] = {
            let a = ISO8601DateFormatter()
            a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let b = ISO8601DateFormatter()
            b.formatOptions = [.withInternetDateTime]
            let c = ISO8601DateFormatter()
            c.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
            return [a, b, c]
        }()
        var date: Date?
        for p in parsers {
            if let d = p.date(from: iso) {
                date = d
                break
            }
        }
        guard let date else { return iso }
        let out = DateFormatter()
        out.locale = .current
        out.dateFormat = "MMM d, yyyy · h:mm a"
        return out.string(from: date)
    }
}
