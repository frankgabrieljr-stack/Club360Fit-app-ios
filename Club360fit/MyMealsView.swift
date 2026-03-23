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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.isLoading {
                    ProgressView("Loading meal plans…")
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let err = model.errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                NavigationLink {
                    MyMealPhotosView()
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundStyle(Club360Theme.burgundy)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Meal photos")
                                .font(.headline)
                                .foregroundStyle(Club360Theme.burgundy)
                            Text("Log meals for your coach (camera or gallery)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Divider()

                if model.plans.isEmpty, !model.isLoading {
                    Text("No meal plans assigned yet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.plans, id: \.rowIdentity) { plan in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Week of \(Club360DateFormats.displayDay(fromPostgresDay: plan.weekStart)) – \(plan.title)")
                                .font(.headline)
                                .foregroundStyle(Club360Theme.burgundy)
                            Text(plan.planText)
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)
                    }
                }
            }
            .padding()
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
