import SwiftUI

/// Signed-in password change (Android: update user password from profile / settings).
struct ChangePasswordView: View {
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showNew = false
    @State private var showConfirm = false
    @State private var isSaving = false
    @State private var message: String?
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                PasswordFieldRow(
                    title: "New password",
                    text: $newPassword,
                    isVisible: $showNew,
                    isNewPassword: true
                )
                PasswordFieldRow(
                    title: "Confirm new password",
                    text: $confirmPassword,
                    isVisible: $showConfirm,
                    isNewPassword: true
                )
            } footer: {
                Text("Use at least 6 characters. This updates your Supabase account password.")
                    .font(.footnote)
            }
            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            if let message {
                Section {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
            Section {
                Button {
                    Task {
                        await save()
                    }
                } label: {
                    if isSaving {
                        HStack {
                            ProgressView()
                                .tint(.white)
                            Text("Updating…")
                        }
                    } else {
                        Text("Update password")
                    }
                }
                .buttonStyle(Club360PrimaryGradientButtonStyle())
                .listRowBackground(Color.clear)
                .disabled(isSaving || !canSave)
            }
        }
        .tint(Club360Theme.tealDark)
        .club360FormScreen()
        .navigationTitle("Change password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }

    private var canSave: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }

    private func save() async {
        error = nil
        message = nil
        guard newPassword == confirmPassword else {
            error = "Passwords do not match."
            return
        }
        isSaving = true
        if let err = await auth.updatePassword(newPassword: newPassword) {
            error = err
        } else {
            message = "Password updated."
            newPassword = ""
            confirmPassword = ""
        }
        isSaving = false
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
            .environment(Club360AuthSession())
    }
}
