import Auth
import Observation
import PhotosUI
import SwiftUI

/// Transformation photos carousel — mirrors Android `TransformationGalleryScreen` (clients view; admins can add).
struct TransformationGalleryView: View {
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @State private var model = TransformationGalleryViewModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var currentIndex = 0

    var body: some View {
        Group {
            if model.isLoading {
                ZStack {
                    Club360ScreenBackground()
                    ProgressView()
                        .tint(Club360Theme.tealDark)
                }
            } else if model.images.isEmpty {
                ZStack {
                    Club360ScreenBackground()
                    Text("No transformations yet. Admins can add photos with +.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.black, Color(white: 0.15), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    TabView(selection: $currentIndex) {
                        ForEach(Array(model.images.enumerated()), id: \.element.id) { idx, img in
                            AsyncImage(url: img.url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView().tint(Club360Theme.tealDark)
                                case let .success(image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .padding()
                                case .failure:
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                }
            }
        }
        .navigationTitle("Gallery")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            if auth.session?.user.isAdminRole == true {
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .tint(Club360Theme.tealDark)
                }
            }
        }
        .onChange(of: pickerItem) { _, new in
            Task { await upload(from: new) }
        }
        .task {
            await model.load()
        }
        .refreshable {
            await model.load()
        }
    }

    private func upload(from item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let uid = auth.session?.user.id.uuidString else { return }
        await model.addImage(data: data, userId: uid, filename: "photo.jpg")
        pickerItem = nil
    }
}

@Observable
@MainActor
private final class TransformationGalleryViewModel {
    var isLoading = true
    var images: [TransformationImage] = []
    var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            images = try await ClientDataService.listTransformationImages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addImage(data: Data, userId: String, filename: String) async {
        do {
            let img = try await ClientDataService.uploadTransformationImage(
                data: data,
                originalFilename: filename,
                userId: userId
            )
            images.append(img)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
