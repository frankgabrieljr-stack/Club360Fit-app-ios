import Observation
import SwiftUI

private enum ClientTabRouterKey: EnvironmentKey {
    static let defaultValue: ClientTabRouter? = nil
}

extension EnvironmentValues {
    /// When set (member shell), notification taps switch tabs / push deep links.
    var clientTabRouter: ClientTabRouter? {
        get { self[ClientTabRouterKey.self] }
        set { self[ClientTabRouterKey.self] = newValue }
    }
}

/// Main tabs for the member shell (`ClientHomeView`).
enum ClientTab: Int, Hashable, CaseIterable {
    case home = 0
    case workouts = 1
    case meals = 2
    case progress = 3
    case profile = 4
}

enum HomeDeepLink: Hashable {
    case schedule
    case payments
    case habits
    case gallery
}

enum MealsDeepLink: Hashable {
    case mealPhotos
}

/// Routes Updates / notification taps to the correct tab and pushed screen.
@Observable
@MainActor
final class ClientTabRouter {
    var selectedTab: ClientTab = .home
    var homePath = NavigationPath()
    var mealsPath = NavigationPath()

    /// Apply routing from a notification row (`kind` + optional `ref_type`).
    func openNotification(_ n: ClientNotificationDTO) {
        homePath = NavigationPath()
        mealsPath = NavigationPath()
        let kind = n.routingKind
        switch kind {
        case "meal_feedback", "meal_photo":
            selectedTab = .meals
            mealsPath.append(MealsDeepLink.mealPhotos)
        case "workout_plan", "workout":
            selectedTab = .workouts
        case "meal_plan", "nutrition":
            selectedTab = .meals
        case "schedule", "session":
            selectedTab = .home
            homePath.append(HomeDeepLink.schedule)
        case "payment", "payment_reminder":
            selectedTab = .home
            homePath.append(HomeDeepLink.payments)
        case "progress", "progress_checkin", "check_in":
            selectedTab = .progress
        case "habit", "daily_habit":
            selectedTab = .home
            homePath.append(HomeDeepLink.habits)
        case "gallery", "transformation":
            selectedTab = .home
            homePath.append(HomeDeepLink.gallery)
        case "client_payment", "payment_confirmation":
            // Client submitted payment info — stay on home payments
            selectedTab = .home
            homePath.append(HomeDeepLink.payments)
        default:
            selectedTab = .home
        }
    }
}
