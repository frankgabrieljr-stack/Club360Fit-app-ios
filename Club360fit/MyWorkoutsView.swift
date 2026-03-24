import Observation
import SwiftUI

/// Client workouts — mirrors Android `MyWorkoutsScreen`.
struct MyWorkoutsView: View {
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel
    @State private var model = MyWorkoutsViewModel()

    var body: some View {
        Group {
            if !home.canViewWorkouts {
                ContentUnavailableView(
                    "Workouts unavailable",
                    systemImage: "lock.fill",
                    description: Text("Your coach has disabled workout access for your account.")
                )
            } else if home.clientId == nil {
                ContentUnavailableView(
                    "No profile",
                    systemImage: "person.crop.circle.badge.xmark",
                    description: Text("We couldn’t load your client profile. Pull to refresh on Home or contact support.")
                )
            } else {
                workoutsContent
            }
        }
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task(id: home.clientId) {
            guard let cid = home.clientId else { return }
            await model.load(clientId: cid)
        }
        .refreshable {
            guard let cid = home.clientId else { return }
            await model.load(clientId: cid)
        }
    }

    @ViewBuilder
    private var workoutsContent: some View {
        ZStack {
            Club360ScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.isLoading {
                        ProgressView("Loading plans…")
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

                    let pct = model.weekExpected <= 0
                        ? 0.0
                        : min(1.0, Double(model.weekLogged) / Double(model.weekExpected))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("This week")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Club360Theme.cardTitle)
                            .textCase(.uppercase)
                            .tracking(0.6)

                        Club360SegmentedProgressBar(value: pct, segments: 4)

                        Text("\(model.weekLogged) / \(model.weekExpected) sessions · \(Int((pct * 100).rounded()))%")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Club360Theme.cardSubtitle)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .club360Glass(cornerRadius: 28)

                    Button {
                        Task {
                            guard let cid = home.clientId else { return }
                            await model.logToday(clientId: cid)
                        }
                    } label: {
                        Text(model.isLogging ? "Saving…" : "Log a workout today")
                    }
                    .buttonStyle(Club360PrimaryGradientButtonStyle())
                    .disabled(model.isLogging || home.clientId == nil)
                    .opacity(model.isLogging ? 0.7 : 1)

                    if let toast = model.toast {
                        Text(toast)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Club360Theme.cardSubtitle)
                    }

                    if model.plans.isEmpty, !model.isLoading {
                        Text("No workout plans assigned yet.")
                            .font(.body)
                            .foregroundStyle(Club360Theme.cardSubtitle)
                            .padding(.top, 8)
                    } else {
                        ForEach(model.plans, id: \.rowIdentity) { plan in
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Week of \(Club360DateFormats.displayDay(fromPostgresDay: plan.weekStart)) – \(plan.title)")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(Club360Theme.cardTitle)
                                Text(plan.planText)
                                    .font(.body)
                                    .foregroundStyle(Club360Theme.cardTitle)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .club360Glass(cornerRadius: 28)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

@Observable
@MainActor
private final class MyWorkoutsViewModel {
    var isLoading = true
    var errorMessage: String?
    var plans: [WorkoutPlanDTO] = []
    var weekLogged = 0
    var weekExpected = 4
    var isLogging = false
    var toast: String?

    private var todayWeekStart: Date {
        Calendar.weekStartSunday(containing: Date())
    }

    func load(clientId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let list = try await ClientDataService.fetchWorkoutPlans(clientId: clientId)
            plans = list
            weekLogged = try await ClientDataService.workoutSessionCountForWeek(
                clientId: clientId,
                weekStart: todayWeekStart
            )
            weekExpected = Self.clampExpected(list.first?.expectedSessions)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshWeek(clientId: String) async {
        do {
            weekLogged = try await ClientDataService.workoutSessionCountForWeek(
                clientId: clientId,
                weekStart: todayWeekStart
            )
            weekExpected = Self.clampExpected(plans.first?.expectedSessions)
        } catch {}
    }

    func logToday(clientId: String) async {
        isLogging = true
        defer { isLogging = false }
        await ClientDataService.logWorkoutSession(clientId: clientId, sessionDate: Date())
        await refreshWeek(clientId: clientId)
        toast = "Workout logged."
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                if toast == "Workout logged." { toast = nil }
            }
        }
    }

    private static func clampExpected(_ raw: Int?) -> Int {
        let e = raw ?? 4
        return max(1, min(14, e))
    }
}
