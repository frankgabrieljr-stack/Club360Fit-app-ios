import SwiftUI

/// Coach / admin shell — client list, gallery, and account (mirrors Android `AdminHomeScreen` tabs).
struct AdminHomeView: View {
    var body: some View {
        TabView {
            NavigationStack {
                CoachMainHubView()
            }
            .tabItem { Label("Hub", systemImage: "square.grid.2x2.fill") }

            AdminClientsTab()
                .tabItem { Label("Clients", systemImage: "person.3.fill") }

            NavigationStack {
                CoachMealPhotoInboxView()
            }
            .tabItem { Label("Meal inbox", systemImage: "tray.full") }

            NavigationStack {
                TransformationGalleryView()
            }
            .tabItem { Label("Gallery", systemImage: "photo.on.rectangle.angled") }

            NavigationStack {
                UserProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(Club360Theme.tealDark)
    }
}

// MARK: - Clients tab

private struct AdminClientsTab: View {
    @State private var model = AdminViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Club360ScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        adminListHeader

                        if model.isLoading {
                            ProgressView("Loading clients…")
                                .tint(Club360Theme.tealDark)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }

                        if let err = model.errorMessage {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .club360Glass(cornerRadius: 22)
                        }

                        if !model.isLoading, model.errorMessage == nil, model.clients.isEmpty {
                            ContentUnavailableView(
                                "No clients yet",
                                systemImage: "person.3",
                                description: Text("When members are linked to your coach account in Supabase, they appear here.")
                            )
                            .padding(.top, 24)
                        }

                        ForEach(model.clients, id: \.stableId) { client in
                            if let cid = client.id, !cid.isEmpty {
                                NavigationLink {
                                    AdminClientHubView(clientId: cid, displayTitle: AdminViewModel.listTitle(for: client))
                                } label: {
                                    AdminClientRow(title: AdminViewModel.listTitle(for: client), subtitle: "Plans, meals, progress")
                                }
                                .buttonStyle(.plain)
                            } else {
                                AdminClientRow(title: AdminViewModel.listTitle(for: client), subtitle: "Missing client id — check Supabase")
                                    .opacity(0.55)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Club360Fit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .task {
                await model.load()
            }
            .refreshable {
                await model.load()
            }
        }
    }

    private var adminListHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Image("LogoBurgundy")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text("Coach")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Club360Theme.burgundy)
                Text("Clients")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Club360Theme.burgundy)
            }
        }
        .padding(.top, 4)
    }
}

private struct AdminClientRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Club360Theme.cardTitle)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Club360Theme.cardSubtitle)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Club360Theme.cardSubtitle.opacity(0.8))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .club360Glass(cornerRadius: 28)
    }
}

// MARK: - Client hub (coach view of member tools)

struct AdminClientHubView: View {
    let clientId: String
    let displayTitle: String

    @State private var homeModel = ClientHomeViewModel()

    var body: some View {
        Group {
            if homeModel.isLoading {
                ZStack {
                    Club360ScreenBackground()
                    ProgressView("Loading client…")
                        .tint(Club360Theme.tealDark)
                }
            } else if let err = homeModel.errorMessage {
                ZStack {
                    Club360ScreenBackground()
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                        .club360Glass(cornerRadius: 22)
                        .padding()
                }
            } else {
                clientHubScroll
            }
        }
        .environment(homeModel)
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MyNotificationsView()
                        .environment(homeModel)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Club360Theme.tealDark)
                        if homeModel.unreadNotifications > 0 {
                            Text("\(min(homeModel.unreadNotifications, 99))")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(Circle().fill(Club360Theme.peachDeep))
                                .offset(x: 10, y: -10)
                        }
                    }
                }
            }
        }
        .task(id: clientId) {
            await homeModel.loadForClient(clientId: clientId)
        }
        .refreshable {
            await homeModel.loadForClient(clientId: clientId)
        }
        .onAppear {
            Task { await homeModel.reloadNotificationsCount() }
        }
    }

    private var clientHubScroll: some View {
        ZStack {
            Club360ScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .center, spacing: 14) {
                        Image("LogoBurgundy")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Member")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Club360Theme.cardSubtitle)
                                .textCase(.uppercase)
                            Text(homeModel.welcomeName)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Club360Theme.burgundy)
                        }
                    }
                    .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "square.grid.2x2.fill")
                                .foregroundStyle(Club360Theme.tealDark)
                            Text("Assignments")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Club360Theme.cardTitle)
                        }
                        Text("Create and assign workout plans, meal plans, and sessions from the Hub tab. Use the tiles below to review what’s assigned for \(homeModel.welcomeName).")
                            .font(.footnote)
                            .foregroundStyle(Club360Theme.cardSubtitle)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .club360Glass(cornerRadius: 28)

                    Text("Tools")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Club360Theme.cardTitle)
                        .textCase(.uppercase)
                        .tracking(0.8)

                    if homeModel.canViewEvents {
                        adminNextSessionCard
                    }

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        spacing: 12
                    ) {
                        NavigationLink {
                            MyWorkoutsView()
                                .environment(homeModel)
                        } label: {
                            Club360HomeTile(
                                title: "Workouts",
                                subtitle: workoutSubtitle,
                                systemImage: "figure.run",
                                accent: Club360Theme.mintDeep
                            )
                        }
                        .disabled(!homeModel.canViewWorkouts)
                        .opacity(homeModel.canViewWorkouts ? 1 : 0.45)

                        NavigationLink {
                            MyMealsView()
                                .environment(homeModel)
                        } label: {
                            Club360HomeTile(
                                title: "Meals",
                                subtitle: mealSubtitle,
                                systemImage: "takeoutbag.and.cup.and.straw.fill",
                                accent: Club360Theme.teal
                            )
                        }
                        .disabled(!homeModel.canViewNutrition)
                        .opacity(homeModel.canViewNutrition ? 1 : 0.45)

                        NavigationLink {
                            MyProgressView()
                                .environment(homeModel)
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
                                .environment(homeModel)
                        } label: {
                            Club360HomeTile(
                                title: "Habits",
                                subtitle: "Water · steps · sleep",
                                systemImage: "checkmark.circle.fill",
                                accent: Club360Theme.teal
                            )
                        }

                        if homeModel.canViewEvents {
                            NavigationLink {
                                MyScheduleView()
                                    .environment(homeModel)
                            } label: {
                                Club360HomeTile(
                                    title: "Schedule",
                                    subtitle: scheduleSubtitle,
                                    systemImage: "calendar",
                                    accent: Club360Theme.mintDeep
                                )
                            }
                        }

                        if homeModel.canViewPayments {
                            NavigationLink {
                                MyPaymentsView()
                                    .environment(homeModel)
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
                            MyMealPhotosView()
                                .environment(homeModel)
                        } label: {
                            Club360HomeTile(
                                title: "Meal photos",
                                subtitle: "Review uploads",
                                systemImage: "camera.fill",
                                accent: Club360Theme.purpleLight
                            )
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
    }

    private var adminNextSessionCard: some View {
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
            Text(homeModel.nextSessionLine ?? "No upcoming sessions scheduled.")
                .font(.body.weight(.semibold))
                .foregroundStyle(Club360Theme.cardTitle)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(homeModel.upcomingSessionCount) upcoming")
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
        guard homeModel.canViewWorkouts else { return "Disabled for this client" }
        if let t = homeModel.currentWorkoutTitle {
            return "Current: \(t) · \(homeModel.workoutPlanCount) plan\(homeModel.workoutPlanCount == 1 ? "" : "s")"
        }
        return homeModel.isLoading ? "…" : "Plans & sessions"
    }

    private var mealSubtitle: String {
        guard homeModel.canViewNutrition else { return "Disabled for this client" }
        if let t = homeModel.currentMealTitle {
            return "Current: \(t) · \(homeModel.mealPlanCount) plan\(homeModel.mealPlanCount == 1 ? "" : "s")"
        }
        return homeModel.isLoading ? "…" : "Nutrition"
    }

    private var progressSubtitle: String {
        let n = homeModel.progressCheckInCount
        return n == 0 ? "Metrics" : "\(n) check-in\(n == 1 ? "" : "s") logged"
    }

    private var scheduleSubtitle: String {
        if let line = homeModel.nextSessionLine {
            return "Next: \(line)"
        }
        return homeModel.upcomingSessionCount == 0 ? "No upcoming" : "\(homeModel.upcomingSessionCount) upcoming"
    }
}

#Preview {
    AdminHomeView()
        .environment(Club360AuthSession())
}
