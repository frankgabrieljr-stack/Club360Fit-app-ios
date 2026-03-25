import Observation
import SwiftUI

/// All `client_notifications` across coached members (RLS). Shown from the main Coach Hub bell.
struct CoachHubNotificationsView: View {
    let clientNameById: [String: String]
    var onUnreadChanged: () -> Void = {}

    @State private var model = CoachHubNotificationsModel()

    var body: some View {
        Group {
            if model.isLoading, model.items.isEmpty {
                ZStack {
                    Club360ScreenBackground()
                    ProgressView()
                        .tint(Club360Theme.tealDark)
                }
            } else if model.items.isEmpty {
                ZStack {
                    Club360ScreenBackground()
                    ContentUnavailableView(
                        "No updates yet",
                        systemImage: "bell",
                        description: Text("Alerts from your clients and system messages will show here.")
                    )
                }
            } else {
                listBody
            }
        }
        .navigationTitle("Updates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Mark all read") {
                    Task {
                        try? await ClientDataService.markAllNotificationsReadForCoach()
                        await model.load()
                        onUnreadChanged()
                    }
                }
                .tint(Club360Theme.tealDark)
            }
        }
        .task {
            await model.load()
        }
        .refreshable {
            await model.load()
        }
    }

    private var listBody: some View {
        ZStack {
            Club360ScreenBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(model.items) { n in
                        notificationCard(n)
                    }
                }
                .padding()
            }
        }
    }

    private func notificationCard(_ n: ClientNotificationDTO) -> some View {
        Button {
            Task {
                if let id = n.rowId {
                    try? await ClientDataService.markNotificationRead(notificationId: id)
                    await model.load()
                    onUnreadChanged()
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                if n.readAt == nil {
                    Circle()
                        .fill(Club360Theme.peachDeep)
                        .frame(width: 10, height: 10)
                        .padding(.top, 4)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(clientNameById[n.clientId] ?? "Member")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Club360Theme.tealDark)
                    Text(n.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Club360Theme.cardTitle)
                    Text(n.body)
                        .font(.body)
                        .foregroundStyle(Club360Theme.cardTitle)
                    if let created = n.createdAt {
                        Text(Club360Formatting.formatPaymentInstant(created))
                            .font(.caption)
                            .foregroundStyle(Club360Theme.cardSubtitle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .club360Glass()
        }
        .buttonStyle(.plain)
    }
}

@Observable
@MainActor
private final class CoachHubNotificationsModel {
    var isLoading = true
    var items: [ClientNotificationDTO] = []

    func load() async {
        isLoading = true
        defer { isLoading = false }
        items = (try? await ClientDataService.fetchNotificationsForCoach(limit: 80)) ?? []
    }
}
