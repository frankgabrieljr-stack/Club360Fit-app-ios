import Observation
import PhotosUI
import SwiftUI

/// Meal photo log list + upload — mirrors Android `MyMealPhotosScreen` (core flow).
struct MyMealPhotosView: View {
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel
    @State private var model = MyMealPhotosViewModel()
    @State private var showAdd = false

    var body: some View {
        Group {
            if let cid = home.clientId {
                mealPhotosContent(clientId: cid)
            } else {
                ContentUnavailableView("No profile", systemImage: "person.crop.circle.badge.xmark")
            }
        }
        .navigationTitle("Meal photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .tint(Club360Theme.burgundy)
            }
        }
        .sheet(isPresented: $showAdd) {
            if let cid = home.clientId {
                AddMealPhotoSheet(clientId: cid, onSaved: {
                    showAdd = false
                    Task { await model.load(clientId: cid) }
                })
            }
        }
    }

    @ViewBuilder
    private func mealPhotosContent(clientId: String) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if model.isLoading {
                    ProgressView("Loading photos…")
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let err = model.errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if model.logs.isEmpty, !model.isLoading {
                    Text("No meal photos yet. Tap + to add one.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                ForEach(model.logs, id: \.rowIdentity) { log in
                    MealPhotoRow(log: log, clientId: clientId) {
                        Task { await model.load(clientId: clientId) }
                    }
                }
            }
            .padding()
        }
        .task(id: clientId) {
            await model.load(clientId: clientId)
        }
        .refreshable {
            await model.load(clientId: clientId)
        }
    }
}

@Observable
@MainActor
private final class MyMealPhotosViewModel {
    var isLoading = true
    var errorMessage: String?
    var logs: [MealPhotoLogDTO] = []

    func load(clientId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            logs = try await ClientDataService.listMealPhotoLogs(clientId: clientId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MealPhotoRow: View {
    let log: MealPhotoLogDTO
    let clientId: String
    var onDeleted: () -> Void

    @State private var imageURL: URL?
    @State private var confirmDelete = false
    @State private var isDeleting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                            .clipShape(RoundedRectangle(cornerRadius: 10))
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

            Text(Club360DateFormats.displayDay(fromPostgresDay: log.logDate))
                .font(.headline)
                .foregroundStyle(Club360Theme.burgundy)

            let note = (log.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !note.isEmpty {
                Text(note)
                    .font(.subheadline)
            }

            if let fb = log.coachFeedback?.trimmingCharacters(in: .whitespacesAndNewlines), !fb.isEmpty {
                Text("Coach: \(fb)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: log.storagePath) {
            imageURL = try? ClientDataService.mealPhotoPublicURL(storagePath: log.storagePath)
        }
        .confirmationDialog("Delete this meal photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await deletePhoto() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func deletePhoto() async {
        guard let id = log.id else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await ClientDataService.deleteMealPhotoLog(clientId: clientId, logId: id)
            onDeleted()
        } catch {
            // Surface via parent if needed
        }
    }
}

private struct AddMealPhotoSheet: View {
    let clientId: String
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var mealDate = Date()
    @State private var notes = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var pickedData: Data?
    @State private var pickedName = "photo.jpg"
    @State private var isUploading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                    }
                    .tint(Club360Theme.burgundy)
                    .onChange(of: selectedItem) { _, new in
                        Task { await loadPhoto(from: new) }
                    }

                    if pickedData != nil {
                        Text("Image ready to upload")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Details") {
                    DatePicker("Meal date", selection: $mealDate, displayedComponents: .date)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add meal photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isUploading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isUploading {
                        ProgressView()
                    } else {
                        Button("Upload") { Task { await upload() } }
                            .foregroundStyle(Club360Theme.burgundy)
                            .disabled(pickedData == nil)
                    }
                }
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else {
            pickedData = nil
            return
        }
        if let data = try? await item.loadTransferable(type: Data.self) {
            pickedData = data
            pickedName = "photo.jpg"
        }
    }

    private func upload() async {
        guard let data = pickedData else { return }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        do {
            _ = try await ClientDataService.uploadMealPhotoAndInsert(
                clientId: clientId,
                imageData: data,
                logDate: mealDate,
                notes: notes,
                originalFilename: pickedName
            )
            dismiss()
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
