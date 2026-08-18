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

enum JellyseerrMediaType: String, Decodable {
    case movie
    case tv
}

struct JellyseerrMedia: Decodable, Identifiable, Hashable {
    let id: Int
    let mediaType: JellyseerrMediaType
    let title: String?
    let name: String?
    let posterPath: String?
    let overview: String?

    var displayTitle: String {
        title ?? name ?? ""
    }

    /// TMDB reuses numeric ids across movies and shows, so the type has to
    /// be part of identity.
    static func == (lhs: JellyseerrMedia, rhs: JellyseerrMedia) -> Bool {
        lhs.id == rhs.id && lhs.mediaType == rhs.mediaType
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(mediaType)
    }
}

struct JellyseerrDiscoverResult: Decodable {
    let page: Int
    let totalPages: Int
    let results: [JellyseerrMedia]
}

enum JellyseerrImageURL {

    private static let base = URL(string: "https://image.tmdb.org/t/p")!

    static func poster(path: String?, width: Int = 500) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let cleaned = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return base.appendingPathComponent("w\(width)").appendingPathComponent(cleaned)
    }
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
