import Foundation
import Observation

/// Coach dashboard: loads all clients the signed-in admin can see (same as Android `AdminHomeViewModel`).
@Observable
@MainActor
final class AdminViewModel {
    var isLoading = true
    var errorMessage: String?
    var clients: [ClientDTO] = []

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            clients = try await ClientDataService.fetchClientsForCoach()
        } catch {
            errorMessage = error.localizedDescription
            clients = []
        }
    }

    /// Stable list label for a row.
    static func listTitle(for client: ClientDTO) -> String {
        if let name = client.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let id = client.id {
            return "Client \(id.prefix(8))…"
        }
        return "Client"
    }
}
