import Auth
import Foundation
import Observation
import SwiftUI
import Supabase

/// Session + email/password auth aligned with Android `AuthViewModel`.
/// Uses `@Observable` (not `ObservableObject`) for Swift 6 + `@MainActor` compatibility.
@Observable
@MainActor
final class Club360AuthSession {
    private(set) var session: Session?
    private(set) var isLoading = true
    var errorMessage: String?

    private let client = Club360FitSupabase.shared

    init() {
        Task { await bootstrap() }
    }

    func bootstrap() async {
        isLoading = true
        session = client.auth.currentSession
        isLoading = false
        Task { await observeAuthStateChanges() }
    }

    private func observeAuthStateChanges() async {
        // Class is @MainActor — assign directly (avoids spurious `await` on `MainActor.run`).
        for await (_, newSession) in client.auth.authStateChanges {
            session = newSession ?? client.auth.currentSession
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            _ = try await client.auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            // Match Android: refresh user so `user_metadata.role` is current.
            _ = try await client.auth.user()
            session = client.auth.currentSession
        } catch {
            errorMessage = Self.userFacingAuthError(error)
        }
    }

    /// - Returns: `true` if a session was created immediately; `false` if email confirmation is required (no session yet).
    func signUp(
        email: String,
        password: String,
        name: String,
        age: String,
        height: String,
        weight: String,
        phone: String,
        medicalConditions: String,
        foodRestrictions: String,
        mealsPerDay: String,
        workoutFrequency: String,
        overallGoal: String
    ) async -> Bool {
        errorMessage = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let data: [String: AnyJSON] = [
            "name": .string(name),
            "age": .string(age),
            "height": .string(height),
            "weight": .string(weight),
            "phone": .string(phone),
            "medical_conditions": .string(medicalConditions),
            "food_restrictions": .string(foodRestrictions),
            "meals_per_day": .string(mealsPerDay),
            "workout_frequency": .string(workoutFrequency),
            "overall_goal": .string(overallGoal),
            /// Coach/admin access is assigned in Supabase (Auth → Users → user metadata), not from the app.
            "role": .string("client"),
        ]
        do {
            let response = try await client.auth.signUp(email: trimmedEmail, password: password, data: data)
            if response.session != nil {
                _ = try? await client.auth.user()
                session = client.auth.currentSession
                return true
            }
            session = nil
            return false
        } catch {
            errorMessage = Self.userFacingAuthError(error)
            return false
        }
    }

    func signOut() async {
        errorMessage = nil
        do {
            try await client.auth.signOut()
            session = nil
        } catch {
            errorMessage = Self.userFacingAuthError(error)
        }
    }

    /// Same as Android `sendPasswordResetEmail` — user receives email with reset link.
    /// - Returns: `nil` on success, or an error message string.
    func sendPasswordResetEmail(email: String) async -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Enter your email address." }
        do {
            try await client.auth.resetPasswordForEmail(
                trimmed,
                redirectTo: AppConfig.passwordResetRedirectURL
            )
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Change password while signed in (Profile → Change password).
    /// - Returns: `nil` on success, or an error message string.
    func updatePassword(newPassword: String) async -> String? {
        guard newPassword.count >= 6 else { return "Password must be at least 6 characters." }
        do {
            _ = try await client.auth.update(user: UserAttributes(password: newPassword))
            _ = try await client.auth.user()
            session = client.auth.currentSession
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Merges keys into existing `user_metadata` so fields like `name` and `role` are not wiped when updating `avatar_url`.
    func updateUserMetadata(_ updates: [String: AnyJSON]) async throws {
        let existing = session?.user.userMetadata ?? [:]
        let merged = existing.merging(updates) { _, new in new }
        _ = try await client.auth.update(user: UserAttributes(data: merged))
        _ = try await client.auth.user()
        session = client.auth.currentSession
    }

    /// Supabase often returns a generic "Database error saving new user" when a trigger or constraint fails server-side.
    private static func userFacingAuthError(_ error: Error) -> String {
        let base: String = {
            if let authError = error as? AuthError {
                switch authError {
                case let .api(message, _, _, _):
                    return message
                default:
                    break
                }
            }
            return error.localizedDescription
        }()

        if base.localizedCaseInsensitiveContains("database error saving new user") {
            return base + "\n\nThis is a Supabase database issue (not your form). Common causes: a trigger on auth.users that inserts into another table failed, RLS blocked that insert, or a NOT NULL/default constraint. Check Supabase → Logs → Postgres for the exact SQL error, and review triggers on auth.users."
        }
        return base
    }
}
