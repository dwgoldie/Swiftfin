//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import SwiftUI

/// An Apple TV-style featured banner for the top of a library,
/// cycling through the library's newest and recently played items.
struct FeaturedLibraryHeader: View {

    @Namespace
    private var namespace

    @ObservedObject
    var viewModel: FeaturedItemsViewModel

    @Router
    private var router

    @State
    private var selectedIndex: Int = 0

    #if os(tvOS)
    @FocusState
    private var isFocused: Bool

    private static let bannerHeight: CGFloat = 560
    #else
    /// A definite height for the iOS hero. The collection-view header
    /// measures its content up-front, so it must not depend on an
    /// async image's (initially zero) intrinsic size.
    private static var bannerHeight: CGFloat {
        let width = UIScreen.main.bounds.width - EdgeInsets.edgePadding * 2
        return width * 9 / 16
    }
    #endif

    private static let rotationInterval: TimeInterval = 7

    private let timer = Timer.publish(
        every: Self.rotationInterval,
        on: .main,
        in: .common
    ).autoconnect()

    private var selectedItem: BaseItemDto? {
        guard viewModel.items.indices.contains(selectedIndex) else {
            return viewModel.items.first
        }
        return viewModel.items[selectedIndex]
    }

    private func advance() {
        guard viewModel.items.count > 1 else { return }

        withAnimation(.smooth(duration: 0.6)) {
            selectedIndex = (selectedIndex + 1) % viewModel.items.count
        }
    }

    private func logoImageSource(for item: BaseItemDto, maxWidth: CGFloat) -> ImageSource {
        item.imageSource(
            .logo,
            environment: ImageSourceOptions(
                maxWidth: maxWidth,
                maxHeight: FeaturedLibraryHeaderMetrics.logoMaxHeight
            )
        )
    }

    // MARK: - Banner card

    @ViewBuilder
    private func bannerCard(for item: BaseItemDto) -> some View {
        ImageView(item.landscapeImageSources(environment: .default))
            .placeholder { imageSource in
                DefaultPlaceholderView(blurHash: imageSource.blurHash)
            }
            .failure {
                Color.secondarySystemFill
                    .opacity(0.75)
            }
            .aspectRatio(contentMode: .fill)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {

                    ImageView(logoImageSource(for: item, maxWidth: 300))
                        .placeholder { _ in
                            titleLabel(for: item)
                        }
                        .failure {
                            titleLabel(for: item)
                        }
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: FeaturedLibraryHeaderMetrics.logoMaxHeight, alignment: .bottomLeading)

                    if let tagline = item.taglines?.first ?? item.overview {
                        Text(tagline)
                            .font(.footnote)
                            .lineLimit(2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(EdgeInsets.edgePadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 180, alignment: .bottom)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .id(item.hashValue)
            .transition(.opacity)
    }

    @ViewBuilder
    private func titleLabel(for item: BaseItemDto) -> some View {
        Text(item.displayTitle)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .lineLimit(2)
    }

    @ViewBuilder
    private var placeholderCard: some View {
        ZStack {
            Color.secondarySystemFill
                .opacity(0.75)

            ProgressView()
        }
    }

    // MARK: - body

    var body: some View {
        #if os(tvOS)
        tvOSBody
        #else
        iOSBody
        #endif
    }

    // MARK: - iOS

    #if !os(tvOS)
    @ViewBuilder
    private var iOSBody: some View {
        ZStack {
            if let selectedItem {
                Button {
                    router.route(to: .item(item: selectedItem), in: namespace)
                } label: {
                    bannerCard(for: selectedItem)
                }
                .buttonStyle(.plain)
                .backport
                .matchedTransitionSource(id: "item", in: namespace)
            } else {
                placeholderCard
            }
        }
        .frame(height: Self.bannerHeight)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottomTrailing) {
            indexIndicator
                .padding(12)
        }
        .padding(.horizontal, EdgeInsets.edgePadding)
        .padding(.top, EdgeInsets.edgePadding)
        .onReceive(timer) { _ in
            advance()
        }
        .animation(.smooth(duration: 0.6), value: selectedIndex)
    }
    #endif

    // MARK: - tvOS

    #if os(tvOS)
    @ViewBuilder
    private var tvOSBody: some View {
        ZStack {
            if let selectedItem {
                Button {
                    router.route(to: .item(item: selectedItem), in: namespace)
                } label: {
                    bannerCard(for: selectedItem)
                        .frame(height: Self.bannerHeight)
                }
                .buttonStyle(.card)
                .focused($isFocused)
            } else {
                placeholderCard
                    .frame(height: Self.bannerHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.bannerHeight)
        .overlay(alignment: .bottomTrailing) {
            indexIndicator
                .padding(30)
        }
        .padding(.vertical, 20)
        .onReceive(timer) { _ in
            guard !isFocused else { return }
            advance()
        }
        .animation(.smooth(duration: 0.6), value: selectedIndex)
    }
    #endif

    // MARK: - index indicator

    @ViewBuilder
    private var indexIndicator: some View {
        if viewModel.items.count > 1 {
            HStack(spacing: 6) {
                ForEach(viewModel.items.indices, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(index == selectedIndex ? 0.9 : 0.4))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }
}

private enum FeaturedLibraryHeaderMetrics {

    static let logoMaxHeight: CGFloat = {
        #if os(tvOS)
        100
        #else
        60
        #endif
    }()
}
