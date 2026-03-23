import Auth
import SwiftUI

/// Client shell: tab bar + live home data from Supabase (Android `ClientHomeScreen` / `ClientHomeViewModel`).
struct ClientHomeView: View {
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @State private var homeModel = ClientHomeViewModel()

    var body: some View {
        TabView {
            ClientHomeTab()
                .tabItem { Label("Home", systemImage: "house.fill") }

            ClientWorkoutsTab()
                .tabItem { Label("Workouts", systemImage: "figure.strengthtraining.traditional") }

            ClientMealsTab()
                .tabItem { Label("Meals", systemImage: "fork.knife") }

            ClientProgressTab()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

            NavigationStack {
                UserProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(Club360Theme.burgundy)
        .environment(homeModel)
        .task(id: auth.session?.user.id) {
            guard let session = auth.session else { return }
            await homeModel.load(session: session)
        }
    }
}

// MARK: - Home tab

private struct ClientHomeTab: View {
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if home.isLoading {
                        ProgressView("Loading your dashboard…")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }

                    if let err = home.errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Text("Welcome, \(home.welcomeName)")
                        .font(.title2.bold())
                        .foregroundStyle(Club360Theme.burgundy)

                    Text("Today")
                        .font(.headline)
                        .foregroundStyle(Club360Theme.burgundy)

                    if home.canViewEvents {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Next session")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Club360Theme.burgundy)
                            Text(home.nextSessionLine ?? "No upcoming sessions scheduled.")
                                .font(.body)
                            Text("\(home.upcomingSessionCount) upcoming")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        NavigationLink {
                            MyWorkoutsView()
                        } label: {
                            HomeTile(
                                title: "Workouts",
                                subtitle: workoutSubtitle,
                                systemImage: "figure.run"
                            )
                        }
                        .disabled(!home.canViewWorkouts)

                        NavigationLink {
                            MyMealsView()
                        } label: {
                            HomeTile(
                                title: "Meals",
                                subtitle: mealSubtitle,
                                systemImage: "takeoutbag.and.cup.and.straw.fill"
                            )
                        }
                        .disabled(!home.canViewNutrition)

                        NavigationLink {
                            MyProgressView()
                        } label: {
                            HomeTile(
                                title: "Progress",
                                subtitle: progressSubtitle,
                                systemImage: "chart.line.uptrend.xyaxis"
                            )
                        }

                        NavigationLink {
                            MyDailyHabitsView()
                        } label: {
                            HomeTile(
                                title: "Daily habits",
                                subtitle: "Water · steps · sleep",
                                systemImage: "checkmark.circle.fill"
                            )
                        }

                        if home.canViewEvents {
                            NavigationLink {
                                MyScheduleView()
                            } label: {
                                HomeTile(
                                    title: "Schedule",
                                    subtitle: scheduleSubtitle,
                                    systemImage: "calendar"
                                )
                            }
                        }

                        if home.canViewPayments {
                            NavigationLink {
                                MyPaymentsView()
                            } label: {
                                HomeTile(
                                    title: "Payments",
                                    subtitle: "Venmo or Zelle",
                                    systemImage: "dollarsign.circle.fill"
                                )
                            }
                        }

                        NavigationLink {
                            TransformationGalleryView()
                        } label: {
                            HomeTile(
                                title: "Gallery",
                                subtitle: "Transformation photos",
                                systemImage: "photo.on.rectangle.angled"
                            )
                        }

                        NavigationLink {
                            UserProfileView()
                        } label: {
                            HomeTile(
                                title: "Profile",
                                subtitle: "Photo & account",
                                systemImage: "person.fill"
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Club360Fit")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        MyNotificationsView()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                            if home.unreadNotifications > 0 {
                                Text("\(min(home.unreadNotifications, 99))")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
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
        }
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

private struct HomeTile: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Club360Theme.burgundy)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Other tabs (My Meals / My Progress)

private struct ClientWorkoutsTab: View {
    var body: some View {
        NavigationStack {
            MyWorkoutsView()
        }
    }
}

private struct ClientMealsTab: View {
    var body: some View {
        NavigationStack {
            MyMealsView()
        }
    }
}

private struct ClientProgressTab: View {
    var body: some View {
        NavigationStack {
            MyProgressView()
        }
    }
}

