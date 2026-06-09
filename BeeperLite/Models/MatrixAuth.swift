import Foundation

/// Request body for Matrix standard password login
struct MatrixLoginRequest: Codable {
    let type: String
    let identifier: LoginIdentifier
    let password: String
    let initialDeviceDisplayName: String?

    enum CodingKeys: String, CodingKey {
        case type
        case identifier
        case password
        case initialDeviceDisplayName = "initial_device_display_name"
    }
}

struct LoginIdentifier: Codable {
    let type: String
    let user: String
}

/// Response body from a successful Matrix login
struct MatrixLoginResponse: Codable {
    let userId: String
    let accessToken: String
    let homeServer: String
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case accessToken = "access_token"
        case homeServer = "home_server"
        case deviceId = "device_id"
    }
}

/// A generic error response from a Matrix homeserver
struct MatrixErrorResponse: Codable, Error {
    let errcode: String
    let error: String
}
