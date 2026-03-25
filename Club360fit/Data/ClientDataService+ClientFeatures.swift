import Foundation
import Storage
import Supabase

extension ClientDataService {
    private static var svc: SupabaseClient { Club360FitSupabase.shared }

    // MARK: - Schedule (`schedule_events`)

    static func fetchScheduleEvents(clientId: String) async throws -> [ScheduleEventDTO] {
        try await svc
            .from("schedule_events")
            .select()
            .eq("client_id", value: clientId)
            .execute()
            .value
    }

    // MARK: - Daily habits (`daily_habit_logs`)

    static func fetchDailyHabitForDay(clientId: String, logDate: String) async throws -> DailyHabitLogDTO? {
        let rows: [DailyHabitLogDTO] = try await svc
            .from("daily_habit_logs")
            .select()
            .eq("client_id", value: clientId)
            .eq("log_date", value: logDate)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// All habit rows for the client, newest `log_date` first (for history UI).
    static func fetchDailyHabitLogs(clientId: String, limit: Int = 5000) async throws -> [DailyHabitLogDTO] {
        try await svc
            .from("daily_habit_logs")
            .select()
            .eq("client_id", value: clientId)
            .order("log_date", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func upsertDailyHabit(
        clientId: String,
        date: Date,
        waterDone: Bool,
        steps: Int?,
        sleepHours: Double?
    ) async throws {
        let day = Club360DateFormats.dayString(date)
        if let existing = try await fetchDailyHabitForDay(clientId: clientId, logDate: day),
           let eid = existing.rowId, !eid.isEmpty {
            let patch = DailyHabitPatch(waterDone: waterDone, steps: steps, sleepHours: sleepHours)
            try await svc
                .from("daily_habit_logs")
                .update(patch)
                .eq("id", value: eid)
                .execute()
        } else {
            let row = DailyHabitLogInsert(
                clientId: clientId,
                logDate: day,
                waterDone: waterDone,
                steps: steps,
                sleepHours: sleepHours
            )
            try await svc
                .from("daily_habit_logs")
                .insert(row)
                .execute()
        }
    }

    // MARK: - Payments

    static func fetchPaymentSettings(clientId: String) async throws -> ClientPaymentSettingsDTO? {
        let rows: [ClientPaymentSettingsDTO] = try await svc
            .from("client_payment_settings")
            .select()
            .eq("client_id", value: clientId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Coach sets Venmo/Zelle and “upcoming due” fields (`coach_rw_client_payment_settings` RLS).
    /// Uses explicit JSON nulls so cleared fields overwrite previous values.
    static func upsertPaymentSettings(
        clientId: String,
        venmoUrl: String?,
        zelleEmail: String?,
        zellePhone: String?,
        note: String,
        nextDueDate: String?,
        nextDueAmount: String?,
        nextDueNote: String?
    ) async throws {
        let row: [String: AnyJSON] = [
            "client_id": .string(clientId),
            "venmo_url": venmoUrl.map { .string($0) } ?? .null,
            "zelle_email": zelleEmail.map { .string($0) } ?? .null,
            "zelle_phone": zellePhone.map { .string($0) } ?? .null,
            "note": .string(note),
            "next_due_date": nextDueDate.map { .string($0) } ?? .null,
            "next_due_amount": nextDueAmount.map { .string($0) } ?? .null,
            "next_due_note": nextDueNote.map { .string($0) } ?? .null,
        ]
        try await svc
            .from("client_payment_settings")
            .upsert(row)
            .execute()
    }

    static func fetchPaymentRecords(clientId: String) async throws -> [PaymentRecordDTO] {
        try await svc
            .from("payment_records")
            .select()
            .eq("client_id", value: clientId)
            .order("paid_at", ascending: false)
            .execute()
            .value
    }

    static func fetchPaymentConfirmations(clientId: String) async throws -> [PaymentConfirmationDTO] {
        try await svc
            .from("payment_confirmations")
            .select()
            .eq("client_id", value: clientId)
            .order("submitted_at", ascending: false)
            .execute()
            .value
    }

    static func submitPaymentConfirmation(
        clientId: String,
        amountLabel: String?,
        note: String,
        method: String
    ) async throws {
        let m = method.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let safeMethod = m.isEmpty ? "venmo" : m
        let row = PaymentConfirmationInsert(
            clientId: clientId,
            amountLabel: amountLabel,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            method: safeMethod
        )
        let inserted: [PaymentConfirmationDTO] = try await svc
            .from("payment_confirmations")
            .insert(row)
            .select()
            .execute()
            .value
        let rid = inserted.first?.rowId
        let amountPart = amountLabel.map { "Amount: \($0). " } ?? ""
        await ClientDataService.notifyCoachAboutClient(
            clientId: clientId,
            kind: "payment_confirmation",
            title: "Payment confirmation submitted",
            body: "\(amountPart)\(note.trimmingCharacters(in: .whitespacesAndNewlines))",
            refType: "payment",
            refId: rid,
            dedupeKey: rid.map { "payment_confirmation:\($0)" }
        )
    }

    // MARK: - Notifications (`client_notifications`)

    static func fetchClientNotifications(clientId: String, limit: Int = 40) async throws -> [ClientNotificationDTO] {
        try await svc
            .from("client_notifications")
            .select()
            .eq("client_id", value: clientId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func unreadNotificationCount(clientId: String) async throws -> Int {
        let rows = try await fetchClientNotifications(clientId: clientId, limit: 100)
        return rows.filter { $0.readAt == nil }.count
    }

    static func markNotificationRead(notificationId: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let patch = NotificationReadAtPatch(readAt: now)
        try await svc
            .from("client_notifications")
            .update(patch)
            .eq("id", value: notificationId)
            .execute()
    }

    static func markAllNotificationsRead(clientId: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let patch = NotificationReadAtPatch(readAt: now)
        try await svc
            .from("client_notifications")
            .update(patch)
            .eq("client_id", value: clientId)
            .execute()
    }

    // MARK: - Transformation gallery (Storage)

    /// Lists `uid/filename` paths in the transformations bucket (two-level layout like Android).
    static func listTransformationImages() async throws -> [TransformationImage] {
        let storage = Club360FitSupabase.shared.storage.from(Club360FitSupabase.transformationsBucket)
        let root = try await storage.list()
        var result: [TransformationImage] = []
        for folder in root {
            if folder.name.contains(".") {
                let path = folder.name
                let url = try storage.getPublicURL(path: path)
                result.append(TransformationImage(path: path, url: url))
            } else {
                let nested = try await storage.list(path: folder.name)
                for file in nested {
                    let path = "\(folder.name)/\(file.name)"
                    let url = try storage.getPublicURL(path: path)
                    result.append(TransformationImage(path: path, url: url))
                }
            }
        }
        return result.sorted { $0.path < $1.path }
    }

    static func uploadTransformationImage(data: Data, originalFilename: String, userId: String) async throws -> TransformationImage {
        let safe = originalFilename.replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
        let name = safe.isEmpty ? "photo.jpg" : safe
        let path = "\(userId)/\(Int(Date().timeIntervalSince1970 * 1_000))_\(name)"
        let storage = Club360FitSupabase.shared.storage.from(Club360FitSupabase.transformationsBucket)
        try await storage.upload(
            path,
            data: data,
            options: FileOptions(contentType: "image/jpeg")
        )
        let url = try storage.getPublicURL(path: path)
        return TransformationImage(path: path, url: url)
    }

    static func deleteTransformationImage(path: String) async throws {
        try await Club360FitSupabase.shared.storage
            .from(Club360FitSupabase.transformationsBucket)
            .remove(paths: [path])
    }

    /// Public URL for avatar in `avatars` bucket.
    static func avatarPublicURL(path: String) throws -> URL {
        try Club360FitSupabase.shared.storage
            .from(Club360FitSupabase.avatarsBucket)
            .getPublicURL(path: path)
    }

    static func uploadUserAvatar(data: Data, userId: String) async throws -> URL {
        // Lowercase UUID so Storage path matches Supabase `auth.uid()::text` and RLS policies.
        let path = "\(userId.lowercased())/avatar.jpg"
        let storage = Club360FitSupabase.shared.storage.from(Club360FitSupabase.avatarsBucket)
        try await storage.upload(
            path,
            data: data,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        return try storage.getPublicURL(path: path)
    }
}
