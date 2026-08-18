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
import KeychainSwift

extension Container {

    var jellyseerrService: Factory<JellyseerrService> {
        self { JellyseerrService() }.singleton
    }
}

/// Owns Jellyseerr configuration for the current Jellyfin user and hands out
/// a configured `JellyseerrClient`.
///
/// Server URL lives in `Defaults` (per-user suite); username is remembered
/// alongside it so the settings screen can show who's connected. Password
/// is never persisted -- only the resulting session cookie is, since that's
/// what Jellyseerr itself treats as the credential after login.
final class JellyseerrService {

    @Injected(\.keychainService)
    private var keychain

    private(set) var client: JellyseerrClient?

    var isConfigured: Bool {
        Defaults[.jellyseerrServerURL] != nil
    }

    func configuredClient(for userID: String) -> JellyseerrClient? {
        guard let url = Defaults[.jellyseerrServerURL] else { return nil }

        let cookie = keychain.get("\(userID)-jellyseerrCookie")
        let client = JellyseerrClient(baseURL: url, sessionCookie: cookie)
        self.client = client
        return client
    }

    func save(serverURL: URL, username: String) {
        Defaults[.jellyseerrServerURL] = serverURL
        Defaults[.jellyseerrUsername] = username
    }

    func persistSession(cookie: String, for userID: String) {
        keychain.set(cookie, forKey: "\(userID)-jellyseerrCookie")
    }

    func clear(for userID: String) {
        Defaults[.jellyseerrServerURL] = nil
        Defaults[.jellyseerrUsername] = nil
        keychain.delete("\(userID)-jellyseerrCookie")
        client = nil
    }
}

extension Defaults.Keys {

    static let jellyseerrServerURL: Key<URL?> = .init("jellyseerrServerURL", suite: .currentUserSuite)
    static let jellyseerrUsername: Key<String?> = .init("jellyseerrUsername", suite: .currentUserSuite)
}
