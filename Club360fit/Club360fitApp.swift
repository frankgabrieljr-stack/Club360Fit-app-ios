//
//  Club360fitApp.swift
//  Club360fit
//

import SwiftUI

@main
struct Club360fitApp: App {
    @State private var authSession = Club360AuthSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authSession)
                .onOpenURL { url in
                    // Password-reset links: `club360fit://reset?...` — add URL scheme in Xcode → Target → Info.
                    Club360FitSupabase.handleAuthRedirectURL(url)
                }
        }
    }
}
