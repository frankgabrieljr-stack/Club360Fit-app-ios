import Auth
import SwiftUI

/// Client shell: tab bar + live home data from Supabase (Android `ClientHomeScreen` / `ClientHomeViewModel`).
struct ClientHomeView: View {
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @State private var homeModel = ClientHomeViewModel()
    @State private var tabRouter = ClientTabRouter()

    var body: some View {
        @Bindable var tabRouter = tabRouter
        TabView(selection: $tabRouter.selectedTab) {
            ClientHomeTab(tabRouter: tabRouter)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(ClientTab.home)

            ClientWorkoutsTab()
                .tabItem { Label("Workouts", systemImage: "figure.strengthtraining.traditional") }
                .tag(ClientTab.workouts)

            ClientMealsTab(tabRouter: tabRouter)
                .tabItem { Label("Meals", systemImage: "fork.knife") }
                .tag(ClientTab.meals)

            ClientProgressTab()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(ClientTab.progress)

            NavigationStack {
                UserProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(ClientTab.profile)
        }
        .tint(Club360Theme.tealDark)
        .environment(homeModel)
        .environment(\.clientTabRouter, tabRouter)
        .task(id: auth.session?.user.id) {
            guard let session = auth.session else { return }
            await homeModel.load(session: session)
        }
    }
}

// MARK: - Home tab

private struct ClientHomeTab: View {
    @Bindable var tabRouter: ClientTabRouter
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel

    var body: some View {
        NavigationStack(path: $tabRouter.homePath) {
            ZStack {
                Club360ScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if home.isLoading {
                            ProgressView("Loading your dashboard…")
                                .tint(Club360Theme.tealDark)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }

                        if let err = home.errorMessage {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .club360Glass(cornerRadius: 22)
                        }

                        HStack(alignment: .center, spacing: 14) {
                            Image("LogoBurgundy")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Welcome")
                                    .font(.largeTitle.weight(.bold))
                                    .foregroundStyle(Club360Theme.burgundy)
                                Text(home.welcomeName)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Club360Theme.burgundy)
                            }
                        }
                        .padding(.top, 4)

                        Text("Today")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Club360Theme.cardTitle)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        if home.canViewEvents {
                            nextSessionCard
                        }

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            NavigationLink {
                                MyWorkoutsView()
                                    .environment(home)
                            } label: {
                                Club360HomeTile(
                                    title: "Workouts",
                                    subtitle: workoutSubtitle,
                                    systemImage: "figure.run",
                                    accent: Club360Theme.mintDeep
                                )
                            }
                            .disabled(!home.canViewWorkouts)
                            .opacity(home.canViewWorkouts ? 1 : 0.45)

                            NavigationLink {
                                MyMealsView()
                                    .environment(home)
                            } label: {
                                Club360HomeTile(
                                    title: "Meals",
                                    subtitle: mealSubtitle,
                                    systemImage: "takeoutbag.and.cup.and.straw.fill",
                                    accent: Club360Theme.teal
                                )
                            }
                            .disabled(!home.canViewNutrition)
                            .opacity(home.canViewNutrition ? 1 : 0.45)

                            NavigationLink {
                                MyProgressView()
                                    .environment(home)
                            } label: {
                                Club360HomeTile(
                                    title: "Progress",
                                    subtitle: progressSubtitle,
                                    systemImage: "chart.line.uptrend.xyaxis",
                                    accent: Club360Theme.tealDark
                                )
                            }

                            NavigationLink {
                                MyDailyHabitsView()
                                    .environment(home)
                            } label: {
                                Club360HomeTile(
                                    title: "Habits",
                                    subtitle: "Water · steps · sleep",
                                    systemImage: "checkmark.circle.fill",
                                    accent: Club360Theme.teal
                                )
                            }

                            if home.canViewEvents {
                                NavigationLink {
                                    MyScheduleView()
                                        .environment(home)
                                } label: {
                                    Club360HomeTile(
                                        title: "Schedule",
                                        subtitle: scheduleSubtitle,
                                        systemImage: "calendar",
                                        accent: Club360Theme.mintDeep
                                    )
                                }
                            }

                            if home.canViewPayments {
                                NavigationLink {
                                    MyPaymentsView()
                                        .environment(home)
                                } label: {
                                    Club360HomeTile(
                                        title: "Payments",
                                        subtitle: "Venmo or Zelle",
                                        systemImage: "dollarsign.circle.fill",
                                        accent: Club360Theme.mintDeep
                                    )
                                }
                            }

                            NavigationLink {
                                TransformationGalleryView()
                            } label: {
                                Club360HomeTile(
                                    title: "Gallery",
                                    subtitle: "Transformation photos",
                                    systemImage: "photo.on.rectangle.angled",
                                    accent: Club360Theme.purpleLight
                                )
                            }

                            NavigationLink {
                                UserProfileView()
                            } label: {
                                Club360HomeTile(
                                    title: "Profile",
                                    subtitle: "Photo & account",
                                    systemImage: "person.fill",
                                    accent: Club360Theme.purple
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        MyNotificationsView()
                            .environment(home)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Club360Theme.tealDark)
                            if home.unreadNotifications > 0 {
                                Text("\(min(home.unreadNotifications, 99))")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(
                                        Circle().fill(Club360Theme.peachDeep)
                                    )
                                    .offset(x: 10, y: -10)
                            }
                        }
                    }
                }
            }
            .onAppear {
                Task { await home.reloadNotificationsCount() }
            }
            .refreshable {
                if let s = auth.session {
                    await home.load(session: s)
                }
            }
            .navigationDestination(for: HomeDeepLink.self) { link in
                switch link {
                case .schedule:
                    MyScheduleView()
                        .environment(home)
                case .payments:
                    MyPaymentsView()
                        .environment(home)
                case .habits:
                    MyDailyHabitsView()
                        .environment(home)
                case .gallery:
                    TransformationGalleryView()
                }
            }
        }
    }

    private var nextSessionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Next session")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Club360Theme.cardSubtitle)
                    .textCase(.uppercase)
                Spacer()
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(Club360Theme.cardSubtitle)
            }
            Text(home.nextSessionLine ?? "No upcoming sessions scheduled.")
                .font(.body.weight(.semibold))
                .foregroundStyle(Club360Theme.cardTitle)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(home.upcomingSessionCount) upcoming")
                .font(.caption.weight(.medium))
                .foregroundStyle(Club360Theme.cardSubtitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Club360Theme.sessionCardGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.9), Color.black.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.25
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 12)
    }

    private var workoutSubtitle: String {
        guard home.canViewWorkouts else { return "Disabled by coach" }
        if let t = home.currentWorkoutTitle {
            return "Current: \(t) · \(home.workoutPlanCount) plan\(home.workoutPlanCount == 1 ? "" : "s")"
        }
        return home.isLoading ? "…" : "Plans & sessions"
    }

    private var mealSubtitle: String {
        guard home.canViewNutrition else { return "Disabled by coach" }
        if let t = home.currentMealTitle {
            return "Current: \(t) · \(home.mealPlanCount) plan\(home.mealPlanCount == 1 ? "" : "s")"
        }
        return home.isLoading ? "…" : "Nutrition"
    }

    private var progressSubtitle: String {
        let n = home.progressCheckInCount
        return n == 0 ? "Metrics" : "\(n) check-in\(n == 1 ? "" : "s") logged"
    }

    private var scheduleSubtitle: String {
        if let line = home.nextSessionLine {
            return "Next: \(line)"
        }
        return home.upcomingSessionCount == 0 ? "No upcoming" : "\(home.upcomingSessionCount) upcoming"
    }
}

// MARK: - Other tabs

private struct ClientWorkoutsTab: View {
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel

    var body: some View {
        NavigationStack {
            MyWorkoutsView()
                .environment(home)
        }
    }
}

private struct ClientMealsTab: View {
    @Bindable var tabRouter: ClientTabRouter
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel

    var body: some View {
        NavigationStack(path: $tabRouter.mealsPath) {
            MyMealsView()
                .environment(home)
                .navigationDestination(for: MealsDeepLink.self) { link in
                    switch link {
                    case .mealPhotos:
                        MyMealPhotosView()
                            .environment(home)
                    }
                }
        }
    }
}

private struct ClientProgressTab: View {
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel

    var body: some View {
        NavigationStack {
            MyProgressView()
                .environment(home)
        }
    }
}
