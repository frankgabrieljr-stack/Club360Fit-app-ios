import Foundation
import Supabase

/// Shared Supabase client — mirrors Android `SupabaseClient.kt` (same project URL & anon key).
enum Club360FitSupabase: Sendable {
    /// Same bucket id as Android `SupabaseClient.MEAL_PHOTOS_BUCKET`.
    static let mealPhotosBucket = "meal-photos"
    /// Android `SupabaseClient.TRANSFORMATIONS_BUCKET`.
    static let transformationsBucket = "transformations"
    /// Android `SupabaseClient.AVATARS_BUCKET`.
    static let avatarsBucket = "avatars"

    static let shared = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )

    /// Password recovery / deep links (`club360fit://reset?...`). Keeps `import Supabase` out of `Club360fitApp.swift`.
    static func handleAuthRedirectURL(_ url: URL) {
        shared.auth.handle(url)
    }

    /// Options for Edge Functions that call `getUser()` with the caller’s JWT (`set-user-role`, `transfer-client`, etc.).
    /// Refreshes the session first so the access token is not expired (the Functions **gateway** validates JWT before
    /// your code runs). Sends explicit `Authorization` + `apikey` on each invoke so the request matches what Supabase
    /// expects, even if header merging on the shared ``FunctionsClient`` would otherwise omit them.
    static func functionInvokeOptions<T: Encodable>(body: T) async throws -> FunctionInvokeOptions {
        _ = try await shared.auth.refreshSession()
        let session = try await shared.auth.session
        shared.functions.setAuth(token: session.accessToken)
        let headers = [
            "Authorization": "Bearer \(session.accessToken)",
            "apikey": AppConfig.supabaseAnonKey,
        ]
        return FunctionInvokeOptions(headers: headers, body: body)
    }
}
