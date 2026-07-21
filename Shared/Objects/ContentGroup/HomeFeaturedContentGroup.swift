//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// A featured hero banner at the top of the home screen, cycling through
/// the newest additions across all libraries — the Netflix / Disney+ /
/// Apple TV "spotlight" treatment.
struct HomeFeaturedContentGroup: ContentGroup {

    let id = "home-featured"
    let viewModel: FeaturedItemsViewModel

    var _shouldBeResolved: Bool {
        viewModel.shouldDisplay && viewModel.items.isNotEmpty
    }

    init() {
        self.viewModel = FeaturedItemsViewModel(source: .home)
    }

    @ViewBuilder
    func body(with viewModel: FeaturedItemsViewModel) -> some View {
        FeaturedLibraryHeader(viewModel: viewModel)
    }
}
