import Observation
import SwiftUI

/// Coach-wide feed of meal photos across all visible clients (newest first), with feedback + link into client hub.
struct CoachMealPhotoInboxView: View {
    @State private var model = CoachMealPhotoInboxViewModel()

    var body: some View {
        ZStack {
            Club360ScreenBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    inboxHeader

                    if model.isLoading {
                        ProgressView("Loading meal inbox…")
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

                    if !model.isLoading, model.errorMessage == nil, model.groups.isEmpty {
                        ContentUnavailableView(
                            "No meal photos yet",
                            systemImage: "camera",
                            description: Text("When clients log meals, they appear here in one place.")
                        )
                        .padding(.top, 24)
                    }

                    ForEach(model.groups) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                Image(systemName: "person.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Club360Theme.burgundy)
                                Text(group.displayName)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Club360Theme.burgundy)
                                Spacer(minLength: 0)
                                NavigationLink {
                                    AdminClientHubView(clientId: group.clientId, displayTitle: group.displayName)
                                } label: {
                                    Text("Client hub")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.plain)
                                .tint(Club360Theme.tealDark)
                            }

                            ForEach(group.logs, id: \.rowIdentity) { log in
                                MealPhotoLogCard(
                                    log: log,
                                    clientId: log.clientId,
                                    clientNameHeader: nil,
                                    isCoachReviewing: true,
                                    onDataChanged: {
                                        Task { await model.load() }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Meal inbox")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task {
            await model.load()
        }
        .refreshable {
            await model.load()
        }
    }

    private var inboxHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Image("LogoBurgundy")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("All clients")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Club360Theme.burgundy)
                Text("Grouped by member — newest uploads first. Save feedback on each card.")
                    .font(.caption)
                    .foregroundStyle(Club360Theme.cardSubtitle)
            }
        }
        .padding(.bottom, 4)
    }
}

private struct InboxClientGroup: Identifiable {
    let clientId: String
    let displayName: String
    let logs: [MealPhotoLogDTO]

    var id: String { clientId }
}

@Observable
@MainActor
private final class CoachMealPhotoInboxViewModel {
    var isLoading = true
    var errorMessage: String?
    var groups: [InboxClientGroup] = []

    func displayName(forClientId id: String, titleByClientId: [String: String]) -> String {
        if let t = titleByClientId[id], !t.isEmpty { return t }
        return "Client \(id.prefix(8))…"
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let logsTask = ClientDataService.listMealPhotoLogsForCoachInbox()
            async let clientsTask = ClientDataService.fetchClientsForCoach()
            let (logs, clients) = try await (logsTask, clientsTask)
            let titleByClientId = Dictionary(uniqueKeysWithValues: clients.compactMap { c -> (String, String)? in
                guard let id = c.id, !id.isEmpty else { return nil }
                return (id, AdminViewModel.listTitle(for: c))
            })

            var order: [String] = []
            var seen = Set<String>()
            for log in logs {
                if !seen.contains(log.clientId) {
                    seen.insert(log.clientId)
                    order.append(log.clientId)
                }
            }
            let byClient = Dictionary(grouping: logs) { $0.clientId }
            groups = order.map { cid in
                let name = displayName(forClientId: cid, titleByClientId: titleByClientId)
                let clientLogs = (byClient[cid] ?? []).sorted { a, b in
                    if a.logDate != b.logDate { return a.logDate > b.logDate }
                    return (a.createdAt ?? "") > (b.createdAt ?? "")
                }
                return InboxClientGroup(clientId: cid, displayName: name, logs: clientLogs)
            }
        } catch {
            errorMessage = error.localizedDescription
            groups = []
        }
    }
}
