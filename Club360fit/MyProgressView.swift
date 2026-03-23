import Observation
import SwiftUI

/// Client progress check-ins — mirrors Android `MyProgressScreen`.
struct MyProgressView: View {
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel
    @State private var model = MyProgressViewModel()
    @State private var showLogSheet = false

    var body: some View {
        Group {
            if home.clientId == nil {
                ContentUnavailableView(
                    "No profile",
                    systemImage: "person.crop.circle.badge.xmark",
                    description: Text("We couldn’t load your client profile.")
                )
            } else {
                progressContent
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
        .task(id: home.clientId) {
            guard let cid = home.clientId else { return }
            await model.load(clientId: cid)
        }
        .refreshable {
            guard let cid = home.clientId else { return }
            await model.load(clientId: cid)
        }
        .sheet(isPresented: $showLogSheet) {
            if let cid = home.clientId {
                LogProgressSheet(clientId: cid) {
                    Task { await model.load(clientId: cid) }
                }
            }
        }
    }

    @ViewBuilder
    private var progressContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.isLoading {
                    ProgressView("Loading check-ins…")
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let err = model.errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if model.checkIns.isEmpty, !model.isLoading {
                    Text("No check-ins yet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.checkIns, id: \.rowIdentity) { checkIn in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Club360DateFormats.displayDay(fromPostgresDay: checkIn.checkInDate))
                                .font(.headline)
                                .foregroundStyle(Club360Theme.burgundy)

                            HStack(spacing: 10) {
                                if let lbs = Club360Units.displayPoundsFromKg(checkIn.weightKg) {
                                    Text(lbs)
                                        .font(.caption)
                                }
                                if checkIn.workoutDone {
                                    Text("Workout ✓")
                                        .font(.caption)
                                }
                                if checkIn.mealsFollowed {
                                    Text("Meals ✓")
                                        .font(.caption)
                                }
                            }
                            .foregroundStyle(.primary)

                            let noteText = (checkIn.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            if !noteText.isEmpty {
                                Text(noteText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)
                    }
                }

                Button {
                    showLogSheet = true
                } label: {
                    Text("Log progress")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Club360Theme.burgundy)
            }
            .padding()
        }
    }
}

@Observable
@MainActor
private final class MyProgressViewModel {
    var isLoading = true
    var errorMessage: String?
    var checkIns: [ProgressCheckInDTO] = []

    func load(clientId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            checkIns = try await ClientDataService.fetchProgressCheckIns(clientId: clientId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Log progress sheet (Android `ClientLogProgressDialog`)

private struct LogProgressSheet: View {
    let clientId: String
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var dateText = Club360DateFormats.dayString(Date())
    @State private var weightText = ""
    @State private var notes = ""
    @State private var workoutDone = false
    @State private var mealsFollowed = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Date (YYYY-MM-DD)", text: $dateText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Weight (kg, optional)", text: $weightText)
                        .keyboardType(.decimalPad)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
                Section {
                    Toggle("Workout completed?", isOn: $workoutDone)
                        .tint(Club360Theme.burgundy)
                    Toggle("Meals followed?", isOn: $mealsFollowed)
                        .tint(Club360Theme.burgundy)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Log progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .foregroundStyle(Club360Theme.burgundy)
                    }
                }
            }
        }
    }

    private func save() async {
        guard let day = Club360DateFormats.postgresDay.date(from: dateText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Enter a valid date."
            return
        }
        let wTrim = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        let weightKg: Double? = wTrim.isEmpty ? nil : Double(wTrim)
        if !wTrim.isEmpty, weightKg == nil {
            errorMessage = "Enter a valid weight in kg."
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let row = ProgressCheckInInsert(
            clientId: clientId,
            checkInDate: Club360DateFormats.dayString(day),
            weightKg: weightKg,
            notes: notes,
            workoutDone: workoutDone,
            mealsFollowed: mealsFollowed
        )
        do {
            try await ClientDataService.addProgressCheckIn(row)
            dismiss()
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
