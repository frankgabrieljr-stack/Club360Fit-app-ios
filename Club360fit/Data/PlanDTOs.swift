import Foundation

/// Mirrors Android `WorkoutPlanDto` / `workout_plans`.
struct WorkoutPlanDTO: Decodable, Sendable {
    let id: String?
    let clientId: String
    let title: String
    let weekStart: String
    let planText: String
    let expectedSessions: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case title
        case weekStart = "week_start"
        case planText = "plan_text"
        case expectedSessions = "expected_sessions"
    }

    /// Stable row id for SwiftUI lists when `id` is nil.
    var rowIdentity: String {
        if let id, !id.isEmpty { return id }
        return "\(clientId)-\(weekStart)-\(title)"
    }
}

/// Mirrors Android `MealPlanDto` / `meal_plans`.
struct MealPlanDTO: Decodable, Sendable {
    let id: String?
    let clientId: String
    let title: String
    let weekStart: String
    let planText: String

    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case title
        case weekStart = "week_start"
        case planText = "plan_text"
    }

    var rowIdentity: String {
        if let id, !id.isEmpty { return id }
        return "\(clientId)-\(weekStart)-\(title)"
    }
}

/// Mirrors Android `ProgressCheckInDto` / `progress_check_ins`.
struct ProgressCheckInDTO: Decodable, Sendable {
    let id: String?
    let clientId: String
    let checkInDate: String
    let weightKg: Double?
    let notes: String?
    let workoutDone: Bool
    let mealsFollowed: Bool
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case checkInDate = "check_in_date"
        case weightKg = "weight_kg"
        case notes
        case workoutDone = "workout_done"
        case mealsFollowed = "meals_followed"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        clientId = try c.decode(String.self, forKey: .clientId)
        checkInDate = try c.decode(String.self, forKey: .checkInDate)
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        workoutDone = try c.decodeIfPresent(Bool.self, forKey: .workoutDone) ?? false
        mealsFollowed = try c.decodeIfPresent(Bool.self, forKey: .mealsFollowed) ?? false
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    var rowIdentity: String {
        if let id, !id.isEmpty { return id }
        return "\(clientId)-\(checkInDate)"
    }
}

struct ProgressCheckInInsert: Encodable, Sendable {
    let clientId: String
    let checkInDate: String
    let weightKg: Double?
    let notes: String
    let workoutDone: Bool
    let mealsFollowed: Bool

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case checkInDate = "check_in_date"
        case weightKg = "weight_kg"
        case notes
        case workoutDone = "workout_done"
        case mealsFollowed = "meals_followed"
    }
}
