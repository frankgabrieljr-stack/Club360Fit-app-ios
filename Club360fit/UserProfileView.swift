import Auth
import Observation
import PhotosUI
import SwiftUI
import Supabase

/// Rich profile — mirrors Android `UserProfileScreen` (avatar, role, sign out).
struct UserProfileView: View {
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @Environment(ClientHomeViewModel.self) private var home: ClientHomeViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var uploadError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        avatarView
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Club360Theme.burgundy.opacity(0.3), lineWidth: 2))

                        Circle()
                            .fill(Club360Theme.burgundy)
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
                    }
                }
                .disabled(isUploadingAvatar)
                .onChange(of: pickerItem) { _, new in
                    Task { await uploadAvatar(from: new) }
                }

                Text("Change photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(displayName)
                    .font(.title2.bold())
                    .foregroundStyle(Club360Theme.burgundy)

                if let email = auth.session?.user.email {
                    Text(email)
                        .font(.body)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    Text(roleLabel)
                        .fontWeight(.medium)
                        .foregroundStyle(Club360Theme.burgundy)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if let cid = home.clientId {
                    LabeledContent("Client ID", value: cid)
                }

                if let uploadError {
                    Text(uploadError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                NavigationLink("Change password") {
                    ChangePasswordView()
                }
                .buttonStyle(.borderedProminent)
                .tint(Club360Theme.burgundy)

                Button("Sign out", role: .destructive) {
                    Task { await auth.signOut() }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var avatarView: some View {
        Group {
            if let urlString = avatarURLString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case let .success(img):
                        img.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Club360Theme.burgundy.opacity(0.5))
                    }
                }
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Club360Theme.burgundy.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Club360Theme.burgundy.opacity(0.12))
    }

    private var avatarURLString: String? {
        guard let meta = auth.session?.user.userMetadata else { return nil }
        if case let .string(s) = meta["avatar_url"] { return s }
        if case let .string(s) = meta["picture"] { return s }
        return nil
    }

    private var displayName: String {
        guard let meta = auth.session?.user.userMetadata else { return "Member" }
        if case let .string(name) = meta["name"], !name.isEmpty { return name }
        if let email = auth.session?.user.email, let local = email.split(separator: "@").first {
            return String(local)
        }
        return "Member"
    }

    private var roleLabel: String {
        auth.session?.user.isAdminRole == true ? "Admin" : "Client"
    }

    private func uploadAvatar(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let uid = auth.session?.user.id.uuidString else { return }
        isUploadingAvatar = true
        uploadError = nil
        defer { isUploadingAvatar = false }
        do {
            let url = try await ClientDataService.uploadUserAvatar(data: data, userId: uid)
            try await auth.updateUserMetadata(["avatar_url": .string(url.absoluteString)])
            pickerItem = nil
        } catch {
            uploadError = error.localizedDescription
        }
    }
}
