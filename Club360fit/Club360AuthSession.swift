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
        for await (_, newSession) in await client.auth.authStateChanges {
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
            errorMessage = error.localizedDescription
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
        overallGoal: String,
        isAdmin: Bool
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
            "role": .string(isAdmin ? "admin" : "client"),
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
            errorMessage = error.localizedDescription
            return false
        }
    }

    func signOut() async {
        errorMessage = nil
        do {
            try await client.auth.signOut()
            session = nil
        } catch {
            errorMessage = error.localizedDescription
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

    /// Merge metadata keys (e.g. `avatar_url`) — same idea as Android `auth.updateUser { data = … }`.
    func updateUserMetadata(_ data: [String: AnyJSON]) async throws {
        _ = try await client.auth.update(user: UserAttributes(data: data))
        _ = try await client.auth.user()
        session = client.auth.currentSession
    }
}
