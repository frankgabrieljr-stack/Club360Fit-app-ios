import Observation
import SwiftUI

/// Mirrors Android `MyNotificationsScreen`.
struct MyNotificationsView: View {
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel
    @Environment(\.clientTabRouter) private var tabRouter
    @Environment(\.dismiss) private var dismiss
    @State private var model = MyNotificationsViewModel()

    var body: some View {
        Group {
            if home.clientId == nil {
                ContentUnavailableView("No profile", systemImage: "person.crop.circle.badge.xmark")
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
                        guard let cid = home.clientId else { return }
                        await model.markAllRead(clientId: cid)
                        await home.reloadNotificationsCount()
                    }
                }
                .tint(Club360Theme.tealDark)
            }
        }
        .task(id: home.clientId) {
            guard let cid = home.clientId else { return }
            await model.load(clientId: cid)
        }
        .refreshable {
            guard let cid = home.clientId else { return }
            await model.load(clientId: cid)
        }
    }

    private var listBody: some View {
        ZStack {
            Club360ScreenBackground()

            Group {
                if model.isLoading {
                    ProgressView()
                        .tint(Club360Theme.tealDark)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.items.isEmpty {
                    Text("No updates yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
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
        }
    }

    private func notificationCard(_ n: ClientNotificationDTO) -> some View {
        Button {
            Task {
                tabRouter?.openNotification(n)
                if let id = n.rowId, let cid = home.clientId {
                    await model.markOneRead(notificationId: id, clientId: cid)
                }
                await home.reloadNotificationsCount()
                dismiss()
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
private final class MyNotificationsViewModel {
    var isLoading = true
    var items: [ClientNotificationDTO] = []

    func load(clientId: String) async {
        isLoading = true
        defer { isLoading = false }
        items = (try? await ClientDataService.fetchClientNotifications(clientId: clientId)) ?? []
    }

    func markOneRead(notificationId: String, clientId: String) async {
        try? await ClientDataService.markNotificationRead(notificationId: notificationId)
        await load(clientId: clientId)
    }

    func markAllRead(clientId: String) async {
        try? await ClientDataService.markAllNotificationsRead(clientId: clientId)
        await load(clientId: clientId)
    }
}
