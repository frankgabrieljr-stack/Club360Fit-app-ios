import SwiftUI

/// Placeholder for Android admin / coach home — add client list & tools next.
struct AdminHomeView: View {
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Admin / Coach")
                    .font(.title2.bold())
                Text("Port coach screens from Android (clients, meal reviews, etc.).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Sign out", role: .destructive) {
                    Task { await auth.signOut() }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Club360Fit")
        }
    }
}
