//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct JellyseerrSettingsView: View {

    @Router
    private var router

    @StateObject
    private var viewModel = JellyseerrSettingsViewModel()

    @State
    private var isConnecting = false

    var body: some View {
        Form {
            Section {
                TextField(L10n.jellyseerrServerURL, text: $viewModel.serverURLString)
                #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                #endif
                    .autocorrectionDisabled()

                TextField(L10n.jellyseerrUsername, text: $viewModel.username)
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
                    .autocorrectionDisabled()

                SecureField(L10n.jellyseerrPassword, text: $viewModel.password)
            } footer: {
                Text(L10n.jellyseerrSettingsDescription)
            }

            Section {
                statusRow

                Button(L10n.jellyseerrTestConnection) {
                    isConnecting = true
                    Task {
                        await viewModel.testAndSave()
                        isConnecting = false
                    }
                }
                .disabled(isConnecting || viewModel.serverURLString.isEmpty || viewModel.username.isEmpty)

                if case .connected = viewModel.connectionState {
                    Button(L10n.jellyseerrDisconnect, role: .destructive) {
                        viewModel.disconnect()
                    }
                }
            }
        }
        .navigationTitle(L10n.jellyseerr)
        #if os(iOS)
            .navigationBarCloseButton {
                router.dismiss()
            }
        #endif
    }

    @ViewBuilder
    private var statusRow: some View {
        switch viewModel.connectionState {
        case .idle:
            EmptyView()
        case .connecting:
            HStack {
                Text(L10n.jellyseerrConnecting)
                Spacer()
                ProgressView()
            }
        case let .connected(displayName):
            Label(
                L10n.jellyseerrConnectedAs(displayName),
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        case let .error(message):
            Label(message, systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
