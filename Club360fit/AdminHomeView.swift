import Auth
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
        .tint(Club360Theme.burgundy)
        .preferredColorScheme(.light)
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
                                    AdminClientRow(
                                        title: AdminViewModel.listTitle(for: client),
                                        subtitle: "Plans, meals, progress",
                                        platformRole: model.profileRolesByUserId[client.userId]
                                    )
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
    var platformRole: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Club360Theme.cardTitle)
                if let platformRole {
                    Text(platformRole == "admin" ? "App login: Admin" : "App login: Client")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(platformRole == "admin" ? Club360Theme.tealDark : Club360Theme.captionOnGlass)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Club360Theme.captionOnGlass)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Club360Theme.captionOnGlass.opacity(0.85))
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

    @Environment(\.dismiss) private var dismiss
    @Environment(Club360AuthSession.self) private var auth

    @State private var homeModel = ClientHomeViewModel()
    @State private var roleBusy = false
    @State private var roleError: String?
    @State private var roleSuccess: String?
    @State private var desiredCoachAccess = false
    @State private var showApplyConfirm = false
    @State private var accessWorkouts = true
    @State private var accessNutrition = true
    @State private var accessEvents = false
    @State private var accessPayments = false
    @State private var accessBusy = false
    @State private var accessError: String?
    @State private var accessSuccess: String?
    @State private var transferTargetCoachId = ""
    @State private var transferBusy = false
    @State private var transferError: String?
    @State private var showTransferConfirm = false
    @State private var showCoachDirectorySheet = false
    @State private var showTransferSuccess = false

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
                    MyNotificationsView(inbox: .coach)
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
                        memberAvatar
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(homeModel.platformAccessCaption)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Club360Theme.captionOnGlass)
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
                            .foregroundStyle(Club360Theme.captionOnGlass)
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
                                systemImage: "figure.strengthtraining.traditional",
                                accent: Club360Theme.burgundyLight
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
                                    systemImage: "calendar.badge.clock",
                                    accent: Club360Theme.burgundy
                                )
                            }
                        }

                        NavigationLink {
                            CoachPaymentSettingsView(clientId: clientId, clientDisplayName: displayTitle)
                        } label: {
                            Club360HomeTile(
                                title: "Payment setup",
                                subtitle: "Venmo, Zelle, due date",
                                systemImage: "square.and.pencil",
                                accent: Club360Theme.burgundy
                            )
                        }

                        if homeModel.canViewPayments {
                            NavigationLink {
                                MyPaymentsView()
                                    .environment(homeModel)
                            } label: {
                                Club360HomeTile(
                                    title: "Payments (preview)",
                                    subtitle: "Same as member sees",
                                    systemImage: "banknote.fill",
                                    accent: Club360Theme.burgundy
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

                        if homeModel.memberAuthUserId != nil {
                            NavigationLink {
                                clientSettingsView
                            } label: {
                                Club360HomeTile(
                                    title: "Member settings",
                                    subtitle: "Access and transfer",
                                    systemImage: "slider.horizontal.3",
                                    accent: Club360Theme.burgundy
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
    }

    private var memberAvatar: some View {
        Group {
            if let uid = homeModel.memberAuthUserId,
               let url = ClientDataService.publicAvatarURLForAuthUserId(uid) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Club360Theme.creamWarm
                            ProgressView()
                                .tint(Club360Theme.burgundy)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image("LogoBurgundy")
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    }
                }
            } else {
                Image("LogoBurgundy")
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            }
        }
    }

    private var clientSettingsView: some View {
        ZStack {
            Club360ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Account access")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Club360Theme.cardTitle)
                        Text(
                            "Use the toggle, then tap Apply. Requires the set-user-role Edge Function deployed to your Supabase project. The member must sign out and sign in again."
                        )
                        .font(.footnote)
                        .foregroundStyle(Club360Theme.captionOnGlass)
                        .fixedSize(horizontal: false, vertical: true)

                        Toggle(isOn: $desiredCoachAccess) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Coach / admin access")
                                    .foregroundStyle(Club360Theme.cardTitle)
                                Text("Off = member-only access")
                                    .font(.caption)
                                    .foregroundStyle(Club360Theme.captionOnGlass)
                            }
                        }
                        .tint(Club360Theme.burgundy)
                        .disabled(roleBusy)

                        if let roleSuccess {
                            Text(roleSuccess)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Club360Theme.burgundy)
                        }
                        if let roleError {
                            Text(roleError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Button {
                            showApplyConfirm = true
                        } label: {
                            Text(roleBusy ? "Updating…" : "Apply")
                        }
                        .buttonStyle(Club360PrimaryGradientButtonStyle())
                        .disabled(roleBusy)
                        .confirmationDialog(
                            desiredCoachAccess ? "Grant coach/admin access?" : "Set member-only access?",
                            isPresented: $showApplyConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("Apply", role: .destructive) {
                                Task { await applyMemberRole(desiredCoachAccess ? "admin" : "client") }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text(
                                desiredCoachAccess
                                    ? "This will let the member access the Hub after signing in again."
                                    : "This will remove Hub access after signing in again."
                            )
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .club360Glass(cornerRadius: 22)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Member app access")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Club360Theme.cardTitle)
                        Text("Enable or disable tiles in the member app.")
                            .font(.footnote)
                            .foregroundStyle(Club360Theme.captionOnGlass)

                        Toggle("Workouts", isOn: $accessWorkouts)
                            .tint(Club360Theme.burgundy)
                            .disabled(accessBusy)
                        Toggle("Meals / nutrition", isOn: $accessNutrition)
                            .tint(Club360Theme.burgundy)
                            .disabled(accessBusy)
                        Toggle("Schedule", isOn: $accessEvents)
                            .tint(Club360Theme.burgundy)
                            .disabled(accessBusy)
                        Toggle("Payments", isOn: $accessPayments)
                            .tint(Club360Theme.burgundy)
                            .disabled(accessBusy)

                        if let accessSuccess {
                            Text(accessSuccess)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Club360Theme.burgundy)
                        }
                        if let accessError {
                            Text(accessError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Button {
                            Task { await applyMemberAccess() }
                        } label: {
                            Text(accessBusy ? "Saving…" : "Apply access")
                        }
                        .buttonStyle(Club360PrimaryGradientButtonStyle())
                        .disabled(accessBusy)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .club360Glass(cornerRadius: 22)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transfer to another coach")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Club360Theme.cardTitle)
                        Text(
                            "Paste another coach’s user ID, or open the directory below. You must be this member’s current coach. After transfer, you will no longer see them in your list."
                        )
                        .font(.footnote)
                        .foregroundStyle(Club360Theme.captionOnGlass)
                        .fixedSize(horizontal: false, vertical: true)
                        Button {
                            showCoachDirectorySheet = true
                        } label: {
                            HStack {
                                Image(systemName: "person.2.fill")
                                Text("Browse coaches & copy IDs")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Club360Theme.burgundy)
                        TextField("Target coach user UUID", text: $transferTargetCoachId)
                            .textContentType(.none)
                            .autocorrectionDisabled()
                            .foregroundStyle(Club360Theme.cardTitle)
                        if let transferError {
                            Text(transferError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                        Button {
                            showTransferConfirm = true
                        } label: {
                            Text(transferBusy ? "Transferring…" : "Transfer client")
                        }
                        .buttonStyle(Club360PrimaryGradientButtonStyle())
                        .disabled(
                            transferBusy
                                || transferTargetCoachId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                        .confirmationDialog(
                            "Transfer this member to another coach?",
                            isPresented: $showTransferConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("Transfer", role: .destructive) {
                                Task { await runTransferClient() }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("You will lose access to this client’s hub after transfer.")
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .club360Glass(cornerRadius: 22)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
        }
        .navigationTitle("Member settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .onAppear {
            syncAccessTogglesFromHomeModel()
        }
        .sheet(isPresented: $showCoachDirectorySheet) {
            NavigationStack {
                CoachDirectoryView(
                    currentUserId: auth.session?.user.id.uuidString,
                    onSelectForTransfer: { id in
                        transferTargetCoachId = id
                        showCoachDirectorySheet = false
                    }
                )
            }
        }
        .alert("Transfer complete", isPresented: $showTransferSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text(
                "This member is now assigned to the other coach. They will no longer appear in your client list."
            )
        }
    }

    private func applyMemberRole(_ role: String) async {
        guard let uid = homeModel.memberAuthUserId else { return }
        roleBusy = true
        roleError = nil
        roleSuccess = nil
        defer { roleBusy = false }
        do {
            try await AdminRoleService.setUserRole(targetAuthUserId: uid, role: role)
            roleSuccess =
                role == "admin"
                ? "Coach access updated. They will see the Hub after signing in again."
                : "Member access set. They will see the client app after signing in again."
        } catch {
            roleError = error.localizedDescription
        }
    }

    private func runTransferClient() async {
        transferBusy = true
        transferError = nil
        defer { transferBusy = false }
        do {
            try await ClientTransferService.transferClient(
                clientId: clientId,
                targetCoachUserId: transferTargetCoachId
            )
            showTransferSuccess = true
        } catch {
            transferError = error.localizedDescription
        }
    }

    private func syncAccessTogglesFromHomeModel() {
        accessWorkouts = homeModel.canViewWorkouts
        accessNutrition = homeModel.canViewNutrition
        accessEvents = homeModel.canViewEvents
        accessPayments = homeModel.canViewPayments
    }

    private func applyMemberAccess() async {
        accessBusy = true
        accessError = nil
        accessSuccess = nil
        defer { accessBusy = false }
        do {
            try await ClientDataService.updateClientAccessFlags(
                clientId: clientId,
                canViewWorkouts: accessWorkouts,
                canViewNutrition: accessNutrition,
                canViewEvents: accessEvents,
                canViewPayments: accessPayments
            )
            accessSuccess = "Member app access updated."
            await homeModel.loadForClient(clientId: clientId)
            syncAccessTogglesFromHomeModel()
        } catch {
            accessError = error.localizedDescription
        }
    }

    private var adminNextSessionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Next session")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Club360Theme.captionOnTintedCard)
                    .textCase(.uppercase)
                Spacer()
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(Club360Theme.burgundy)
            }
            Text(homeModel.nextSessionLine ?? "No upcoming sessions scheduled.")
                .font(.body.weight(.semibold))
                .foregroundStyle(Club360Theme.cardTitle)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(homeModel.upcomingSessionCount) upcoming")
                .font(.caption.weight(.medium))
                .foregroundStyle(Club360Theme.captionOnTintedCard)
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
