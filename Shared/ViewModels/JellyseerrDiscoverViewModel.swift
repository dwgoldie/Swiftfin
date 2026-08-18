//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import FactoryKit
import Foundation

/// Trending movies/shows from Jellyseerr's TMDB-backed catalog -- what you
/// could add, not what's already in the library.
final class JellyseerrDiscoverViewModel: ViewModel, WithRefresh {

    @Injected(\.jellyseerrService)
    private var jellyseerrService

    @Published
    private(set) var items: [JellyseerrMedia] = []
    @Published
    private(set) var hasRefreshed = false

    func refresh() {
        Task { await refresh() }
    }

    func refresh() async {
        guard let userID = try? authenticatedUser.id,
              let client = jellyseerrService.configuredClient(for: userID)
        else {
            hasRefreshed = true
            return
        }

        do {
            let result = try await client.fetchTrending()
            items = result.results.filter { $0.posterPath != nil }
        } catch {
            logger.error("Unable to retrieve Jellyseerr trending: \(error.localizedDescription)")
        }

        hasRefreshed = true
    }
}
