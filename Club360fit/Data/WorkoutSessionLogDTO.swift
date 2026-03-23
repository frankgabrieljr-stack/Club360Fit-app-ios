import Foundation

/// `workout_session_logs` — mirrors Android `WorkoutSessionLogDto`.
struct WorkoutSessionLogDTO: Decodable, Sendable {
    let id: String?
    let clientId: String
    let sessionDate: String
    let weekStart: String

    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case sessionDate = "session_date"
        case weekStart = "week_start"
    }
}

struct WorkoutSessionLogInsert: Encodable, Sendable {
    let clientId: String
    let sessionDate: String
    let weekStart: String

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case sessionDate = "session_date"
        case weekStart = "week_start"
    }
}
