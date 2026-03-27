import Auth
import Observation
import PhotosUI
import SwiftUI
import Supabase
import UIKit

/// Rich profile — mirrors Android `UserProfileScreen` (avatar, role, sign out).
struct UserProfileView: View {
    @Environment(Club360AuthSession.self) private var auth: Club360AuthSession
    @State private var pickerItem: PhotosPickerItem?
    @State private var pendingAvatarImage: UIImage?
    @State private var showAvatarEditor = false
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var bio = ""
    @State private var location = ""
    @State private var timezone = ""
    @State private var phone = ""
    @State private var coachHeadline = ""
    @State private var coachSpecialties = ""
    @State private var coachAvailability = ""
    @State private var isSavingProfile = false
    @State private var profileMessage: String?
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
                        Task { await prepareAvatarForEditing(from: new) }
                    }

                    Text("Change photo")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Club360Theme.burgundy.opacity(0.9))

                    Button("Remove photo", role: .destructive) {
                        Task { await removeAvatar() }
                    }
                    .font(.caption)
                    .disabled(isUploadingAvatar)

                    Text(displayName)
                        .font(.title2.bold())
                        .foregroundStyle(Club360Theme.cardTitle)

                    if let email = auth.session?.user.email {
                        Text(email)
                            .font(.body)
                            .foregroundStyle(Club360Theme.captionOnGlass)
                    }

                    HStack {
                        Text("Status")
                            .foregroundStyle(Club360Theme.captionOnGlass)
                        Spacer()
                        Text(roleLabel)
                            .fontWeight(.semibold)
                            .foregroundStyle(Club360Theme.burgundy)
                    }
                    .padding(16)
                    .club360Glass()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Profile details")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Club360Theme.cardTitle)

                        TextField("First name", text: $firstName)
                            .textFieldStyle(.roundedBorder)
                        TextField("Last name", text: $lastName)
                            .textFieldStyle(.roundedBorder)
                        TextField("Short bio", text: $bio, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2 ... 4)
                        TextField("Location (city, country)", text: $location)
                            .textFieldStyle(.roundedBorder)
                        TextField("Timezone", text: $timezone)
                            .textFieldStyle(.roundedBorder)
                        TextField("Phone", text: $phone)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.phonePad)

                        if auth.session?.user.isAdminRole == true {
                            Divider()
                            Text("Coach details")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Club360Theme.cardTitle)
                            TextField("Coach headline", text: $coachHeadline)
                                .textFieldStyle(.roundedBorder)
                            TextField("Specialties (comma separated)", text: $coachSpecialties, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2 ... 4)
                            TextField("Availability", text: $coachAvailability, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2 ... 4)
                        }

                        if let profileMessage {
                            Text(profileMessage)
                                .font(.footnote)
                                .foregroundStyle(profileMessage.localizedCaseInsensitiveContains("saved") ? Club360Theme.burgundy : .red)
                        }

                        Button {
                            Task { await saveProfileDetails() }
                        } label: {
                            Text(isSavingProfile ? "Saving…" : "Save details")
                        }
                        .buttonStyle(Club360PrimaryGradientButtonStyle())
                        .disabled(isSavingProfile)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .club360Glass(cornerRadius: 22)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Club360Theme.cardTitle)
                        Text("Email")
                            .font(.caption)
                            .foregroundStyle(Club360Theme.captionOnGlass)
                        Text(auth.session?.user.email ?? "-")
                            .foregroundStyle(Club360Theme.cardTitle)
                            .font(.body)
                        Text("Email changes should use the secure auth flow.")
                            .font(.footnote)
                            .foregroundStyle(Club360Theme.captionOnGlass)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .club360Glass(cornerRadius: 22)

                    if auth.session?.user.isAdminRole == true {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Coach profile preview")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Club360Theme.cardTitle)

                            Text(coachHeadlineDisplay)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Club360Theme.burgundy)

                            Text("Specialties")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Club360Theme.captionOnGlass)
                            Text(coachSpecialtiesDisplay)
                                .font(.footnote)
                                .foregroundStyle(Club360Theme.cardTitle)

                            Text("Availability")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Club360Theme.captionOnGlass)
                            Text(coachAvailabilityDisplay)
                                .font(.footnote)
                                .foregroundStyle(Club360Theme.cardTitle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .club360Glass(cornerRadius: 22)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Coach & admin access")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Club360Theme.cardTitle)
                            Text(
                                "New sign-ups are always clients. As an admin, open a member from Clients → use Grant coach access on their hub, or set role in Supabase (Authentication → Users → User metadata). Deploy the set-user-role Edge Function from the repo for the in-app button. The member must sign out and sign in again."
                            )
                            .font(.footnote)
                            .foregroundStyle(Club360Theme.captionOnGlass)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .club360Glass(cornerRadius: 22)
                    }

                    if let uploadError {
                        Text(uploadError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    NavigationLink {
                        ChangePasswordView()
                    } label: {
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
        .preferredColorScheme(.light)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .onAppear(perform: populateEditableFieldsFromSession)
        .onChange(of: auth.session?.user.id.uuidString) { _, _ in
            populateEditableFieldsFromSession()
        }
        .sheet(isPresented: $showAvatarEditor) {
            if let pendingAvatarImage {
                AvatarCropEditorView(
                    image: pendingAvatarImage,
                    onCancel: {
                        showAvatarEditor = false
                        pickerItem = nil
                    },
                    onUse: { cropped in
                        showAvatarEditor = false
                        pickerItem = nil
                        Task { await uploadAvatarImage(cropped) }
                    }
                )
            }
        }
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
        if case let .string(s) = meta["picture"] { return s }
        return nil
    }

    private var displayName: String {
        let full = "\(firstName.trimmingCharacters(in: .whitespacesAndNewlines)) \(lastName.trimmingCharacters(in: .whitespacesAndNewlines))".trimmingCharacters(in: .whitespacesAndNewlines)
        if !full.isEmpty { return full }
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

    private var coachHeadlineDisplay: String {
        let value = coachHeadline.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Certified Coach" : value
    }

    private var coachSpecialtiesDisplay: String {
        let value = coachSpecialties.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Strength, nutrition, accountability" : value
    }

    private var coachAvailabilityDisplay: String {
        let value = coachAvailability.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Mon-Fri, 8am-6pm (local time)" : value
    }

    private func prepareAvatarForEditing(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let raw = try? await item.loadTransferable(type: Data.self) else {
            uploadError = "Could not read the photo. Try another image."
            return
        }
        guard let image = UIImage(data: raw) else {
            uploadError = "Could not use this image format. Try a photo from your library."
            return
        }
        pendingAvatarImage = image
        showAvatarEditor = true
    }

    private func uploadAvatarImage(_ image: UIImage) async {
        guard let jpeg = Club360AvatarImageProcessing.jpegDataForAvatarUpload(image) else {
            uploadError = "Could not process this photo. Try another image."
            return
        }
        guard let uid = auth.session?.user.id.uuidString else { return }
        isUploadingAvatar = true
        uploadError = nil
        defer { isUploadingAvatar = false }
        do {
            let url = try await ClientDataService.uploadUserAvatar(data: jpeg, userId: uid)
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

    private func removeAvatar() async {
        isUploadingAvatar = true
        uploadError = nil
        defer { isUploadingAvatar = false }
        do {
            try await auth.updateUserMetadata([
                "avatar_url": .null,
                "picture": .null,
            ])
        } catch {
            uploadError = "Could not remove photo: \(error.localizedDescription)"
        }
    }

    private func saveProfileDetails() async {
        isSavingProfile = true
        profileMessage = nil
        defer { isSavingProfile = false }
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let mergedName = "\(trimmedFirst) \(trimmedLast)".trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await auth.updateUserMetadata([
                "first_name": .string(trimmedFirst),
                "last_name": .string(trimmedLast),
                "name": .string(mergedName),
                "bio": .string(bio.trimmingCharacters(in: .whitespacesAndNewlines)),
                "location": .string(location.trimmingCharacters(in: .whitespacesAndNewlines)),
                "timezone": .string(timezone.trimmingCharacters(in: .whitespacesAndNewlines)),
                "phone": .string(phone.trimmingCharacters(in: .whitespacesAndNewlines)),
                "coach_headline": .string(coachHeadline.trimmingCharacters(in: .whitespacesAndNewlines)),
                "coach_specialties": .string(coachSpecialties.trimmingCharacters(in: .whitespacesAndNewlines)),
                "coach_availability": .string(coachAvailability.trimmingCharacters(in: .whitespacesAndNewlines)),
            ])
            profileMessage = "Profile details saved."
        } catch {
            profileMessage = error.localizedDescription
        }
    }

    private func populateEditableFieldsFromSession() {
        guard let meta = auth.session?.user.userMetadata else { return }
        firstName = metadataString(meta, "first_name")
        lastName = metadataString(meta, "last_name")
        bio = metadataString(meta, "bio")
        location = metadataString(meta, "location")
        timezone = metadataString(meta, "timezone")
        phone = metadataString(meta, "phone")
        coachHeadline = metadataString(meta, "coach_headline")
        coachSpecialties = metadataString(meta, "coach_specialties")
        coachAvailability = metadataString(meta, "coach_availability")
    }

    private func metadataString(_ meta: [String: AnyJSON], _ key: String) -> String {
        if case let .string(value) = meta[key] {
            return value
        }
        return ""
    }
}
