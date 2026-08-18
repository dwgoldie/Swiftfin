//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation

struct JellyseerrStatus: Decodable {
    let version: String
    let updateAvailable: Bool
}

struct JellyseerrUser: Decodable {
    let id: Int
    let email: String?
    let username: String?
    let jellyfinUsername: String?

    var displayName: String {
        jellyfinUsername ?? username ?? email ?? "Jellyseerr user"
    }
}

struct JellyseerrJellyfinAuthBody: Encodable {
    let username: String
    let password: String
}

enum JellyseerrError: LocalizedError {
    case invalidURL
    case unauthorized
    case unexpectedResponse(statusCode: Int)
    case decoding(Error)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            L10n.jellyseerrInvalidURL
        case .unauthorized:
            L10n.jellyseerrUnauthorized
        case let .unexpectedResponse(statusCode):
            L10n.jellyseerrUnexpectedResponse(statusCode)
        case let .decoding(error):
            error.localizedDescription
        case .notConfigured:
            L10n.jellyseerrNotConfigured
        }
    }
}
