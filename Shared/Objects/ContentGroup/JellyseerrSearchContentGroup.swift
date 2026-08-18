//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// A search-results row of Jellyseerr catalog hits, alongside the library's
/// own search groups -- distinguishes what's already yours from what's
/// requestable via a status badge / inline request action per card.
struct JellyseerrSearchContentGroup: ContentGroup {

    let id: String
    let viewModel: JellyseerrSearchViewModel

    var _shouldBeResolved: Bool {
        viewModel.hasRefreshed && viewModel.items.isNotEmpty
    }

    init(query: String) {
        self.id = "jellyseerr-search-\(query)"
        self.viewModel = JellyseerrSearchViewModel(query: query)
    }

    @ViewBuilder
    func body(with viewModel: JellyseerrSearchViewModel) -> some View {
        JellyseerrSearchRow(viewModel: viewModel)
    }
}
