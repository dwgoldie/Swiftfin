//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

/// Provides the items for a library's featured banner: the newest
/// additions to the library, blended with recently played items.
final class FeaturedItemsViewModel: ViewModel {

    private static let featuredLimit = 8

    @Published
    private(set) var hasRefreshed = false
    @Published
    private(set) var items: [BaseItemDto] = []

    private let parent: BaseItemDto?

    /// Whether the parent library supports a featured banner.
    var isEligible: Bool {
        guard let parent, parent.type == .userView else { return false }

        return parent.collectionType == nil ||
            parent.collectionType == .movies ||
            parent.collectionType == .tvshows
    }

    var shouldDisplay: Bool {
        isEligible && !(hasRefreshed && items.isEmpty)
    }

    init(parent: BaseItemDto?) {
        self.parent = parent
        super.init()
    }

    func refresh() {
        guard isEligible, let parent else { return }

        Task { @MainActor in
            do {
                let userSession = try requireUserSession()

                var latestParameters = Paths.GetItemsParameters()
                latestParameters.parentID = parent.id
                latestParameters.includeItemTypes = [.movie, .series]
                latestParameters.isRecursive = true
                latestParameters.limit = Self.featuredLimit
                latestParameters.sortBy = [ItemSortBy.dateCreated]
                latestParameters.sortOrder = [.descending]
                latestParameters.userID = userSession.user.id
                latestParameters.fields = ItemFields.MinimumFields
                    .appending(.overview)
                    .appending(.taglines)

                var recentlyPlayedParameters = latestParameters
                recentlyPlayedParameters.sortBy = [ItemSortBy.datePlayed]
                recentlyPlayedParameters.limit = Self.featuredLimit / 2

                async let latest = userSession.client.send(Paths.getItems(parameters: latestParameters))
                async let recentlyPlayed = userSession.client.send(Paths.getItems(parameters: recentlyPlayedParameters))

                let latestItems = try await latest.value.items ?? []
                let recentlyPlayedItems = try await recentlyPlayed.value.items ?? []

                var seenIDs = Set<String>()
                var interleaved: [BaseItemDto] = []

                for pairIndex in 0 ..< max(latestItems.count, recentlyPlayedItems.count) {
                    for source in [latestItems, recentlyPlayedItems] where pairIndex < source.count {
                        let item = source[pairIndex]
                        guard let id = item.id, seenIDs.insert(id).inserted else { continue }
                        interleaved.append(item)
                    }
                }

                self.items = Array(interleaved.prefix(Self.featuredLimit))
                self.hasRefreshed = true
            } catch {
                logger.error("Unable to retrieve featured items: \(error.localizedDescription)")
                self.hasRefreshed = true
            }
        }
    }
}
