import SwiftUI

/// Email reset link — same flow as Android `sendPasswordResetEmail` / `ResetPasswordScreen` entry.
struct ForgotPasswordView: View {
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @State private var email = ""
    @State private var isSending = false
    @State private var successMessage: String?
    @State private var localError: String?

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                Text("We’ll email you a link to reset your password. Add the URL scheme **club360fit** in Xcode (URL Types) so the link can open this app, or use the link from any browser.")
                    .font(.footnote)
            }
            if let ok = successMessage {
                Section {
                    Text(ok)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
            if let err = localError {
                Section {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            Section {
                Button {
                    Task {
                        isSending = true
                        localError = nil
                        successMessage = nil
                        if let err = await auth.sendPasswordResetEmail(email: email) {
                            localError = err
                        } else {
                            successMessage = "Check your inbox for a reset link."
                        }
                        isSending = false
                    }
                } label: {
                    if isSending {
                        HStack {
                            ProgressView()
                            Text("Sending…")
                        }
                    } else {
                        Text("Send reset link")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSending || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Forgot password")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
            .environment(Club360AuthSession())
    }
}
