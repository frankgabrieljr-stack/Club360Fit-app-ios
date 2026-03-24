import SwiftUI

/// Club360Fit design system — glass / soft gradients (mint, teal, peach, purple) inspired by the product redesign.
enum Club360Theme {
    // MARK: Legacy brand (still used for subtle accents)

    static let burgundy = Color(red: 0.45, green: 0.11, blue: 0.16)

    // MARK: Redesign palette

    static let mint = Color(red: 0.78, green: 0.94, blue: 0.90)
    static let mintDeep = Color(red: 0.42, green: 0.82, blue: 0.72)
    static let teal = Color(red: 0.38, green: 0.78, blue: 0.82)
    static let tealDark = Color(red: 0.12, green: 0.48, blue: 0.55)
    static let peach = Color(red: 1.0, green: 0.86, blue: 0.78)
    static let peachDeep = Color(red: 0.98, green: 0.68, blue: 0.58)
    static let purple = Color(red: 0.40, green: 0.26, blue: 0.62)
    static let purpleLight = Color(red: 0.58, green: 0.45, blue: 0.82)

    /// Hero titles, nav emphasis (teal — large nav titles still use system `.primary` when needed)
    static let titleForeground = tealDark

    /// Primary text on light cards — high contrast vs mint gradient
    static let cardTitle = Color(red: 0.08, green: 0.09, blue: 0.1)

    /// Secondary lines on cards (darker than `.secondary` on pale UI)
    static let cardSubtitle = Color(red: 0.38, green: 0.4, blue: 0.42)

    /// Primary actions / links in redesigned screens
    static let accentPrimary = purple

    /// Frosted tile base — sits under material so tiles don’t blend into the background
    static let cardBaseFill = Color.white.opacity(0.82)

    // MARK: Gradients

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.90, green: 0.97, blue: 0.95),
                Color(red: 0.82, green: 0.93, blue: 0.96),
                Color(red: 0.88, green: 0.94, blue: 0.98),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var primaryButtonGradient: LinearGradient {
        LinearGradient(
            colors: [purpleLight, purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Next-session / highlight cards (peach coral)
    static var sessionCardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.88, blue: 0.78),
                peachDeep.opacity(0.95),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
