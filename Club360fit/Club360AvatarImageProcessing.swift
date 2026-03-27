import UIKit

/// Normalizes PhotosPicker output to JPEG bytes for Storage (`image/jpeg`).
enum Club360AvatarImageProcessing {
    /// Returns JPEG data suitable for `avatars/{uid}/avatar.jpg`, or `nil` if the image could not be decoded.
    static func jpegDataForAvatarUpload(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return jpegDataForAvatarUpload(image)
    }

    /// Returns JPEG data from an already decoded image.
    static func jpegDataForAvatarUpload(_ image: UIImage) -> Data? {
        image.jpegData(compressionQuality: 0.88)
    }
}
