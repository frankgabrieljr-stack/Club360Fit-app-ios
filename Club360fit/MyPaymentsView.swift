import Observation
import SwiftUI
import UIKit

/// Mirrors Android `MyPaymentsScreen` (Venmo / Zelle / confirmations / history).
struct MyPaymentsView: View {
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel
    @State private var model = MyPaymentsViewModel()
    @State private var showConfirm = false

    var body: some View {
        Group {
            if home.clientId == nil {
                ContentUnavailableView("No profile", systemImage: "person.crop.circle.badge.xmark")
            } else if !home.canViewPayments {
                ContentUnavailableView(
                    "Payments unavailable",
                    systemImage: "lock.fill",
                    description: Text("Your coach has disabled payment details for your account.")
                )
            } else {
                paymentsScroll
            }
        }
        .navigationTitle("Payments")
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
        .sheet(isPresented: $showConfirm) {
            if let s = model.settings, let cid = home.clientId {
                ConfirmPaymentSheet(
                    clientId: cid,
                    defaultAmount: s.nextDueAmount ?? "",
                    onDone: {
                        showConfirm = false
                        Task { await model.load(clientId: cid) }
                    }
                )
            }
        }
    }

    private var paymentsScroll: some View {
        ZStack {
            Club360ScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if model.isLoading {
                        ProgressView()
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

                    if model.settings == nil, !model.isLoading {
                        Text("Your coach hasn’t set up payment info yet.")
                            .foregroundStyle(.secondary)
                    }

                    if let s = model.settings {
                        upcomingDueCard(s)
                        if let note = s.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                            Text(note)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .club360Glass(cornerRadius: 22)
                        }

                        if let url = s.venmoUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
                            Text("Venmo")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Club360Theme.cardTitle)
                            if let u = URL(string: url) {
                                Link(destination: u) {
                                    Label("Open Venmo", systemImage: "arrow.up.right.square")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Club360Theme.primaryButtonGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .shadow(color: Club360Theme.purple.opacity(0.3), radius: 10, y: 5)
                                }
                            }
                            QRCodeImageView(content: url)
                                .frame(maxHeight: 220)
                                .padding(.vertical, 8)
                        }

                        if s.zelleEmail?.isEmpty == false || s.zellePhone?.isEmpty == false {
                            Text("Zelle")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Club360Theme.cardTitle)
                            if let em = s.zelleEmail?.trimmingCharacters(in: .whitespacesAndNewlines), !em.isEmpty {
                                copyRow(label: "Email", value: em)
                                QRCodeImageView(content: em)
                                    .frame(maxHeight: 220)
                                    .padding(.vertical, 8)
                            }
                            if let ph = s.zellePhone?.trimmingCharacters(in: .whitespacesAndNewlines), !ph.isEmpty {
                                copyRow(label: "Phone", value: ph)
                            }
                        }

                        Button {
                            showConfirm = true
                        } label: {
                            Text("I paid")
                        }
                        .buttonStyle(Club360PrimaryGradientButtonStyle())

                        if !model.confirmations.isEmpty {
                            Text("Your confirmations")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Club360Theme.cardTitle)
                            ForEach(model.confirmations) { c in
                                confirmationCard(c)
                            }
                        }

                        if !model.records.isEmpty {
                            Text("History")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Club360Theme.cardTitle)
                            ForEach(model.records) { r in
                                recordCard(r)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func upcomingDueCard(_ s: ClientPaymentSettingsDTO) -> some View {
        let amountNonempty = (s.nextDueAmount?.trimmingCharacters(in: .whitespacesAndNewlines))
            .map { !$0.isEmpty } ?? false
        let noteNonempty = (s.nextDueNote?.trimmingCharacters(in: .whitespacesAndNewlines))
            .map { !$0.isEmpty } ?? false
        let hasDue = s.nextDueDate != nil || amountNonempty || noteNonempty
        return Group {
            if hasDue {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Upcoming due")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Club360Theme.cardTitle)
                    if let d = s.nextDueDate {
                        Text("Due: \(Club360DateFormats.displayDay(fromPostgresDay: d))")
                    }
                    if let a = s.nextDueAmount?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty {
                        Text("Amount: \(a)")
                    }
                    if let n = s.nextDueNote?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
                        Text(n).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Club360Theme.sessionCardGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: Club360Theme.peachDeep.opacity(0.25), radius: 14, y: 8)
            }
        }
    }

    private func copyRow(label: String, value: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = value
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .tint(Club360Theme.tealDark)
        }
    }

    private func confirmationCard(_ c: PaymentConfirmationDTO) -> some View {
        let statusLabel = confirmationStatusLabel(c.status)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(c.amountLabel ?? "Payment")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Club360Theme.cardTitle)
                Spacer()
                if let t = c.submittedAt {
                    Text(Club360Formatting.formatPaymentInstant(t))
                        .font(.caption2)
                        .foregroundStyle(Club360Theme.cardSubtitle)
                }
            }
            Text("\(statusLabel) · \(c.method.capitalized)")
                .font(.caption)
                .foregroundStyle(Club360Theme.cardTitle)
            if !c.note.isEmpty {
                Text(c.note)
                    .font(.caption)
                    .foregroundStyle(Club360Theme.cardSubtitle)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .club360Glass(cornerRadius: 28)
    }

    private func confirmationStatusLabel(_ status: String) -> String {
        switch status {
        case "pending": "Pending"
        case "approved": "Verified"
        case "declined": "Declined"
        default: status
        }
    }

    private func recordCard(_ r: PaymentRecordDTO) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(r.amountLabel ?? "Payment")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Club360Theme.cardTitle)
                Spacer()
                Text(Club360Formatting.formatPaymentInstant(r.paidAt))
                    .font(.caption2)
                    .foregroundStyle(Club360Theme.cardSubtitle)
            }
            Text(r.method.capitalized)
                .font(.caption)
                .foregroundStyle(Club360Theme.cardTitle)
            if let n = r.note, !n.isEmpty {
                Text(n)
                    .font(.caption)
                    .foregroundStyle(Club360Theme.cardSubtitle)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .club360Glass(cornerRadius: 28)
    }
}

@Observable
@MainActor
private final class MyPaymentsViewModel {
    var isLoading = true
    var errorMessage: String?
    var settings: ClientPaymentSettingsDTO?
    var records: [PaymentRecordDTO] = []
    var confirmations: [PaymentConfirmationDTO] = []

    func load(clientId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            settings = try await ClientDataService.fetchPaymentSettings(clientId: clientId)
            records = try await ClientDataService.fetchPaymentRecords(clientId: clientId)
            confirmations = try await ClientDataService.fetchPaymentConfirmations(clientId: clientId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ConfirmPaymentSheet: View {
    let clientId: String
    var defaultAmount: String
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount: String
    @State private var method = "venmo"
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(clientId: String, defaultAmount: String, onDone: @escaping () -> Void) {
        self.clientId = clientId
        self.defaultAmount = defaultAmount
        self.onDone = onDone
        _amount = State(initialValue: defaultAmount)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $amount)
                    Picker("Method", selection: $method) {
                        Text("Venmo").tag("venmo")
                        Text("Zelle").tag("zelle")
                    }
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .tint(Club360Theme.tealDark)
            .club360FormScreen()
            .navigationTitle("Confirm payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                            .tint(Club360Theme.tealDark)
                    } else {
                        Button("Submit") { Task { await submit() } }
                            .foregroundStyle(Club360Theme.tealDark)
                    }
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        let amt = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await ClientDataService.submitPaymentConfirmation(
                clientId: clientId,
                amountLabel: amt.isEmpty ? nil : amt,
                note: note,
                method: method
            )
            dismiss()
            onDone()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
