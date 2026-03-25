import SwiftUI

/// Coach-only editor for what the member sees on **Payments** (`client_payment_settings`).
struct CoachPaymentSettingsView: View {
    let clientId: String
    let clientDisplayName: String

    @State private var venmoUrl = ""
    @State private var zelleEmail = ""
    @State private var zellePhone = ""
    @State private var note = ""
    @State private var hasUpcomingDue = false
    @State private var nextDueDay = Date()
    @State private var nextDueAmount = ""
    @State private var nextDueNote = ""

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var toast: String?

    var body: some View {
        Group {
            if clientId.isEmpty {
                ContentUnavailableView("No client", systemImage: "person.crop.circle.badge.xmark")
            } else {
                formContent
            }
        }
        .navigationTitle("Payment setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task(id: clientId) {
            await load()
        }
    }

    private var formContent: some View {
        ZStack {
            Club360ScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("This is what \(clientDisplayName) sees on their Payments screen when payment access is enabled.")
                        .font(.footnote)
                        .foregroundStyle(Club360Theme.cardSubtitle)
                        .fixedSize(horizontal: false, vertical: true)

                    if isLoading {
                        ProgressView("Loading…")
                            .tint(Club360Theme.burgundy)
                            .frame(maxWidth: .infinity)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .club360Glass(cornerRadius: 22)
                    }

                    if let toast {
                        Text(toast)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Club360Theme.burgundy)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        sectionLabel("Pay links")
                        TextField("Venmo profile URL (https://…)", text: $venmoUrl)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Zelle email (optional)", text: $zelleEmail)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        TextField("Zelle phone (optional)", text: $zellePhone)
                            .textContentType(.telephoneNumber)

                        sectionLabel("Note on Payments screen")
                        TextField("Short note (e.g. pay before session)", text: $note, axis: .vertical)
                            .lineLimit(2 ... 5)

                        sectionLabel("Upcoming due (card on their Payments)")
                        Toggle("Show upcoming due block", isOn: $hasUpcomingDue)
                            .tint(Club360Theme.burgundy)
                        if hasUpcomingDue {
                            DatePicker("Due date", selection: $nextDueDay, displayedComponents: [.date])
                            TextField("Amount (e.g. $25)", text: $nextDueAmount)
                            TextField("Fine print under amount (optional)", text: $nextDueNote, axis: .vertical)
                                .lineLimit(2 ... 4)
                        }

                        Button {
                            Task { await save() }
                        } label: {
                            Text(isSaving ? "Saving…" : "Save")
                        }
                        .buttonStyle(Club360PrimaryGradientButtonStyle())
                        .disabled(isSaving || isLoading)
                    }
                    .padding(18)
                    .club360Glass(cornerRadius: 28)
                }
                .padding()
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(Club360Theme.cardSubtitle)
            .textCase(.uppercase)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let s = try await ClientDataService.fetchPaymentSettings(clientId: clientId) else {
                venmoUrl = ""
                zelleEmail = ""
                zellePhone = ""
                note = ""
                hasUpcomingDue = false
                nextDueAmount = ""
                nextDueNote = ""
                return
            }
            venmoUrl = s.venmoUrl ?? ""
            zelleEmail = s.zelleEmail ?? ""
            zellePhone = s.zellePhone ?? ""
            note = s.note ?? ""
            nextDueAmount = s.nextDueAmount ?? ""
            nextDueNote = s.nextDueNote ?? ""
            if let d = s.nextDueDate, let date = Club360DateFormats.postgresDay.date(from: d) {
                hasUpcomingDue = true
                nextDueDay = Calendar.current.startOfDay(for: date)
            } else {
                hasUpcomingDue = false
                nextDueDay = Date()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        toast = nil
        defer { isSaving = false }
        let v = venmoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let ze = zelleEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let zp = zellePhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let amt = nextDueAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        let dueNote = nextDueNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let dueStr: String? = hasUpcomingDue
            ? Club360DateFormats.dayString(Calendar.current.startOfDay(for: nextDueDay))
            : nil
        do {
            try await ClientDataService.upsertPaymentSettings(
                clientId: clientId,
                venmoUrl: v.isEmpty ? nil : v,
                zelleEmail: ze.isEmpty ? nil : ze,
                zellePhone: zp.isEmpty ? nil : zp,
                note: n,
                nextDueDate: dueStr,
                nextDueAmount: hasUpcomingDue ? (amt.isEmpty ? nil : amt) : nil,
                nextDueNote: hasUpcomingDue ? (dueNote.isEmpty ? nil : dueNote) : nil
            )
            toast = "Saved. Member may need to pull to refresh."
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                if toast == "Saved. Member may need to pull to refresh." { toast = nil }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
