import Foundation
import Supabase

/// Calls Edge Function `transfer-client` — only the current `clients.coach_id` may move the row to another coach.
private struct TransferClientPayload: Encodable {
    let client_id: String
    let target_coach_user_id: String
}

private struct TransferClientResponse: Decodable {
    let ok: Bool?
    let error: String?
}

enum ClientTransferService {
    /// Sets `clients.coach_id` to `targetCoachUserId` (must be an Auth user with `user_metadata.role` = admin). Deploy `transfer-client` in Supabase.
    static func transferClient(clientId: String, targetCoachUserId: String) async throws {
        let cid = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let tid = targetCoachUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cid.isEmpty else {
            throw NSError(domain: "Club360Fit", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing client."])
        }
        guard !tid.isEmpty else {
            throw NSError(domain: "Club360Fit", code: 400, userInfo: [NSLocalizedDescriptionKey: "Enter the other coach’s user ID (UUID)."])
        }
        let payload = TransferClientPayload(client_id: cid, target_coach_user_id: tid)
        let response: TransferClientResponse = try await Club360FitSupabase.shared.functions.invoke(
            "transfer-client",
            options: FunctionInvokeOptions(body: payload)
        )
        if response.ok != true {
            let msg = response.error ?? "Transfer failed. Deploy the transfer-client Edge Function in Supabase."
            throw NSError(domain: "Club360Fit", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }
}
