//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import FactoryKit
import Foundation

@MainActor
final class JellyseerrSettingsViewModel: ViewModel {

    enum ConnectionState: Equatable {
        case idle
        case connecting
        case connected(displayName: String)
        case error(String)
    }

    @Injected(\.jellyseerrService)
    private var jellyseerrService

    @Published
    var serverURLString: String = ""

    @Published
    var username: String = ""

    @Published
    var password: String = ""

    @Published
    private(set) var connectionState: ConnectionState = .idle

    override init() {
        super.init()

        serverURLString = Defaults[.jellyseerrServerURL]?.absoluteString ?? ""
        username = Defaults[.jellyseerrUsername] ?? ""
    }

    func testAndSave() async {
        guard let url = URL(string: serverURLString), url.scheme != nil else {
            connectionState = .error(L10n.jellyseerrInvalidURL)
            return
        }

        connectionState = .connecting

        let client = JellyseerrClient(baseURL: url)

        do {
            _ = try await client.fetchStatus()
            let user = try await client.loginWithJellyfin(username: username, password: password)

            guard let cookie = client.sessionCookie, let userID = try? authenticatedUser.id else {
                connectionState = .error(L10n.jellyseerrUnauthorized)
                return
            }

            jellyseerrService.save(serverURL: url, username: username)
            jellyseerrService.persistSession(cookie: cookie, for: userID)

            password = ""
            connectionState = .connected(displayName: user.displayName)
        } catch {
            connectionState = .error(error.localizedDescription)
        }
    }

    func disconnect() {
        guard let userID = try? authenticatedUser.id else { return }
        jellyseerrService.clear(for: userID)
        serverURLString = ""
        username = ""
        password = ""
        connectionState = .idle
    }
}
