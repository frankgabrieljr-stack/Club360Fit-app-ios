import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Shared meal photo card — **client** (read coach reply + delete) or **coach** (feedback editor). Optional `clientNameHeader` for multi-client inbox.
struct MealPhotoLogCard: View {
    let log: MealPhotoLogDTO
    let clientId: String
    /// When set (coach inbox), shows member name above the image.
    var clientNameHeader: String?
    let isCoachReviewing: Bool
    var onDataChanged: () -> Void

    @State private var imageURL: URL?
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var feedbackDraft = ""
    @State private var isSavingFeedback = false
    @State private var feedbackError: String?
    @State private var showSavedConfirmation = false
    @State private var hideSavedBannerTask: Task<Void, Never>?
    /// After a successful save, shows what was sent while the text field is cleared.
    @State private var savedForClientDisplay: String?
    @State private var skipNextCoachFeedbackSync = false

    private static let coachPresets: [(label: String, text: String)] = [
        ("Too much", "Too much — consider trimming portion or lighter swaps next meal."),
        ("Too little", "Too little — add lean protein or another serving from the plan."),
        ("Good balance", "Good balance — keep this up."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let name = clientNameHeader?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Club360Theme.burgundy)
                    Text(name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Club360Theme.burgundy)
                    Spacer(minLength: 0)
                }
            }

            mealImageBlock

            Text(Club360DateFormats.displayDay(fromPostgresDay: log.logDate))
                .font(.headline.weight(.semibold))
                .foregroundStyle(isCoachReviewing ? Club360Theme.burgundy : Club360Theme.cardTitle)

            let note = (log.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !note.isEmpty {
                if isCoachReviewing {
                    Text("Client: \(note)")
                        .font(.subheadline)
                        .foregroundStyle(Club360Theme.cardTitle)
                } else {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(Club360Theme.cardTitle)
                }
            }

            if isCoachReviewing {
                coachFeedbackSection
            } else {
                clientCoachFeedbackReadOnly
                clientDeleteSection
            }
        }
        .padding(16)
        .club360Glass(cornerRadius: 28)
        .task(id: log.storagePath) {
            imageURL = try? ClientDataService.mealPhotoPublicURL(storagePath: log.storagePath)
        }
        .task(id: log.rowIdentity) {
            feedbackDraft = log.coachFeedback ?? ""
            savedForClientDisplay = nil
            skipNextCoachFeedbackSync = false
        }
        .onChange(of: log.coachFeedback ?? "") { _, new in
            if skipNextCoachFeedbackSync {
                skipNextCoachFeedbackSync = false
                return
            }
            feedbackDraft = new
        }
        .onChange(of: feedbackDraft) { _, new in
            if savedForClientDisplay != nil, !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                savedForClientDisplay = nil
            }
        }
        .confirmationDialog("Delete this meal photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await deletePhoto() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var mealImageBlock: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 160)
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                case .failure:
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private var clientCoachFeedbackReadOnly: some View {
        if let fb = log.coachFeedback?.trimmingCharacters(in: .whitespacesAndNewlines), !fb.isEmpty {
            Text("Coach: \(fb)")
                .font(.subheadline)
                .foregroundStyle(Club360Theme.tealDark)
            if let iso = log.coachFeedbackUpdatedAt {
                Text(formatCoachFeedbackTime(iso))
                    .font(.caption)
                    .foregroundStyle(Club360Theme.cardSubtitle)
            }
        }
    }

    private var coachFeedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Coach feedback")
                .font(.caption.weight(.bold))
                .foregroundStyle(Club360Theme.burgundy)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.coachPresets, id: \.label) { preset in
                        Button {
                            savedForClientDisplay = nil
                            feedbackDraft = preset.text
                        } label: {
                            Text(preset.label)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Club360Theme.mint.opacity(0.55))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Club360Theme.cardTitle)
                    }
                }
            }

            if let saved = savedForClientDisplay?.trimmingCharacters(in: .whitespacesAndNewlines), !saved.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Club360Theme.mintDeep)
                        Text("Saved for client")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Club360Theme.mintDeep)
                    }
                    Text(saved)
                        .font(.subheadline)
                        .foregroundStyle(Club360Theme.cardTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    if let iso = log.coachFeedbackUpdatedAt {
                        Text(formatCoachFeedbackTime(iso))
                            .font(.caption)
                            .foregroundStyle(Club360Theme.cardSubtitle)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Club360Theme.mint.opacity(0.42))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Club360Theme.mintDeep.opacity(0.35), lineWidth: 1)
                )
            }

            TextField(
                "",
                text: $feedbackDraft,
                prompt: Text(savedForClientDisplay == nil ? "Feedback for your client" : "Add another note (optional)"),
                axis: .vertical
            )
            .lineLimit(3...6)
            .textInputAutocapitalization(.sentences)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
            .disabled(log.id == nil || isSavingFeedback)

            if savedForClientDisplay == nil, let iso = log.coachFeedbackUpdatedAt {
                Text(formatCoachFeedbackTime(iso))
                    .font(.caption)
                    .foregroundStyle(Club360Theme.cardSubtitle)
            }

            if let feedbackError {
                Text(feedbackError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await saveFeedback() }
            } label: {
                HStack {
                    if isSavingFeedback {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isSavingFeedback ? "Saving…" : (showSavedConfirmation ? "Saved ✓" : "Save feedback"))
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background {
                    Group {
                        if showSavedConfirmation {
                            LinearGradient(
                                colors: [Club360Theme.mintDeep, Club360Theme.tealDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Club360Theme.primaryButtonGradient
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .buttonStyle(.plain)
            .disabled(log.id == nil || isSavingFeedback)
            .opacity(log.id == nil ? 0.45 : 1)
        }
    }

    @ViewBuilder
    private var clientDeleteSection: some View {
        if log.id != nil {
            HStack {
                Spacer()
                Button("Delete", role: .destructive) {
                    confirmDelete = true
                }
                .font(.caption)
                .disabled(isDeleting)
            }
        }
    }

    private func deletePhoto() async {
        guard let id = log.id else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await ClientDataService.deleteMealPhotoLog(clientId: clientId, logId: id)
            onDataChanged()
        } catch {
            // Surface via parent if needed
        }
    }

    private func saveFeedback() async {
        guard let logId = log.id else { return }
        isSavingFeedback = true
        feedbackError = nil
        defer { isSavingFeedback = false }
        let trimmed = feedbackDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await ClientDataService.updateMealPhotoCoachFeedback(
                clientId: clientId,
                logId: logId,
                feedback: feedbackDraft
            )
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            hideSavedBannerTask?.cancel()
            showSavedConfirmation = true
            hideSavedBannerTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_800_000_000)
                showSavedConfirmation = false
            }
            skipNextCoachFeedbackSync = true
            if trimmed.isEmpty {
                savedForClientDisplay = nil
            } else {
                savedForClientDisplay = trimmed
            }
            feedbackDraft = ""
            onDataChanged()
        } catch {
            feedbackError = error.localizedDescription
        }
    }

    private func formatCoachFeedbackTime(_ iso: String) -> String {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFmt.date(from: iso) {
            return formatDisplay(d)
        }
        isoFmt.formatOptions = [.withInternetDateTime]
        if let d = isoFmt.date(from: iso) {
            return formatDisplay(d)
        }
        return iso
    }

    private func formatDisplay(_ d: Date) -> String {
        let out = DateFormatter()
        out.locale = .current
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: d)
    }
}
