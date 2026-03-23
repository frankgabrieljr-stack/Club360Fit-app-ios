import SwiftUI

/// Parity with Android `WelcomeScreen`: logo, tagline, Create account / Sign in.
struct WelcomeView: View {
    let onSignIn: () -> Void
    let onCreateAccount: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image("LogoBurgundy")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text("Welcome to Club 360 Fit")
                .font(.title2.bold())
                .foregroundStyle(Club360Theme.burgundy)
                .multilineTextAlignment(.center)
            Text("Your profile, nutrition, and workouts in one place.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 24)
            Button(action: onCreateAccount) {
                Text("Create account")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Club360Theme.burgundy)
            Button(action: onSignIn) {
                Text("Sign in")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(Club360Theme.burgundy)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(.systemBackground))
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        WelcomeView(onSignIn: {}, onCreateAccount: {})
    }
}
