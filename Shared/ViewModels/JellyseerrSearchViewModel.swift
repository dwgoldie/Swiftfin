//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import FactoryKit
import Foundation

/// Fans a search query out to Jellyseerr's catalog alongside the library
/// search -- what's popular that you could add, not just what you own.
final class JellyseerrSearchViewModel: ViewModel, WithRefresh {

    @Injected(\.jellyseerrService)
    private var jellyseerrService

    let query: String

    @Published
    private(set) var items: [JellyseerrMedia] = []
    @Published
    private(set) var hasRefreshed = false
    @Published
    private(set) var requestingKeys: Set<String> = []
    @Published
    private(set) var requestedKeys: Set<String> = []
    @Published
    var requestError: String?

    init(query: String) {
        self.query = query
        super.init()
    }

    func refresh() {
        Task { await refresh() }
    }

    func refresh() async {
        guard !query.isEmpty,
              let userID = try? authenticatedUser.id,
              let client = jellyseerrService.configuredClient(for: userID)
        else {
            hasRefreshed = true
            return
        }

        do {
            let result = try await client.search(query: query)
            items = result.results.filter { $0.posterPath != nil }
        } catch {
            logger.error("Unable to search Jellyseerr: \(error.localizedDescription)")
        }

        hasRefreshed = true
    }

    func isRequestable(_ media: JellyseerrMedia) -> Bool {
        media.isRequestable && !requestedKeys.contains(stableKey(for: media))
    }

    func isRequesting(_ media: JellyseerrMedia) -> Bool {
        requestingKeys.contains(stableKey(for: media))
    }

    func isJustRequested(_ media: JellyseerrMedia) -> Bool {
        requestedKeys.contains(stableKey(for: media))
    }

    func request(_ media: JellyseerrMedia) async {
        guard let userID = try? authenticatedUser.id,
              let client = jellyseerrService.configuredClient(for: userID)
        else { return }

        let key = stableKey(for: media)
        requestingKeys.insert(key)
        defer { requestingKeys.remove(key) }

        do {
            try await client.createRequest(mediaType: media.mediaType, tmdbID: media.id)
            requestedKeys.insert(key)
        } catch {
            requestError = error.localizedDescription
        }
    }

    private func stableKey(for media: JellyseerrMedia) -> String {
        "\(media.mediaType.rawValue)-\(media.id)"
    }
}
