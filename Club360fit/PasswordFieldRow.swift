import SwiftUI

/// Password field with show/hide — matches Android `AuthScreen` visibility toggle.
struct PasswordFieldRow: View {
    let title: String
    @Binding var text: String
    @Binding var isVisible: Bool
    /// `false` = sign-in (`.password`); `true` = sign-up / change-password (`.newPassword`).
    var isNewPassword: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Group {
                if isVisible {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textContentType(isNewPassword ? .newPassword : .password)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(isVisible ? "Hide password" : "Show password")
            }
            .buttonStyle(.borderless)
        }
    }
}
