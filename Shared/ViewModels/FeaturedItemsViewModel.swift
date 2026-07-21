//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

/// Provides the items for a featured banner: either the newest additions
/// to a single library (blended with recently played items from it), or —
/// for the home screen — the newest additions across all libraries.
final class FeaturedItemsViewModel: ViewModel, WithRefresh {

    enum Source {
        /// A single library's banner.
        case library(BaseItemDto)
        /// The home screen banner: latest across all libraries.
        case home
    }

    private static let featuredLimit = 8

    @Published
    private(set) var hasRefreshed = false
    @Published
    private(set) var items: [BaseItemDto] = []

    private let source: Source

    /// Whether this source supports a featured banner.
    ///
    /// For a library, keyed off `collectionType` rather than `type`:
    /// Jellyfin returns movie/show libraries from `/UserViews` as
    /// `.collectionFolder` (not `.userView`), so gating on `type` would
    /// silently disable the banner.
    var isEligible: Bool {
        switch source {
        case let .library(parent):
            parent.collectionType == .movies || parent.collectionType == .tvshows
        case .home:
            true
        }
    }

    var shouldDisplay: Bool {
        isEligible && !(hasRefreshed && items.isEmpty)
    }

    init(source: Source) {
        self.source = source
        super.init()
    }

    convenience init(parent: BaseItemDto?) {
        if let parent {
            self.init(source: .library(parent))
        } else {
            self.init(source: .home)
        }
    }

    /// Fire-and-forget refresh, for callers outside the content-group flow.
    func refresh() {
        Task { await refresh() }
    }

    func refresh() async {
        guard isEligible else { return }

        do {
            let userSession = try requireUserSession()

            var latestParameters = Paths.GetItemsParameters()
            latestParameters.includeItemTypes = [.movie, .series]
            latestParameters.isRecursive = true
            latestParameters.limit = Self.featuredLimit
            latestParameters.sortBy = [ItemSortBy.dateCreated]
            latestParameters.sortOrder = [.descending]
            latestParameters.userID = userSession.user.id
            latestParameters.fields = ItemFields.MinimumFields
                .appending(.overview)
                .appending(.taglines)

            if case let .library(parent) = source {
                latestParameters.parentID = parent.id
            }

            let items: [BaseItemDto]

            switch source {
            case .library:
                // Blend newest additions with recently played from the library.
                var recentlyPlayedParameters = latestParameters
                recentlyPlayedParameters.sortBy = [ItemSortBy.datePlayed]
                recentlyPlayedParameters.limit = Self.featuredLimit / 2

                async let latest = userSession.client.send(Paths.getItems(parameters: latestParameters))
                async let recentlyPlayed = userSession.client.send(Paths.getItems(parameters: recentlyPlayedParameters))

                items = try await interleave(
                    latest.value.items ?? [],
                    recentlyPlayed.value.items ?? []
                )
            case .home:
                let response = try await userSession.client.send(Paths.getItems(parameters: latestParameters))
                items = response.value.items ?? []
            }

            self.items = Array(items.prefix(Self.featuredLimit))
            self.hasRefreshed = true
        } catch {
            logger.error("Unable to retrieve featured items: \(error.localizedDescription)")
            self.hasRefreshed = true
        }
    }

    private func interleave(_ a: [BaseItemDto], _ b: [BaseItemDto]) -> [BaseItemDto] {
        var seenIDs = Set<String>()
        var result: [BaseItemDto] = []

        for index in 0 ..< max(a.count, b.count) {
            for source in [a, b] where index < source.count {
                let item = source[index]
                guard let id = item.id, seenIDs.insert(id).inserted else { continue }
                result.append(item)
            }
        }

        return result
    }
}
