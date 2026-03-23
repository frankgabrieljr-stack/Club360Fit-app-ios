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
}
