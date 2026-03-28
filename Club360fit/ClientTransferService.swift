import Foundation
import Supabase

/// Calls Edge Function `transfer-client` — only the current `clients.coach_id` may move the row to another coach.
private struct TransferClientPayload: Encodable {
    let client_id: String
    let target_coach_user_id: String
    /// Same UUID as `target_coach_user_id` — older deployed `transfer-client` builds only read this key.
    let target_coach_id: String
}

private struct TransferClientResponse: Decodable {
    let ok: Bool?
    let error: String?
}

/// Some 401 responses use `message` (gateway) instead of `error` (Edge Function body).
private struct FunctionsErrorBody: Decodable {
    let error: String?
    let message: String?
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
        let payload = TransferClientPayload(client_id: cid, target_coach_user_id: tid, target_coach_id: tid)
        let options = try await Club360FitSupabase.functionInvokeOptions(body: payload)
        do {
            let response: TransferClientResponse = try await Club360FitSupabase.shared.functions.invoke(
                "transfer-client",
                options: options
            )
            if response.ok != true {
                let msg = response.error ?? "Transfer failed. Deploy the transfer-client Edge Function in Supabase."
                throw NSError(domain: "Club360Fit", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
            }
        } catch {
            throw mapFunctionsInvokeError(error)
        }
    }

    private static func mapFunctionsInvokeError(_ error: Error) -> Error {
        guard let fn = error as? FunctionsError else { return error }
        switch fn {
        case .relayError:
            return NSError(
                domain: "Club360Fit",
                code: 502,
                userInfo: [NSLocalizedDescriptionKey: "Could not reach the server. Try again."]
            )
        case let .httpError(code, data):
            if let obj = try? JSONDecoder().decode(TransferClientResponse.self, from: data),
               let msg = obj.error, !msg.isEmpty
            {
                return NSError(domain: "Club360Fit", code: code, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            if let alt = try? JSONDecoder().decode(FunctionsErrorBody.self, from: data) {
                let msg = alt.error ?? alt.message
                if let msg, !msg.isEmpty {
                    return NSError(domain: "Club360Fit", code: code, userInfo: [NSLocalizedDescriptionKey: msg])
                }
            }
            if code == 401 {
                return NSError(
                    domain: "Club360Fit",
                    code: 401,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Could not authorize this request (401). If this keeps happening, confirm the app’s Supabase URL and anon key match your project, redeploy the transfer-client function, and try again.",
                    ]
                )
            }
            return error
        }
    }
}
