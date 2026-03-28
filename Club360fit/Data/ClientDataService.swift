import Auth
import Foundation
import Supabase

/// PostgREST calls aligned with Android repositories (`ClientSelfRepository`, `WorkoutPlanRepository`, etc.).
enum ClientDataService {
    private static var db: SupabaseClient { Club360FitSupabase.shared }
    private struct WorkoutSessionCoachReplyPatch: Encodable {
        let coach_reply: String
        let coach_replied_at: String
    }
    private struct ClientAccessPatch: Encodable {
        let can_view_workouts: Bool
        let can_view_nutrition: Bool
        let can_view_events: Bool
        let can_view_payments: Bool
    }

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

    /// Best-effort self-heal for accounts where Auth signup succeeded but `public.clients` row is missing.
    /// Returns the row if it exists or could be created and then fetched; otherwise `nil`.
    static func ensureOwnClientProfile(userId: String, fullName: String?) async throws -> ClientDTO? {
        if let existing = try await fetchOwnClientProfile(userId: userId) {
            return existing
        }

        let trimmedName = fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let row: [String: AnyJSON] = [
            "user_id": .string(userId),
            "full_name": trimmedName.isEmpty ? .null : .string(trimmedName),
        ]
        do {
            try await db
                .from("clients")
                .insert(row)
                .execute()
        } catch {
            // If RLS/trigger config prevents direct insert, caller will surface a backend-oriented message.
        }
        return try await fetchOwnClientProfile(userId: userId)
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

    private struct ProfileRoleRow: Decodable, Sendable {
        let role: String
    }

    /// `public.profiles.role` for this auth user (`admin` / `client`). Coach JWT must be `admin` (RLS).
    static func fetchProfileRoleForUser(userId: String) async throws -> String? {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let rows: [ProfileRoleRow] = try await db
            .from("profiles")
            .select("role")
            .eq("id", value: trimmed)
            .limit(1)
            .execute()
            .value
        return rows.first?.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// One row from `public.profiles` for coach directory; `id` is the Supabase Auth user id (use for transfers).
    struct CoachDirectoryProfileRow: Decodable, Sendable, Identifiable {
        let id: String
        let full_name: String?
        let email: String?
        let role: String
    }

    /// Coach accounts (`profiles.role` = admin) so admins can copy another coach’s Auth user id. Requires admin JWT (RLS).
    static func fetchCoachDirectoryProfiles() async throws -> [CoachDirectoryProfileRow] {
        try await db
            .from("profiles")
            .select("id, full_name, email, role")
            .eq("role", value: "admin")
            .order("full_name", ascending: true)
            .execute()
            .value
    }

    /// Sets `coach_id` to the signed-in user when the row is still unassigned (signup intake). Required for plan RLS after `coach_id` became nullable.
    static func claimCoachAssignmentIfNeeded(clientId: String) async throws {
        guard let session = db.auth.currentSession else { return }
        let uid = session.user.id.uuidString
        let patch: [String: AnyJSON] = ["coach_id": .string(uid)]
        try await db
            .from("clients")
            .update(patch)
            .eq("id", value: clientId)
            .execute()
    }

    /// Coach/admin: updates which tiles/features are available to this member.
    static func updateClientAccessFlags(
        clientId: String,
        canViewWorkouts: Bool,
        canViewNutrition: Bool,
        canViewEvents: Bool,
        canViewPayments: Bool
    ) async throws {
        let patch = ClientAccessPatch(
            can_view_workouts: canViewWorkouts,
            can_view_nutrition: canViewNutrition,
            can_view_events: canViewEvents,
            can_view_payments: canViewPayments
        )
        try await db
            .from("clients")
            .update(patch)
            .eq("id", value: clientId)
            .execute()
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
    static func logWorkoutSession(clientId: String, sessionDate: Date, noteToCoach: String? = nil) async {
        let trimmedNote = noteToCoach?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let weekStart = Calendar.weekStartSunday(containing: sessionDate)
        let row = WorkoutSessionLogInsert(
            clientId: clientId,
            sessionDate: Club360DateFormats.dayString(sessionDate),
            weekStart: Club360DateFormats.dayString(weekStart),
            noteToCoach: trimmedNote.isEmpty ? nil : String(trimmedNote.prefix(1000))
        )
        do {
            let inserted: [WorkoutSessionLogDTO] = try await db
                .from("workout_session_logs")
                .insert(row)
                .select()
                .execute()
                .value
            let day = Club360DateFormats.dayString(sessionDate)
            let body: String
            if trimmedNote.isEmpty {
                body = "Member logged a session for \(day)."
            } else {
                body = "Member logged a session for \(day). Note: \(String(trimmedNote.prefix(500)))"
            }
            await ClientDataService.notifyCoachAboutClient(
                clientId: clientId,
                kind: "workout_session_logged",
                title: "Workout session logged",
                body: body,
                refType: "workout_session",
                refId: inserted.first?.id
            )
        } catch {
            // duplicate day / unique constraint — same as Android
        }
    }

    /// Coach/admin: write a timestamped reply to the member's logged workout note.
    static func replyToWorkoutSessionNote(
        clientId: String,
        workoutSessionLogId: String?,
        replyText: String
    ) async throws {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let now = ISO8601DateFormatter().string(from: Date())
        if let workoutSessionLogId, !workoutSessionLogId.isEmpty {
            let patch = WorkoutSessionCoachReplyPatch(
                coach_reply: String(trimmed.prefix(1000)),
                coach_replied_at: now
            )
            try await db
                .from("workout_session_logs")
                .update(patch)
                .eq("id", value: workoutSessionLogId)
                .eq("client_id", value: clientId)
                .execute()
        }

        await notifyMemberFromCoach(
            clientId: clientId,
            kind: "workout_session_reply",
            title: "Coach reply to your workout note",
            body: String(trimmed.prefix(1000)),
            refType: "workout_session",
            refId: workoutSessionLogId
        )
    }

    // MARK: - Progress check-ins (`progress_check_ins`)

    /// Mirrors Android `ProgressRepository.addCheckIn`.
    static func addProgressCheckIn(_ row: ProgressCheckInInsert) async throws {
        let rows: [ProgressCheckInDTO] = try await db
            .from("progress_check_ins")
            .insert(row)
            .select()
            .execute()
            .value
        let rid = rows.first?.id
        await ClientDataService.notifyCoachAboutClient(
            clientId: row.clientId,
            kind: "progress_checkin",
            title: "Progress check-in submitted",
            body: "Check-in for \(row.checkInDate).",
            refType: "progress",
            refId: rid
        )
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
        let notePreview = first.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body: String
        if notePreview.isEmpty {
            body = "Photo for \(first.logDate)."
        } else {
            body = "Photo for \(first.logDate) — \(notePreview)"
        }
        await ClientDataService.notifyCoachAboutClient(
            clientId: clientId,
            kind: "meal_photo_upload",
            title: "New meal photo",
            body: body,
            refType: "meal_photo",
            refId: first.id,
            dedupeKey: first.id.map { "meal_photo_upload:\($0)" }
        )
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
            try? await insertMealPhotoFeedbackClientNotification(clientId: clientId, logId: logId, feedbackPreview: trimmed)
        }
    }

    /// In-app notification so the member sees the bell badge (requires migration `013_coach_insert_client_notifications`).
    private static func insertMealPhotoFeedbackClientNotification(
        clientId: String,
        logId: String,
        feedbackPreview: String
    ) async throws {
        let preview = String(feedbackPreview.prefix(500))
        let row = ClientNotificationInsert(
            clientId: clientId,
            kind: "meal_feedback",
            title: "Coach feedback on your meal photo",
            body: preview.isEmpty ? "Your coach left feedback." : preview,
            refType: "meal_photo",
            refId: logId,
            visibleToClient: true
        )
        try await insertClientNotification(row)
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
