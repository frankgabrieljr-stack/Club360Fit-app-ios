import SwiftUI
import UIKit

/// Lists coach accounts from `public.profiles` so admins can copy Auth user UUIDs (e.g. client transfer).
struct CoachDirectoryView: View {
    /// Signed-in user id (lowercased) for a “You” label; optional.
    var currentUserId: String?
    /// When transferring a client, fills the target field and dismisses the sheet.
    var onSelectForTransfer: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var rows: [ClientDataService.CoachDirectoryProfileRow] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var copiedId: String?

    var body: some View {
        ZStack {
            Club360ScreenBackground()
            if isLoading {
                ProgressView("Loading coaches…")
                    .tint(Club360Theme.tealDark)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if rows.isEmpty {
                ContentUnavailableView(
                    "No coach profiles",
                    systemImage: "person.2",
                    description: Text("Coach accounts appear here when they have admin access in Club360Fit.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(
                            "Each coach’s User ID is their Supabase Auth UUID — use it when transferring a client to them."
                        )
                        .font(.footnote)
                        .foregroundStyle(Club360Theme.captionOnGlass)
                        .fixedSize(horizontal: false, vertical: true)

                        ForEach(rows) { row in
                            coachRow(row)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Coaches")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task {
            await load()
        }
    }

    private func coachRow(_ row: ClientDataService.CoachDirectoryProfileRow) -> some View {
        let idLower = row.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let selfLower = currentUserId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isSelf = selfLower != nil && selfLower == idLower

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(displayName(for: row))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Club360Theme.cardTitle)
                if isSelf {
                    Text("(you)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Club360Theme.tealDark)
                }
                Spacer(minLength: 0)
            }
            if let email = row.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(Club360Theme.captionOnGlass)
            }
            Text(idLower)
                .font(.caption.monospaced())
                .foregroundStyle(Club360Theme.cardTitle)
                .textSelection(.enabled)

            HStack(spacing: 10) {
                Button {
                    copyId(idLower)
                } label: {
                    Text(copiedId == idLower ? "Copied" : "Copy ID")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(Club360Theme.burgundy)

                if let onSelectForTransfer, !isSelf {
                    Button {
                        onSelectForTransfer(idLower)
                        dismiss()
                    } label: {
                        Text("Use for transfer")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Club360Theme.burgundy)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .club360Glass(cornerRadius: 20)
    }

    private func displayName(for row: ClientDataService.CoachDirectoryProfileRow) -> String {
        if let n = row.full_name?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            return n
        }
        if let email = row.email?.trimmingCharacters(in: .whitespacesAndNewlines),
           !email.isEmpty,
           let local = email.split(separator: "@").first
        {
            return String(local)
        }
        return "Coach \(row.id.prefix(8))…"
    }

    private func copyId(_ idLower: String) {
        UIPasteboard.general.string = idLower
        copiedId = idLower
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            copiedId = nil
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            rows = try await ClientDataService.fetchCoachDirectoryProfiles()
        } catch {
            rows = []
            errorMessage = error.localizedDescription
        }
    }
}
