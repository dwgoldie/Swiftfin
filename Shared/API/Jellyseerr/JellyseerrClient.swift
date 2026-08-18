//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation

/// Thin client for the subset of the Jellyseerr API this fork uses.
///
/// Jellyseerr authenticates with a `connect.sid` session cookie, not a
/// bearer token -- the cookie must be dropped before a fresh login or a
/// stale one 401s the new credentials before the response body is read.
final class JellyseerrClient {

    var baseURL: URL
    var sessionCookie: String?

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL, sessionCookie: String? = nil) {
        self.baseURL = baseURL
        self.sessionCookie = sessionCookie
        session = URLSession(configuration: .ephemeral)

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        encoder = JSONEncoder()
    }

    func fetchStatus() async throws -> JellyseerrStatus {
        try await get("/api/v1/status", requiresAuth: false)
    }

    func loginWithJellyfin(username: String, password: String) async throws -> JellyseerrUser {
        sessionCookie = nil

        let body = JellyseerrJellyfinAuthBody(username: username, password: password)
        let (data, response) = try await send(
            path: "/api/v1/auth/jellyfin",
            method: "POST",
            body: body,
            requiresAuth: false
        )

        guard let cookie = extractSessionCookie(from: response) else {
            throw JellyseerrError.unauthorized
        }
        sessionCookie = cookie

        return try decode(JellyseerrUser.self, from: data)
    }

    func currentUser() async throws -> JellyseerrUser {
        try await get("/api/v1/auth/me", requiresAuth: true)
    }

    func logout() async throws {
        _ = try await send(path: "/api/v1/auth/logout", method: "POST", body: String?.none, requiresAuth: true)
        sessionCookie = nil
    }

    // MARK: - Private

    private func get<T: Decodable>(_ path: String, requiresAuth: Bool) async throws -> T {
        let (data, _) = try await send(path: path, method: "GET", body: String?.none, requiresAuth: requiresAuth)
        return try decode(T.self, from: data)
    }

    private func send(
        path: String,
        method: String,
        body: (some Encodable)?,
        requiresAuth: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw JellyseerrError.invalidURL
        }
        components.path = (components.path + path).replacingOccurrences(of: "//", with: "/")
        guard let url = components.url else {
            throw JellyseerrError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if requiresAuth, let sessionCookie {
            request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyseerrError.unexpectedResponse(statusCode: -1)
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw JellyseerrError.unauthorized
            }
            throw JellyseerrError.unexpectedResponse(statusCode: httpResponse.statusCode)
        }

        return (data, httpResponse)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw JellyseerrError.decoding(error)
        }
    }

    private func extractSessionCookie(from response: HTTPURLResponse) -> String? {
        guard let headerFields = response.allHeaderFields as? [String: String] else { return nil }

        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: baseURL)
        guard let sessionCookie = cookies.first(where: { $0.name == "connect.sid" }) else {
            return nil
        }
        return "\(sessionCookie.name)=\(sessionCookie.value)"
    }
}
