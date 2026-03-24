import Auth
import Observation
import PhotosUI
import SwiftUI
import UIKit

/// Meal photo log — **client**: upload & delete own rows; **coach/admin**: review & leave feedback (Android `MyMealPhotosScreen` vs `ClientMealPhotosScreen`).
struct MyMealPhotosView: View {
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @State private var model = MyMealPhotosViewModel()
    @State private var showAdd = false

    private var isCoachReviewing: Bool {
        auth.session?.user.isAdminRole == true
    }

    var body: some View {
        Group {
            if let cid = home.clientId {
                mealPhotosContent(clientId: cid)
            } else {
                ContentUnavailableView("No profile", systemImage: "person.crop.circle.badge.xmark")
            }
        }
        .navigationTitle(isCoachReviewing ? "Client meal photos" : "Meal photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            if !isCoachReviewing {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .tint(Club360Theme.tealDark)
                }
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
        ZStack {
            Club360ScreenBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if model.isLoading {
                        ProgressView("Loading photos…")
                            .tint(Club360Theme.tealDark)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }

                    if let err = model.errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .club360Glass(cornerRadius: 22)
                    }

                    if isCoachReviewing, !model.isLoading {
                        Text("Add quick feedback so your client knows if portions are too much, too little, or on track.")
                            .font(.subheadline)
                            .foregroundStyle(Club360Theme.cardSubtitle)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if model.logs.isEmpty, !model.isLoading {
                        Text(
                            isCoachReviewing
                                ? "No meal photos from this client yet."
                                : "No meal photos yet. Tap + to add one so your coach can review portions and adjust your plan."
                        )
                        .font(.body)
                        .foregroundStyle(.secondary)
                    }

                    ForEach(model.logs, id: \.rowIdentity) { log in
                        MealPhotoLogCard(
                            log: log,
                            clientId: clientId,
                            clientNameHeader: nil,
                            isCoachReviewing: isCoachReviewing,
                            onDataChanged: {
                                Task { await model.load(clientId: clientId) }
                            }
                        )
                    }
                }
                .padding()
            }
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

// MARK: - Add sheet (client)

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
    @State private var showCamera = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take picture", systemImage: "camera.fill")
                    }
                    .disabled(!cameraAvailable)
                    .foregroundStyle(Club360Theme.tealDark)

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                    }
                    .tint(Club360Theme.tealDark)
                    .onChange(of: selectedItem) { _, new in
                        Task { await loadPhoto(from: new) }
                    }

                    if !cameraAvailable {
                        Text("Camera isn’t available here (e.g. Simulator). Use “Choose from library” or run on a device.")
                            .font(.caption)
                            .foregroundStyle(Club360Theme.cardSubtitle)
                    }

                    if pickedData != nil {
                        Text("Image ready to upload")
                            .font(.caption)
                            .foregroundStyle(Club360Theme.cardSubtitle)
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
            .tint(Club360Theme.tealDark)
            .club360FormScreen()
            .navigationTitle("Add meal photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
                            .foregroundStyle(Club360Theme.tealDark)
                            .disabled(pickedData == nil)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraImagePicker(
                    onCapture: { data in
                        pickedData = data
                        pickedName = "camera.jpg"
                        selectedItem = nil
                    },
                    onDismiss: { showCamera = false }
                )
                .ignoresSafeArea()
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
