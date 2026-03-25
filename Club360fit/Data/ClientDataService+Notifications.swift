import Foundation
import Supabase

extension ClientDataService {
    private static var notifDb: SupabaseClient { Club360FitSupabase.shared }

    /// Inserts a `client_notifications` row (coach or client, per RLS).
    static func insertClientNotification(_ row: ClientNotificationInsert) async throws {
        try await notifDb
            .from("client_notifications")
            .insert(row)
            .execute()
    }

    /// Coach-facing updates shown in the member’s Updates feed (`visible_to_client` = true).
    static func notifyMemberFromCoach(
        clientId: String,
        kind: String,
        title: String,
        body: String,
        refType: String? = nil,
        refId: String? = nil,
        dedupeKey: String? = nil
    ) async {
        let row = ClientNotificationInsert(
            clientId: clientId,
            kind: kind,
            title: title,
            body: body,
            refType: refType,
            refId: refId,
            dedupeKey: dedupeKey,
            visibleToClient: true
        )
        try? await insertClientNotification(row)
    }

    /// Alerts for the coach when viewing this client (hidden from the member app).
    static func notifyCoachAboutClient(
        clientId: String,
        kind: String,
        title: String,
        body: String,
        refType: String? = nil,
        refId: String? = nil,
        dedupeKey: String? = nil
    ) async {
        let row = ClientNotificationInsert(
            clientId: clientId,
            kind: kind,
            title: title,
            body: body,
            refType: refType,
            refId: refId,
            dedupeKey: dedupeKey,
            visibleToClient: false
        )
        try? await insertClientNotification(row)
    }

    // MARK: - Coach hub (all coached clients; RLS restricts rows)

    /// Every `client_notifications` row visible to this coach (newest first).
    static func fetchNotificationsForCoach(limit: Int = 80) async throws -> [ClientNotificationDTO] {
        try await notifDb
            .from("client_notifications")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func unreadNotificationCountForCoach() async throws -> Int {
        let rows = try await fetchNotificationsForCoach(limit: 400)
        return rows.filter { $0.readAt == nil }.count
    }

    /// Marks every unread notification read for all coached clients (coach RLS).
    static func markAllNotificationsReadForCoach() async throws {
        let rows = try await fetchNotificationsForCoach(limit: 500)
        let unread = rows.filter { $0.readAt == nil }
        for n in unread {
            if let id = n.rowId {
                try await markNotificationRead(notificationId: id)
            }
        }
    }
}
