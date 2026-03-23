import Auth
import SwiftUI

private enum AuthDestination: Hashable {
    case signIn
    case createAccount
}

/// Root: loading → signed-in (client vs admin) → unauthenticated welcome flow.
struct RootView: View {
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @State private var path = NavigationPath()

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView("Loading…")
            } else if let session = auth.session {
                if session.userIsAdmin {
                    AdminHomeView()
                } else {
                    ClientHomeView()
                }
            } else {
                NavigationStack(path: $path) {
                    WelcomeView(
                        onSignIn: { path.append(AuthDestination.signIn) },
                        onCreateAccount: { path.append(AuthDestination.createAccount) }
                    )
                    .navigationDestination(for: AuthDestination.self) { dest in
                        switch dest {
                        case .signIn:
                            SignInView()
                        case .createAccount:
                            CreateAccountView()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(Club360AuthSession())
}
