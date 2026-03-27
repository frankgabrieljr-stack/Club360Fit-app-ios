import Auth
import Foundation
import Observation
import Supabase

/// Mirrors Android `ClientHomeViewModel` — loads `clients`, plans, and check-ins for the home dashboard.
@Observable
@MainActor
final class ClientHomeViewModel {
    var isLoading = true
    var errorMessage: String?

    /// First name or email local-part (same idea as Android `welcomeName`).
    var welcomeName = "there"
    var clientId: String?

    /// Auth `user_id` on the loaded `clients` row — public avatar URL is `avatars/{user_id}/avatar.jpg`.
    var memberAuthUserId: String?

    var canViewWorkouts = true
    var canViewNutrition = true
    var canViewEvents = false
    var canViewPayments = false

    /// First day the client record existed (`clients.created_at`), for date pickers (e.g. daily habits).
    var memberSinceStartOfDay: Date?

    /// Unread client notifications (Android home badge). Uses member `read_at` or coach `coach_read_at` per `useCoachNotificationUnread`.
    var unreadNotifications = 0

    /// When true (coach viewing a client hub), unread count uses `coach_read_at`; otherwise member `read_at`.
    private var useCoachNotificationUnread = false

    /// Next upcoming session line for home card (e.g. “Mar 15, 2025 at 10:00 AM”).
    var nextSessionLine: String?
    var upcomingSessionCount = 0

    var currentWorkoutTitle: String?
    var workoutPlanCount = 0
    var currentMealTitle: String?
    var mealPlanCount = 0
    var progressCheckInCount = 0

    func reloadNotificationsCount() async {
        guard let cid = clientId else { return }
        if useCoachNotificationUnread {
            unreadNotifications = (try? await ClientDataService.unreadCoachNotificationCountForClient(clientId: cid)) ?? 0
        } else {
            unreadNotifications = (try? await ClientDataService.unreadNotificationCount(clientId: cid)) ?? 0
        }
    }

    func load(session: Session) async {
        useCoachNotificationUnread = false
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let client = try await ClientDataService.fetchOwnClientProfile(userId: session.user.id.uuidString)
            guard let row = client, let cid = row.id, !cid.isEmpty else {
                errorMessage = "No client profile found. Ask your coach to finish onboarding in Supabase."
                resetSummary()
                return
            }

            try await applyDashboard(for: row, clientId: cid, welcomeEmail: session.user.email)
        } catch {
            errorMessage = error.localizedDescription
            resetSummary()
        }
    }

    /// Coach/admin: load dashboard data for another client (same child views as the member app).
    func loadForClient(clientId requestedId: String) async {
        useCoachNotificationUnread = true
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await ClientDataService.claimCoachAssignmentIfNeeded(clientId: requestedId)
            guard let row = try await ClientDataService.fetchClientById(requestedId),
                  let cid = row.id, !cid.isEmpty else {
                errorMessage = "Client not found or not visible to your account."
                resetSummary()
                return
            }

            try await applyDashboard(for: row, clientId: cid, welcomeEmail: nil)
        } catch {
            errorMessage = error.localizedDescription
            resetSummary()
        }
    }

    private func applyDashboard(for row: ClientDTO, clientId cid: String, welcomeEmail: String?) async throws {
        self.clientId = cid
        memberAuthUserId = row.userId
        memberSinceStartOfDay = Self.startOfDayFromSupabaseTimestamp(row.createdAt)
        welcomeName = welcomeEmail.map { Self.welcomeName(from: row, email: $0) } ?? Self.coachViewWelcomeName(from: row)
        canViewWorkouts = row.canViewWorkouts
        canViewNutrition = row.canViewNutrition
        canViewEvents = row.canViewEvents
        canViewPayments = row.canViewPayments

        async let workouts = ClientDataService.fetchWorkoutPlans(clientId: cid)
        async let meals = ClientDataService.fetchMealPlans(clientId: cid)
        async let checkIns = ClientDataService.fetchProgressCheckIns(clientId: cid)

        let wPlans = try await workouts
        let mPlans = try await meals
        let pRows = try await checkIns
        if useCoachNotificationUnread {
            unreadNotifications = (try? await ClientDataService.unreadCoachNotificationCountForClient(clientId: cid)) ?? 0
        } else {
            unreadNotifications = (try? await ClientDataService.unreadNotificationCount(clientId: cid)) ?? 0
        }

        let events: [ScheduleEventDTO]
        if row.canViewEvents {
            events = try await ClientDataService.fetchScheduleEvents(clientId: cid)
        } else {
            events = []
        }
        Self.applyScheduleSummary(events: events, to: self)

        workoutPlanCount = wPlans.count
        currentWorkoutTitle = wPlans.first?.title
        mealPlanCount = mPlans.count
        currentMealTitle = mPlans.first?.title
        progressCheckInCount = pRows.count
    }

    private func resetSummary() {
        useCoachNotificationUnread = false
        clientId = nil
        memberAuthUserId = nil
        memberSinceStartOfDay = nil
        welcomeName = "there"
        currentWorkoutTitle = nil
        workoutPlanCount = 0
        currentMealTitle = nil
        mealPlanCount = 0
        progressCheckInCount = 0
        unreadNotifications = 0
        nextSessionLine = nil
        upcomingSessionCount = 0
        canViewEvents = false
        canViewPayments = false
    }

    private static func applyScheduleSummary(events: [ScheduleEventDTO], to model: ClientHomeViewModel) {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let upcoming = events.filter { e in
            guard !e.isCompleted, let d = Club360DateFormats.postgresDay.date(from: e.date) else { return false }
            return cal.startOfDay(for: d) >= todayStart
        }
        .sorted {
            let d0 = Club360DateFormats.postgresDay.date(from: $0.date) ?? .distantFuture
            let d1 = Club360DateFormats.postgresDay.date(from: $1.date) ?? .distantFuture
            if d0 != d1 { return d0 < d1 }
            return $0.time < $1.time
        }
        model.upcomingSessionCount = upcoming.count
        if let first = upcoming.first {
            let day = Club360DateFormats.displayDay(fromPostgresDay: first.date)
            model.nextSessionLine = "\(day) at \(first.time)"
        } else {
            model.nextSessionLine = nil
        }
    }

    /// Parses Supabase `timestamptz` strings for calendar ranges.
    private static func startOfDayFromSupabaseTimestamp(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let cal = Calendar.current
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) {
            return cal.startOfDay(for: d)
        }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) {
            return cal.startOfDay(for: d)
        }
        return nil
    }

    private static func welcomeName(from client: ClientDTO, email: String?) -> String {
        if let full = client.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !full.isEmpty {
            return full.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? "there"
        }
        if let email, let local = email.split(separator: "@").first {
            return String(local)
        }
        return "there"
    }

    /// First name for coach-facing headers (never uses the coach’s email).
    private static func coachViewWelcomeName(from client: ClientDTO) -> String {
        if let full = client.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !full.isEmpty {
            return full.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? "Member"
        }
        return "Member"
    }
}
