import Foundation

/// Supabase project (same as Android `SupabaseClient.kt`).
/// The anon key must be **one single line** inside the quotes — no line breaks in the middle of the string.
enum AppConfig {
    static let supabaseURL = URL(string: "https://mjkrokpctcieahxtxvxq.supabase.co")!
    /// Same value as Android `local.properties` → `SUPABASE_ANON_KEY` (copy the whole `eyJ…` line as one line).
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qa3Jva3BjdGNpZWFoeHR4dnhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMyNzc2OTEsImV4cCI6MjA4ODg1MzY5MX0.EkHGULoDFxqJOpH14_L6-THsi4MmIrjAbots-xaipRE"

    /// Same as Android `Auth` redirect for password reset (`club360fit://reset`). Add URL scheme `club360fit` in Xcode → Target → Info → URL Types if you want the link to open the app.
    static let passwordResetRedirectURL = URL(string: "club360fit://reset")!
}
