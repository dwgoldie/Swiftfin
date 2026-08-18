//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct JellyseerrSearchRow: View {

    @ObservedObject
    var viewModel: JellyseerrSearchViewModel

    private let posterWidth: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.jellyseerr)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(viewModel.items) { item in
                        JellyseerrSearchResultCard(
                            item: item,
                            posterWidth: posterWidth,
                            isRequestable: viewModel.isRequestable(item),
                            isRequesting: viewModel.isRequesting(item),
                            isJustRequested: viewModel.isJustRequested(item)
                        ) {
                            Task { await viewModel.request(item) }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .alert(
            L10n.jellyseerrRequestFailed,
            isPresented: .init(
                get: { viewModel.requestError != nil },
                set: {
                    if !$0 {
                        viewModel.requestError = nil
                    }
                }
            )
        ) {
            Button(L10n.dismiss, role: .cancel) {}
        } message: {
            Text(viewModel.requestError ?? "")
        }
    }
}

private struct JellyseerrSearchResultCard: View {

    let item: JellyseerrMedia
    let posterWidth: CGFloat
    let isRequestable: Bool
    let isRequesting: Bool
    let isJustRequested: Bool
    let onRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomLeading) {
                ImageView(JellyseerrImageURL.poster(path: item.posterPath))
                    .aspectRatio(2 / 3, contentMode: .fill)
                    .frame(width: posterWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                statusBadge
                    .padding(6)
            }

            Text(item.displayTitle)
                .font(.caption)
                .lineLimit(2)
                .frame(width: posterWidth, alignment: .leading)

            if isRequestable {
                Button {
                    onRequest()
                } label: {
                    if isRequesting {
                        ProgressView()
                    } else {
                        Text(L10n.jellyseerrRequest)
                            .font(.caption2)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isRequesting)
            }
        }
        .frame(width: posterWidth)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isJustRequested {
            badge(L10n.jellyseerrRequested, color: .orange)
        } else if !isRequestable {
            badge(L10n.jellyseerrInLibrary, color: .green)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.85), in: Capsule())
            .foregroundStyle(.white)
    }
}
