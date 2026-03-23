import SwiftUI

struct SignInView: View {
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @State private var email = ""
    @State private var password = ""
    @State private var passwordVisible = false
    @State private var isBusy = false

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                PasswordFieldRow(
                    title: "Password",
                    text: $password,
                    isVisible: $passwordVisible,
                    isNewPassword: false
                )
            }
            Section {
                NavigationLink("Forgot password?") {
                    ForgotPasswordView()
                }
            }
            if let err = auth.errorMessage {
                Section {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            Section {
                Button {
                    Task {
                        isBusy = true
                        await auth.signIn(email: email, password: password)
                        isBusy = false
                    }
                } label: {
                    if isBusy {
                        HStack {
                            ProgressView()
                            Text("Signing in…")
                        }
                    } else {
                        Text("Sign in")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
            }
            Section {
                NavigationLink("Create account instead") {
                    CreateAccountView()
                }
            }
        }
        .navigationTitle("Sign in")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SignInView()
            .environment(Club360AuthSession())
    }
}
