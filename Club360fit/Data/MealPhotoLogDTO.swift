import Foundation

/// Mirrors Android `MealPhotoLogDto` / `meal_photo_logs`.
struct MealPhotoLogDTO: Decodable, Sendable {
    let id: String?
    let clientId: String
    let logDate: String
    let storagePath: String
    let notes: String?
    let createdAt: String?
    let coachFeedback: String?
    let coachFeedbackUpdatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case logDate = "log_date"
        case storagePath = "storage_path"
        case notes
        case createdAt = "created_at"
        case coachFeedback = "coach_feedback"
        case coachFeedbackUpdatedAt = "coach_feedback_updated_at"
    }

    var rowIdentity: String {
        if let id, !id.isEmpty { return id }
        return "\(clientId)-\(logDate)-\(storagePath)"
    }
}

struct MealPhotoLogInsert: Encodable, Sendable {
    let clientId: String
    let logDate: String
    let storagePath: String
    let notes: String

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case logDate = "log_date"
        case storagePath = "storage_path"
        case notes
    }
}
