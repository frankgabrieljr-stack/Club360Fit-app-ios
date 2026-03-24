import Foundation

// MARK: - Schedule (`schedule_events`)

struct ScheduleEventDTO: Decodable, Sendable, Identifiable {
    let rowId: String?
    let userId: String?
    let title: String
    let date: String
    let time: String
    let notes: String?
    let clientId: String?
    let isCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case rowId = "id"
        case userId = "user_id"
        case title
        case date
        case time
        case notes
        case clientId = "client_id"
        case isCompleted = "is_completed"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rowId = try c.decodeIfPresent(String.self, forKey: .rowId)
        userId = try c.decodeIfPresent(String.self, forKey: .userId)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        time = try c.decodeIfPresent(String.self, forKey: .time) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        clientId = try c.decodeIfPresent(String.self, forKey: .clientId)
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    }

    var id: String { rowId ?? "\(date)-\(time)-\(title)" }
}

// MARK: - Daily habits (`daily_habit_logs`)

struct DailyHabitLogDTO: Decodable, Sendable, Identifiable {
    let rowId: String?
    let clientId: String
    let logDate: String
    let waterDone: Bool
    let steps: Int?
    let sleepHours: Double?

    enum CodingKeys: String, CodingKey {
        case rowId = "id"
        case clientId = "client_id"
        case logDate = "log_date"
        case waterDone = "water_done"
        case steps
        case sleepHours = "sleep_hours"
    }

    var id: String { rowId ?? "\(clientId)-\(logDate)" }
}

struct DailyHabitLogInsert: Encodable, Sendable {
    let clientId: String
    let logDate: String
    let waterDone: Bool
    let steps: Int?
    let sleepHours: Double?

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case logDate = "log_date"
        case waterDone = "water_done"
        case steps
        case sleepHours = "sleep_hours"
    }
}

struct DailyHabitPatch: Encodable, Sendable {
    let waterDone: Bool
    let steps: Int?
    let sleepHours: Double?

    enum CodingKeys: String, CodingKey {
        case waterDone = "water_done"
        case steps
        case sleepHours = "sleep_hours"
    }
}

// MARK: - Payments

struct ClientPaymentSettingsDTO: Decodable, Sendable {
    let clientId: String
    let venmoUrl: String?
    let zelleEmail: String?
    let zellePhone: String?
    let note: String?
    let nextDueDate: String?
    let nextDueAmount: String?
    let nextDueNote: String?

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case venmoUrl = "venmo_url"
        case zelleEmail = "zelle_email"
        case zellePhone = "zelle_phone"
        case note
        case nextDueDate = "next_due_date"
        case nextDueAmount = "next_due_amount"
        case nextDueNote = "next_due_note"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clientId = try c.decode(String.self, forKey: .clientId)
        venmoUrl = try c.decodeIfPresent(String.self, forKey: .venmoUrl)
        zelleEmail = try c.decodeIfPresent(String.self, forKey: .zelleEmail)
        zellePhone = try c.decodeIfPresent(String.self, forKey: .zellePhone)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        nextDueDate = try c.decodeIfPresent(String.self, forKey: .nextDueDate)
        nextDueAmount = try c.decodeIfPresent(String.self, forKey: .nextDueAmount)
        nextDueNote = try c.decodeIfPresent(String.self, forKey: .nextDueNote)
    }
}

struct PaymentRecordDTO: Decodable, Sendable, Identifiable {
    let rowId: String?
    let clientId: String
    let amountLabel: String?
    let paidAt: String
    let method: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case rowId = "id"
        case clientId = "client_id"
        case amountLabel = "amount_label"
        case paidAt = "paid_at"
        case method
        case note
    }

    var id: String { rowId ?? "\(clientId)-\(paidAt)-\(amountLabel ?? "")" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rowId = try c.decodeIfPresent(String.self, forKey: .rowId)
        clientId = try c.decode(String.self, forKey: .clientId)
        amountLabel = try c.decodeIfPresent(String.self, forKey: .amountLabel)
        paidAt = try c.decode(String.self, forKey: .paidAt)
        method = try c.decodeIfPresent(String.self, forKey: .method) ?? "other"
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

struct PaymentConfirmationDTO: Decodable, Sendable, Identifiable {
    let rowId: String?
    let clientId: String
    let amountLabel: String?
    let note: String
    let method: String
    let submittedAt: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case rowId = "id"
        case clientId = "client_id"
        case amountLabel = "amount_label"
        case note
        case method
        case submittedAt = "submitted_at"
        case status
    }

    var id: String { rowId ?? "\(clientId)-\(submittedAt ?? note)-\(amountLabel ?? "")" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rowId = try c.decodeIfPresent(String.self, forKey: .rowId)
        clientId = try c.decode(String.self, forKey: .clientId)
        amountLabel = try c.decodeIfPresent(String.self, forKey: .amountLabel)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        method = try c.decodeIfPresent(String.self, forKey: .method) ?? "venmo"
        submittedAt = try c.decodeIfPresent(String.self, forKey: .submittedAt)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "pending"
    }
}

struct PaymentConfirmationInsert: Encodable, Sendable {
    let clientId: String
    let amountLabel: String?
    let note: String
    let method: String

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case amountLabel = "amount_label"
        case note
        case method
    }
}

// MARK: - Notifications (`client_notifications`)

struct ClientNotificationDTO: Decodable, Sendable, Identifiable {
    let rowId: String?
    let clientId: String
    let title: String
    let body: String
    let readAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case rowId = "id"
        case clientId = "client_id"
        case title
        case body
        case readAt = "read_at"
        case createdAt = "created_at"
    }

    var id: String { rowId ?? "\(clientId)-\(createdAt ?? UUID().uuidString)" }
}

struct NotificationReadAtPatch: Encodable, Sendable {
    let readAt: String
    enum CodingKeys: String, CodingKey { case readAt = "read_at" }
}

struct ClientNotificationInsert: Encodable, Sendable {
    let clientId: String
    let kind: String
    let title: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case kind
        case title
        case body
    }
}

// MARK: - Transformation gallery (Storage)

struct TransformationImage: Identifiable, Hashable, Sendable {
    let path: String
    let url: URL

    var id: String { path }
}
