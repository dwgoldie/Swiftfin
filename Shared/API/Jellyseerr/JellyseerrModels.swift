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

enum JellyseerrMediaType: String, Codable {
    case movie
    case tv
}

/// Jellyseerr's own numeric media-status enum. Lenient decode: a future
/// Jellyseerr adding a new state shouldn't abort decoding the whole
/// search/discover response over one unrecognized entry.
enum JellyseerrMediaStatus: Int, Decodable {
    case unknown = 1
    case pending = 2
    case processing = 3
    case partiallyAvailable = 4
    case available = 5
    case deleted = 7

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(Int.self)
        self = JellyseerrMediaStatus(rawValue: raw) ?? .unknown
    }

    /// Whether this status means "don't offer a request button" -- already
    /// in the library, in the download pipeline, or awaiting approval.
    var isRequestable: Bool {
        self == .unknown || self == .deleted
    }
}

struct JellyseerrMediaInfo: Decodable {
    let status: JellyseerrMediaStatus?
}

struct JellyseerrMedia: Decodable, Identifiable, Hashable {
    let id: Int
    let mediaType: JellyseerrMediaType
    let title: String?
    let name: String?
    let posterPath: String?
    let overview: String?
    let mediaInfo: JellyseerrMediaInfo?

    var displayTitle: String {
        title ?? name ?? ""
    }

    var isRequestable: Bool {
        mediaInfo?.status?.isRequestable ?? true
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

/// `/api/v1/search` mixes in `person` and other TMDB result types alongside
/// movies/shows; anything that isn't `.movie`/`.tv` is dropped rather than
/// failing the whole decode, since a single unusable entry shouldn't cost
/// the rest of the page.
struct JellyseerrSearchResult: Decodable {
    let results: [JellyseerrMedia]

    private enum CodingKeys: String, CodingKey {
        case results
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decodeIfPresent([Entry].self, forKey: .results) ?? []
        results = entries.compactMap(\.media)
    }

    private enum Entry: Decodable {
        case media(JellyseerrMedia)
        case other

        private enum TypeKey: String, CodingKey {
            case mediaType
        }

        var media: JellyseerrMedia? {
            if case let .media(media) = self {
                return media
            }
            return nil
        }

        init(from decoder: Decoder) throws {
            let type = try? decoder.container(keyedBy: TypeKey.self)
                .decodeIfPresent(String.self, forKey: .mediaType)
            if type == "movie" || type == "tv" {
                self = (try? JellyseerrMedia(from: decoder)).map(Entry.media) ?? .other
            } else {
                self = .other
            }
        }
    }
}

struct JellyseerrCreateRequestBody: Encodable {
    let mediaType: JellyseerrMediaType
    let mediaId: Int
}

struct JellyseerrRequest: Decodable {
    let id: Int?
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
    /// Jellyseerr's `POST /request` signals this failure inside the 2xx
    /// range (202 + a message body) rather than as an HTTP error -- every
    /// season requested was already requested, processing, or available.
    case noSeasonsAvailable

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
        case .noSeasonsAvailable:
            L10n.jellyseerrNoSeasonsAvailable
        }
    }
}
