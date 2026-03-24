import Observation
import SwiftUI

/// Mirrors Android `MyScheduleScreen`.
struct MyScheduleView: View {
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel
    @State private var model = MyScheduleViewModel()

    var body: some View {
        Group {
            if home.clientId == nil {
                ContentUnavailableView("No profile", systemImage: "person.crop.circle.badge.xmark")
            } else if !home.canViewEvents {
                ContentUnavailableView(
                    "Schedule unavailable",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Your coach has disabled club events for your account.")
                )
            } else {
                scheduleBody
            }
        }
        .navigationTitle("Schedule")
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

    private var scheduleBody: some View {
        ZStack {
            Club360ScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if model.isLoading {
                        ProgressView("Loading schedule…")
                            .tint(Club360Theme.tealDark)
                            .frame(maxWidth: .infinity)
                    }
                    if let err = model.errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .club360Glass(cornerRadius: 22)
                    }
                    if model.upcoming.isEmpty, model.past.isEmpty, !model.isLoading {
                        Text("No sessions scheduled yet.")
                            .foregroundStyle(.secondary)
                    }
                    if !model.upcoming.isEmpty {
                        Text("Upcoming")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Club360Theme.cardTitle)
                        ForEach(model.upcoming, id: \.id) { s in
                            sessionBlock(s, small: false)
                        }
                    }
                    if !model.past.isEmpty {
                        Text("Past")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Club360Theme.cardTitle)
                        ForEach(Array(model.past.suffix(20)), id: \.id) { s in
                            sessionBlock(s, small: true)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func sessionBlock(_ s: ScheduleEventDTO, small: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(Club360DateFormats.displayDay(fromPostgresDay: s.date)) at \(s.time) – \(s.title)")
                .font(small ? .caption.weight(.medium) : .body.weight(.medium))
                .foregroundStyle(small ? Club360Theme.cardSubtitle : Club360Theme.cardTitle)
            let n = (s.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !n.isEmpty {
                Text(n)
                    .font(.caption)
                    .foregroundStyle(Club360Theme.cardSubtitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .club360Glass(cornerRadius: 28)
    }
}

@Observable
@MainActor
private final class MyScheduleViewModel {
    var isLoading = true
    var errorMessage: String?
    var upcoming: [ScheduleEventDTO] = []
    var past: [ScheduleEventDTO] = []

    func load(clientId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let events = try await ClientDataService.fetchScheduleEvents(clientId: clientId)
            let cal = Calendar.current
            let todayStart = cal.startOfDay(for: Date())
            upcoming = events
                .filter { e in
                    guard !e.isCompleted, let d = Club360DateFormats.postgresDay.date(from: e.date) else { return false }
                    return cal.startOfDay(for: d) >= todayStart
                }
                .sorted {
                    let d0 = Club360DateFormats.postgresDay.date(from: $0.date) ?? .distantFuture
                    let d1 = Club360DateFormats.postgresDay.date(from: $1.date) ?? .distantFuture
                    if d0 != d1 { return d0 < d1 }
                    return $0.time < $1.time
                }
            past = events
                .filter { e in
                    guard let d = Club360DateFormats.postgresDay.date(from: e.date) else { return false }
                    return cal.startOfDay(for: d) < todayStart
                }
                .sorted {
                    let d0 = Club360DateFormats.postgresDay.date(from: $0.date) ?? .distantPast
                    let d1 = Club360DateFormats.postgresDay.date(from: $1.date) ?? .distantPast
                    if d0 != d1 { return d0 < d1 }
                    return $0.time < $1.time
                }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
