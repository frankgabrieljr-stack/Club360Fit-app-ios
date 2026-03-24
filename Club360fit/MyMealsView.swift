import Observation
import SwiftUI

/// Meal plans + entry to meal photos — mirrors Android `MyMealsScreen`.
struct MyMealsView: View {
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel
    @State private var model = MyMealsViewModel()

    var body: some View {
        Group {
            if !home.canViewNutrition {
                ContentUnavailableView(
                    "Meals unavailable",
                    systemImage: "lock.fill",
                    description: Text("Your coach has disabled nutrition access for your account.")
                )
            } else if home.clientId == nil {
                ContentUnavailableView(
                    "No profile",
                    systemImage: "person.crop.circle.badge.xmark",
                    description: Text("We couldn’t load your client profile.")
                )
            } else {
                mealsContent
            }
        }
        .navigationTitle("Meals")
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
    private var mealsContent: some View {
        ZStack {
            Club360ScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.isLoading {
                        ProgressView("Loading meal plans…")
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

                    NavigationLink {
                        MyMealPhotosView()
                            .environment(home)
                    } label: {
                        HStack(alignment: .center, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Club360Theme.teal.opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                    )
                                    .frame(width: 52, height: 52)
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundStyle(Club360Theme.tealDark)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Meal photos")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(Club360Theme.cardTitle)
                                Text("Log meals for your coach (camera or gallery)")
                                    .font(.caption)
                                    .foregroundStyle(Club360Theme.cardSubtitle)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Club360Theme.cardSubtitle)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .club360Glass(cornerRadius: 28)
                    }
                    .buttonStyle(.plain)

                    if model.plans.isEmpty, !model.isLoading {
                        Text("No meal plans assigned yet.")
                            .font(.body)
                            .foregroundStyle(.secondary)
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
private final class MyMealsViewModel {
    var isLoading = true
    var errorMessage: String?
    var plans: [MealPlanDTO] = []

    func load(clientId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            plans = try await ClientDataService.fetchMealPlans(clientId: clientId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
