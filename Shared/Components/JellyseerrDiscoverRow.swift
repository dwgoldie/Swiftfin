//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct JellyseerrDiscoverRow: View {

    let items: [JellyseerrMedia]

    private let posterWidth: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.discover)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in
                        JellyseerrMediaCard(item: item, posterWidth: posterWidth)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct JellyseerrMediaCard: View {

    let item: JellyseerrMedia
    let posterWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ImageView(JellyseerrImageURL.poster(path: item.posterPath))
                .aspectRatio(2 / 3, contentMode: .fill)
                .frame(width: posterWidth)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.displayTitle)
                .font(.caption)
                .lineLimit(2)
                .frame(width: posterWidth, alignment: .leading)
        }
    }
}
