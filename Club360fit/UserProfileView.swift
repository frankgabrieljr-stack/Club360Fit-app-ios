import Auth
import Observation
import PhotosUI
import SwiftUI
import UIKit
import Supabase

/// Rich profile — mirrors Android `UserProfileScreen` (avatar, role, sign out).
struct UserProfileView: View {
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var uploadError: String?

    var body: some View {
        ZStack {
            Club360ScreenBackground()
            ScrollView {
                VStack(spacing: 22) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            avatarView
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Club360Theme.teal.opacity(0.8), Club360Theme.purpleLight.opacity(0.6)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2.5
                                        )
                                )
                            Circle()
                                .fill(Club360Theme.primaryButtonGradient)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if isUploadingAvatar {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "camera.fill")
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .shadow(color: Club360Theme.purple.opacity(0.35), radius: 6, y: 3)
                        }
                    }
                    .disabled(isUploadingAvatar)
                    .onChange(of: pickerItem) { _, new in
                        Task { await uploadAvatar(from: new) }
                    }

                    Text("Change photo")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Club360Theme.tealDark.opacity(0.75))

                    Text(displayName)
                        .font(.title2.bold())
                        .foregroundStyle(Club360Theme.cardTitle)

                    if let email = auth.session?.user.email {
                        Text(email)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Status")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(roleLabel)
                            .fontWeight(.semibold)
                            .foregroundStyle(Club360Theme.tealDark)
                    }
                    .padding(16)
                    .club360Glass()

                    if let uploadError {
                        Text(uploadError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    NavigationLink { ChangePasswordView() } label: {
                        Text("Change password")
                    }
                    .buttonStyle(Club360PrimaryGradientButtonStyle())

                    Button("Sign out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                .padding()
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }

    private var avatarView: some View {
        Group {
            if let urlString = avatarURLString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty: ProgressView()
                    case let .success(img): img.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Club360Theme.teal.opacity(0.45))
                    }
                }
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Club360Theme.teal.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Club360Theme.mint.opacity(0.5), Club360Theme.teal.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var avatarURLString: String? {
        guard let meta = auth.session?.user.userMetadata else { return nil }
        if case let .string(s) = meta["avatar_url"] { return s }
        if case let .string(s) = meta["picture"]    { return s }
        return nil
    }

    private var displayName: String {
        guard let meta = auth.session?.user.userMetadata else { return "Member" }
        if case let .string(name) = meta["name"], !name.isEmpty { return name }
        if let email = auth.session?.user.email,
           let local = email.split(separator: "@").first { return String(local) }
        return "Member"
    }

    private var roleLabel: String {
        auth.session?.user.isAdminRole == true ? "Admin" : "Client"
    }

    // MARK: - Avatar upload (converts any source format to JPEG before uploading)
    private func uploadAvatar(from item: PhotosPickerItem?) async {
        guard let item else { return }

        // Load raw bytes from the picker
        guard let rawData = try? await item.loadTransferable(type: Data.self) else {
            uploadError = "Could not load image data."
            return
        }
        guard let uid = auth.session?.user.id.uuidString.lowercased() else { return }

        // Convert to JPEG regardless of source format (HEIC, PNG, etc.).
        // This ensures the avatars bucket always stores a proper JPEG and
        // the content-type header matches `image/jpeg`.
        guard let uiImage = UIImage(data: rawData),
              let jpegData = uiImage.jpegData(compressionQuality: 0.85)
        else {
            uploadError = "Could not convert image to JPEG."
            return
        }

        isUploadingAvatar = true
        uploadError = nil
        defer { isUploadingAvatar = false }

        do {
            let url = try await ClientDataService.uploadUserAvatar(data: jpegData, userId: uid)
            do {
                try await auth.updateUserMetadata(["avatar_url": .string(url.absoluteString)])
            } catch {
                uploadError = "Saved photo, but profile update failed: \(error.localizedDescription)"
                return
            }
            pickerItem = nil
        } catch {
            uploadError = "Upload failed: \(error.localizedDescription)"
        }
    }
}
