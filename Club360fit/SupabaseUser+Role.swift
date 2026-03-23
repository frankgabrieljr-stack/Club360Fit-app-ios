import Auth
import Foundation
import Supabase

extension User {
    /// Same as Android: `user.userMetadata["role"] == "admin"`.
    var isAdminRole: Bool {
        guard let role = userMetadata["role"] else { return false }
        if case let .string(value) = role { return value == "admin" }
        return false
    }
}

extension Session {
    var userIsAdmin: Bool {
        user.isAdminRole
    }
}
