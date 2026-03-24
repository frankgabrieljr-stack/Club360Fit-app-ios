import Observation
import SwiftUI

/// Daily habits — log per day; browse full history via date picker + list (`daily_habit_logs`).
struct MyDailyHabitsView: View {
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var habitHistory: [DailyHabitLogDTO] = []
    @State private var waterDone = false
    @State private var stepsText = ""
    @State private var sleepText = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var toast: String?

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// Past-only range: from `clients.created_at` (member since) through today; fallback if missing.
    private var selectableRange: ClosedRange<Date> {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let fallbackOldest = cal.date(byAdding: .year, value: -50, to: Date()) ?? Date.distantPast
        let rawStart = home.memberSinceStartOfDay ?? cal.startOfDay(for: fallbackOldest)
        let start = min(rawStart, end)
        return start ... end
    }

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
            await loadHistory()
            await loadSelectedDay()
        }
        .onChange(of: selectedDate) { _, _ in
            Task { await loadSelectedDay() }
        }
        .onChange(of: home.memberSinceStartOfDay) { _, new in
            guard let new else { return }
            let cal = Calendar.current
            let end = cal.startOfDay(for: Date())
            if selectedDate < new {
                selectedDate = new
            } else if selectedDate > end {
                selectedDate = end
            }
        }
    }

    private var formContent: some View {
        ZStack {
            Club360ScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if isLoading && habitHistory.isEmpty {
                        ProgressView("Loading…")
                            .tint(Club360Theme.tealDark)
                            .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Choose a day")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Club360Theme.cardSubtitle)
                            .textCase(.uppercase)

                        DatePicker(
                            "Day",
                            selection: $selectedDate,
                            in: selectableRange,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.compact)
                        .tint(Club360Theme.tealDark)
                        .labelsHidden()

                        if let since = home.memberSinceStartOfDay {
                            Text("Earliest day matches your profile start (\(Club360DateFormats.displayDay(fromPostgresDay: Club360DateFormats.dayString(since)))).")
                                .font(.caption2)
                                .foregroundStyle(Club360Theme.cardSubtitle)
                        }

                        Button {
                            selectedDate = Calendar.current.startOfDay(for: Date())
                        } label: {
                            Text("Jump to today")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .tint(Club360Theme.tealDark)

                        Text(Club360DateFormats.displayDay(fromPostgresDay: Club360DateFormats.dayString(selectedDate)))
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
                            Text(isSaving ? "Saving…" : (isToday ? "Save today" : "Save this day"))
                        }
                        .buttonStyle(Club360PrimaryGradientButtonStyle())
                        .disabled(isSaving || home.clientId == nil)
                        .opacity(isSaving ? 0.75 : 1)
                    }
                    .padding(18)
                    .club360Glass(cornerRadius: 28)

                    if !habitHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your log history")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Club360Theme.cardTitle)

                            Text("Tap a day to edit it. Newest first.")
                                .font(.caption)
                                .foregroundStyle(Club360Theme.cardSubtitle)

                            ForEach(habitHistory) { row in
                                Button {
                                    selectHistoryRow(row)
                                } label: {
                                    habitHistoryRow(row)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .club360Glass(cornerRadius: 28)
                    }
                }
                .padding()
            }
        }
    }

    private func habitHistoryRow(_ row: DailyHabitLogDTO) -> some View {
        let dayLabel = Club360DateFormats.displayDay(fromPostgresDay: row.logDate)
        let selected = Club360DateFormats.dayString(selectedDate) == row.logDate
        let steps = row.steps.map { "\($0) steps" } ?? "— steps"
        let sleep = row.sleepHours.map { String(format: "%.1f h sleep", $0) } ?? "— sleep"
        let water = row.waterDone ? "Water ✓" : "Water —"

        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? Club360Theme.burgundy : Club360Theme.cardTitle)
                Text("\(water) · \(steps) · \(sleep)")
                    .font(.caption)
                    .foregroundStyle(Club360Theme.cardSubtitle)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Club360Theme.cardSubtitle.opacity(0.7))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selected ? Club360Theme.mint.opacity(0.35) : Color.clear)
        )
    }

    private func selectHistoryRow(_ row: DailyHabitLogDTO) {
        guard let d = Club360DateFormats.postgresDay.date(from: row.logDate) else { return }
        selectedDate = Calendar.current.startOfDay(for: d)
        waterDone = row.waterDone
        stepsText = row.steps.map(String.init) ?? ""
        sleepText = row.sleepHours.map { String($0) } ?? ""
        toast = nil
        errorMessage = nil
    }

    private func loadHistory() async {
        guard let cid = home.clientId else { return }
        do {
            habitHistory = try await ClientDataService.fetchDailyHabitLogs(clientId: cid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSelectedDay() async {
        guard let cid = home.clientId else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let day = Club360DateFormats.dayString(selectedDate)
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
        let sleepVal = sleepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : Double(sleepText.trimmingCharacters(in: .whitespacesAndNewlines))

        isSaving = true
        errorMessage = nil
        toast = nil
        defer { isSaving = false }
        do {
            try await ClientDataService.upsertDailyHabit(
                clientId: cid,
                date: selectedDate,
                waterDone: waterDone,
                steps: steps,
                sleepHours: sleepVal
            )
            toast = "Saved."
            await loadHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
