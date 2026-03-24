import Observation
import SwiftUI

/// Mirrors Android `MyDailyHabitsScreen`.
struct MyDailyHabitsView: View {
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel
    @State private var waterDone = false
    @State private var stepsText = ""
    @State private var sleepText = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var toast: String?

    var body: some View {
        Group {
            if home.clientId == nil {
                ContentUnavailableView("No profile", systemImage: "person.crop.circle.badge.xmark")
            } else {
                formContent
            }
        }
        .navigationTitle("Daily habits")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task(id: home.clientId) {
            await loadToday()
        }
    }

    private var formContent: some View {
        ZStack {
            Club360ScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if isLoading {
                        ProgressView("Loading…")
                            .tint(Club360Theme.tealDark)
                            .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text(Club360DateFormats.displayDay(fromPostgresDay: Club360DateFormats.dayString(Date())))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Club360Theme.cardTitle)
                        Text("Log once per day. Any entry counts toward your streak.")
                            .font(.caption)
                            .foregroundStyle(Club360Theme.cardSubtitle)

                        Toggle("Water goal met", isOn: $waterDone)
                            .tint(Club360Theme.tealDark)

                        TextField("Steps (optional)", text: $stepsText)
                            .keyboardType(.numberPad)

                        TextField("Sleep (hours, optional)", text: $sleepText)
                            .keyboardType(.decimalPad)

                        if let errorMessage {
                            Text(errorMessage).font(.footnote).foregroundStyle(.red)
                        }
                        if let toast {
                            Text(toast)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Club360Theme.tealDark)
                        }

                        Button {
                            Task { await save() }
                        } label: {
                            Text(isSaving ? "Saving…" : "Save today")
                        }
                        .buttonStyle(Club360PrimaryGradientButtonStyle())
                        .disabled(isSaving || home.clientId == nil)
                        .opacity(isSaving ? 0.75 : 1)
                    }
                    .padding(18)
                    .club360Glass(cornerRadius: 28)
                }
                .padding()
            }
        }
    }

    private func loadToday() async {
        guard let cid = home.clientId else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let day = Club360DateFormats.dayString(Date())
        do {
            if let h = try await ClientDataService.fetchDailyHabitForDay(clientId: cid, logDate: day) {
                waterDone = h.waterDone
                stepsText = h.steps.map(String.init) ?? ""
                sleepText = h.sleepHours.map { String($0) } ?? ""
            } else {
                waterDone = false
                stepsText = ""
                sleepText = ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let cid = home.clientId else { return }
        let digits = stepsText.filter { $0.isNumber }
        let steps = digits.isEmpty ? nil : Int(digits)
        let sleep = Double(sleepText.trimmingCharacters(in: .whitespacesAndNewlines))
        let sleepVal = sleepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : sleep

        isSaving = true
        errorMessage = nil
        toast = nil
        defer { isSaving = false }
        do {
            try await ClientDataService.upsertDailyHabit(
                clientId: cid,
                date: Date(),
                waterDone: waterDone,
                steps: steps,
                sleepHours: sleepVal
            )
            toast = "Saved."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
