//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

struct SearchView: View {

    #if os(iOS)
    @Default(.Customization.Search.enabledDrawerFilters)
    private var enabledDrawerFilters
    #endif

    @FocusState
    private var isSearchFocused: Bool

    @Namespace
    private var namespace

    @Router
    private var router

    @State
    private var searchQuery = ""

    @StateObject
    private var focusCoordinator: FocusCoordinator = .init()
    @StateObject
    private var viewModel = SearchViewModel()

    @TabItemSelected
    private var tabItemSelected

    @ViewBuilder
    private var suggestionsView: some View {
        #if os(tvOS)
        // An interactive "Discover" state: browsable posters from
        // across the user's libraries, with a cinematic background
        // for the focused poster.
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.discover)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .edgePadding(.horizontal)

                PosterHStack(
                    elements: viewModel.suggestions,
                    displayType: .portrait,
                    size: .medium
                ) { item, _ in
                    router.route(to: .item(item: item), in: namespace)
                }
            }
            .edgePadding(.vertical)
        }
        .scrollIndicators(.hidden)
        #else
        VStack(spacing: 20) {
            ForEach(viewModel.suggestions) { item in
                Button(item.displayTitle) {
                    searchQuery = item.displayTitle
                }
            }
        }
        #endif
    }

    @ViewBuilder
    private var resultsView: some View {
        ScrollView {
            ContentGroupVStack(
                groups: viewModel.itemContentGroupViewModel.groups
            )
            .edgePadding(.vertical)
        }
        .scrollIndicators(.hidden)
    }

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .error:
                viewModel.error.map(ErrorView.init)
            case .initial:
                if viewModel.canSearch {
                    if viewModel.isEmpty {
                        Text(L10n.noResults)
                    } else {
                        resultsView
                    }
                } else {
                    suggestionsView
                }
            case .searching:
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(tvOS)
            .background {
                FocusedPosterCinematicBackgroundView()
            }
        #endif
            .animation(.linear(duration: 0.2), value: viewModel.state)
                .ignoresSafeArea(.keyboard)
                .navigationTitle(L10n.search)
                .toolbarTitleDisplayMode(.inline)
                .searchFocused($isSearchFocused)
                .onReceive(tabItemSelected) { event in
                    if event.isRepeat, event.isRoot {
                        isSearchFocused = true
                    }
                }
                .onFirstAppear {
                    viewModel.getSuggestions()
                }
                .onChange(of: searchQuery) {
                    viewModel.search(query: searchQuery)
                }
                .searchable(
                    text: $searchQuery,
                    prompt: L10n.search
                )
                .environmentObject(focusCoordinator)
        #if os(tvOS)
            .edgePadding(.top)
        #else
            .navigationBarFilterDrawer(
                viewModel: viewModel.filterViewModel,
                types: enabledDrawerFilters
            )
        #endif
    }
}
