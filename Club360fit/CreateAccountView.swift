import SwiftUI

/// Signup form — role is always "client"; promotion to admin is server-side only.
struct CreateAccountView: View {
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @State private var name = ""
    @State private var age = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var password = ""
    @State private var medicalConditions = ""
    @State private var foodRestrictions = ""
    @State private var mealsPerDay = ""
    @State private var workoutFrequency = ""
    @State private var overallGoal = ""
    @State private var isBusy = false
    @State private var needsEmailConfirmation = false
    @State private var passwordVisible = false

    var body: some View {
        Form {
            Section("Account") {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                PasswordFieldRow(
                    title: "Password",
                    text: $password,
                    isVisible: $passwordVisible,
                    isNewPassword: true
                )
            }
            Section("Profile") {
                TextField("Name", text: $name)
                TextField("Age", text: $age)
                    .keyboardType(.numberPad)
                TextField("Height", text: $height)
                TextField("Weight", text: $weight)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
            }
            Section("Health & goals") {
                TextField("Medical conditions", text: $medicalConditions, axis: .vertical)
                    .lineLimit(2 ... 4)
                TextField("Food restrictions", text: $foodRestrictions, axis: .vertical)
                    .lineLimit(2 ... 4)
                TextField("Meals per day", text: $mealsPerDay)
                TextField("Workout frequency", text: $workoutFrequency)
                TextField("Overall goal", text: $overallGoal, axis: .vertical)
                    .lineLimit(2 ... 4)
            }
            if needsEmailConfirmation {
                Section {
                    Text("Check your email to confirm your account, then sign in.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                        needsEmailConfirmation = false
                        let ok = await auth.signUp(
                            email: email,
                            password: password,
                            name: name,
                            age: age,
                            height: height,
                            weight: weight,
                            phone: phone,
                            medicalConditions: medicalConditions,
                            foodRestrictions: foodRestrictions,
                            mealsPerDay: mealsPerDay,
                            workoutFrequency: workoutFrequency,
                            overallGoal: overallGoal
                        )
                        if !ok, auth.errorMessage == nil {
                            needsEmailConfirmation = true
                        }
                        isBusy = false
                    }
                } label: {
                    if isBusy {
                        HStack {
                            ProgressView()
                                .tint(.white)
                            Text("Creating account…")
                        }
                    } else {
                        Text("Create account")
                    }
                }
                .buttonStyle(Club360PrimaryGradientButtonStyle())
                .listRowBackground(Color.clear)
                .disabled(isBusy || !canSubmit)
            }
            Section {
                NavigationLink("Sign in instead") {
                    SignInView()
                }
            }
        }
        .tint(Club360Theme.tealDark)
        .club360FormScreen()
        .navigationTitle("Create account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }
}

#Preview {
    NavigationStack {
        CreateAccountView()
            .environment(Club360AuthSession())
    }
}
