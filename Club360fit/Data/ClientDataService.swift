import Auth
import Foundation
import Supabase

/// PostgREST calls aligned with Android repositories (`ClientSelfRepository`, `WorkoutPlanRepository`, etc.).
enum ClientDataService {
    private static var db: SupabaseClient { Club360FitSupabase.shared }

    /// `clients` row for the signed-in auth user (`user_id` = `auth.uid`).
    static func fetchOwnClientProfile(userId: String) async throws -> ClientDTO? {
        let rows: [ClientDTO] = try await db
            .from("clients")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Single `clients` row by primary key (coach / admin flows).
    static func fetchClientById(_ clientId: String) async throws -> ClientDTO? {
        let rows: [ClientDTO] = try await db
            .from("clients")
            .select()
            .eq("id", value: clientId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// All `clients` rows visible to the signed-in coach (`RLS` restricts to coached clients).
    static func fetchClientsForCoach() async throws -> [ClientDTO] {
        try await db
            .from("clients")
            .select()
            .order("full_name", ascending: true)
            .execute()
            .value
    }

    static func fetchWorkoutPlans(clientId: String) async throws -> [WorkoutPlanDTO] {
        try await db
            .from("workout_plans")
            .select()
            .eq("client_id", value: clientId)
            .order("week_start", ascending: false)
            .execute()
            .value
    }

    static func fetchMealPlans(clientId: String) async throws -> [MealPlanDTO] {
        try await db
            .from("meal_plans")
            .select()
            .eq("client_id", value: clientId)
            .order("week_start", ascending: false)
            .execute()
            .value
    }

    static func fetchProgressCheckIns(clientId: String) async throws -> [ProgressCheckInDTO] {
        try await db
            .from("progress_check_ins")
            .select()
            .eq("client_id", value: clientId)
            .order("check_in_date", ascending: false)
            .execute()
            .value
    }

    // MARK: - Workout session logs (`workout_session_logs`)

    /// Count rows for `client_id` + `week_start` (yyyy-MM-dd), matching Android `WorkoutSessionLogRepository.countForWeek`.
    static func workoutSessionCountForWeek(clientId: String, weekStart: Date) async throws -> Int {
        let key = Club360DateFormats.dayString(weekStart)
        let rows: [WorkoutSessionLogDTO] = try await db
            .from("workout_session_logs")
            .select()
            .eq("client_id", value: clientId)
            .eq("week_start", value: key)
            .execute()
            .value
        return rows.count
    }

    /// Insert a session log; ignores duplicate-day errors like Android.
    static func logWorkoutSession(clientId: String, sessionDate: Date) async {
        let weekStart = Calendar.weekStartSunday(containing: sessionDate)
        let row = WorkoutSessionLogInsert(
            clientId: clientId,
            sessionDate: Club360DateFormats.dayString(sessionDate),
            weekStart: Club360DateFormats.dayString(weekStart)
        )
        do {
            try await db
                .from("workout_session_logs")
                .insert(row)
                .execute()
        } catch {
            // duplicate day / unique constraint — same as Android
        }
    }

    // MARK: - Progress check-ins (`progress_check_ins`)

    /// Mirrors Android `ProgressRepository.addCheckIn`.
    static func addProgressCheckIn(_ row: ProgressCheckInInsert) async throws {
        try await db
            .from("progress_check_ins")
            .insert(row)
            .execute()
    }

    // MARK: - Meal photo logs (`meal_photo_logs` + Storage)

    /// Same ordering idea as Android `MealPhotoRepository.listForClient`.
    static func listMealPhotoLogs(clientId: String) async throws -> [MealPhotoLogDTO] {
        try await db
            .from("meal_photo_logs")
            .select()
            .eq("client_id", value: clientId)
            .order("log_date", ascending: false)
            .execute()
            .value
    }

    /// Coach inbox: every `meal_photo_logs` row visible to the session (`RLS`: coached clients). Sorted newest first.
    static func listMealPhotoLogsForCoachInbox() async throws -> [MealPhotoLogDTO] {
        let rows: [MealPhotoLogDTO] = try await db
            .from("meal_photo_logs")
            .select()
            .execute()
            .value
        return rows.sorted { a, b in
            if a.logDate != b.logDate { return a.logDate > b.logDate }
            return (a.createdAt ?? "") > (b.createdAt ?? "")
        }
    }

    /// Public URL for a row’s `storage_path` (bucket must be public, like Android `publicUrlFor`).
    static func mealPhotoPublicURL(storagePath: String) throws -> URL {
        try Club360FitSupabase.shared.storage
            .from(Club360FitSupabase.mealPhotosBucket)
            .getPublicURL(path: storagePath)
    }

    /// Upload to `meal-photos` then insert `meal_photo_logs`, matching Android `MealPhotoRepository.uploadAndInsert`.
    static func uploadMealPhotoAndInsert(
        clientId: String,
        imageData: Data,
        logDate: Date,
        notes: String,
        originalFilename: String
    ) async throws -> MealPhotoLogDTO {
        let safeName = originalFilename.replacingOccurrences(
            of: "\\s+",
            with: "_",
            options: .regularExpression
        )
        let filePart = safeName.isEmpty ? "photo.jpg" : safeName
        let path = "\(clientId)/\(Int(Date().timeIntervalSince1970 * 1_000))_\(filePart)"
        let bucket = Club360FitSupabase.shared.storage.from(Club360FitSupabase.mealPhotosBucket)
        try await bucket.upload(
            path,
            data: imageData,
            options: FileOptions(contentType: "image/jpeg")
        )
        let row = MealPhotoLogInsert(
            clientId: clientId,
            logDate: Club360DateFormats.dayString(logDate),
            storagePath: path,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            try await db
                .from("meal_photo_logs")
                .insert(row)
                .execute()
        } catch {
            _ = try? await bucket.remove(paths: [path])
            throw error
        }
        let rows: [MealPhotoLogDTO] = try await db
            .from("meal_photo_logs")
            .select()
            .eq("storage_path", value: path)
            .execute()
            .value
        guard let first = rows.first else {
            throw ClientDataServiceError.insertedMealPhotoRowMissing
        }
        return first
    }

    /// Coach/admin: set or clear feedback on a client’s meal photo (Android `MealPhotoRepository.updateCoachFeedback`).
    static func updateMealPhotoCoachFeedback(clientId: String, logId: String, feedback: String) async throws {
        let trimmed = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: AnyJSON]
        if trimmed.isEmpty {
            body = [
                "coach_feedback": .null,
                "coach_feedback_updated_at": .null,
            ]
        } else {
            let now = ISO8601DateFormatter().string(from: Date())
            body = [
                "coach_feedback": .string(trimmed),
                "coach_feedback_updated_at": .string(now),
            ]
        }
        try await db
            .from("meal_photo_logs")
            .update(body)
            .eq("id", value: logId)
            .eq("client_id", value: clientId)
            .execute()

        if !trimmed.isEmpty {
            // Best-effort: bell badge counts `client_notifications`; fails quietly if coach INSERT policy isn’t applied yet.
            try? await insertMealPhotoFeedbackClientNotification(clientId: clientId, feedbackPreview: trimmed)
        }
    }

    /// In-app notification so the member sees the bell badge (requires migration `013_coach_insert_client_notifications`).
    private static func insertMealPhotoFeedbackClientNotification(clientId: String, feedbackPreview: String) async throws {
        let preview = String(feedbackPreview.prefix(500))
        let row = ClientNotificationInsert(
            clientId: clientId,
            kind: "meal_feedback",
            title: "Coach feedback on your meal photo",
            body: preview.isEmpty ? "Your coach left feedback." : preview
        )
        try await db
            .from("client_notifications")
            .insert(row)
            .execute()
    }

    /// Mirrors Android `MealPhotoRepository.deleteOwn`.
    static func deleteMealPhotoLog(clientId: String, logId: String) async throws {
        let rows: [MealPhotoLogDTO] = try await db
            .from("meal_photo_logs")
            .select()
            .eq("id", value: logId)
            .limit(1)
            .execute()
            .value
        guard let existing = rows.first, existing.clientId == clientId else { return }
        try await db
            .from("meal_photo_logs")
            .delete()
            .eq("id", value: logId)
            .execute()
        _ = try? await Club360FitSupabase.shared.storage
            .from(Club360FitSupabase.mealPhotosBucket)
            .remove(paths: [existing.storagePath])
    }
}

enum ClientDataServiceError: LocalizedError {
    case insertedMealPhotoRowMissing

    var errorDescription: String? {
        switch self {
        case .insertedMealPhotoRowMissing:
            "Uploaded image but could not load the saved row."
        }
    }
}
