import SwiftUI

/// Parity with Android `WelcomeScreen`: logo, tagline, Sign in (primary) / Create account (outlined).
struct WelcomeView: View {
    let onSignIn: () -> Void
    let onCreateAccount: () -> Void

    var body: some View {
        ZStack {
            Club360ScreenBackground()

            VStack(spacing: 24) {
                Image("LogoBurgundy")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.08), radius: 16, y: 8)

                Text("Welcome to Club 360 Fit")
                    .font(.title2.bold())
                    .foregroundStyle(Club360Theme.burgundy)
                    .multilineTextAlignment(.center)
                Text("Your profile, nutrition, and workouts in one place.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 24)

                Button(action: onSignIn) {
                    Text("Sign in")
                }
                .buttonStyle(Club360PrimaryGradientButtonStyle())

                Button(action: onCreateAccount) {
                    Text("Create account")
                        .font(.headline)
                        .foregroundStyle(Club360Theme.burgundy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Club360Theme.burgundy.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        WelcomeView(onSignIn: {}, onCreateAccount: {})
    }
}
