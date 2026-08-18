//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// A Home row of trending Jellyseerr content -- what's popular that isn't
/// in your library yet, distinct from the library-only rows around it.
/// Read-only for now: no request action until the search/request flow lands.
struct JellyseerrDiscoverContentGroup: ContentGroup {

    let id = "jellyseerr-discover-trending"
    let viewModel: JellyseerrDiscoverViewModel

    var _shouldBeResolved: Bool {
        viewModel.hasRefreshed && viewModel.items.isNotEmpty
    }

    init() {
        self.viewModel = JellyseerrDiscoverViewModel()
    }

    @ViewBuilder
    func body(with viewModel: JellyseerrDiscoverViewModel) -> some View {
        JellyseerrDiscoverRow(items: viewModel.items)
    }
}
