# Jellyseerr integration — scope

Fork-only. Upstream jellyfin/Swiftfin has explicitly refused this twice
(#1675, #1895 — "we are unable to provide integration with 3rd party
tools"), so this lives on `dwgoldie/Swiftfin` only, never as an upstream PR.

Goal from the ask: search the complete Jellyseerr catalog (not just what's
already in the Jellyfin library) and request from inside Swiftfin.

## Reference implementation

`reference/source/player/streamyfin` (pinned `137a8b8`) has a mature,
working Jellyseerr integration to build against — treat it as an oracle for
*behaviour and API shape*, not for code to port directly (it's Expo/React
Native; Swiftfin is native SwiftUI with a completely different service
architecture). Relevant files there:

- `hooks/useJellyseerr.ts` — client/session lifecycle
- `utils/serverUrl/probes/jellyseerr.ts` — server discovery/health probe
- `components/jellyseerr/discover/*` — the TMDB-backed browse UI
  (`Discover.tsx`, `MovieTvSlide.tsx`, `GenreSlide.tsx`,
  `RecentRequestsSlide.tsx`, `CompanySlide.tsx`)
- `components/jellyseerr/RequestModal.tsx` / `tv/TVRequestModal.tsx` —
  the request flow, iOS and tvOS variants
- `components/settings/Jellyseerr.tsx` — server config UI
- `components/common/JellyseerrItemRouter.tsx` — routes a search/discover
  hit to either "already in your library, play it" or "not in library,
  request it" — this is the one genuinely load-bearing piece of logic to
  carry over faithfully

Their "Discover" is Jellyseerr/TMDB trending+popular, request buttons
attached — distinct from the hero-banner discovery work just landed on
`main`, which is library-content only. These are complementary, not
competing: hero banner surfaces what's already yours, Jellyseerr discover
surfaces what you could add.

## Jellyseerr's own API

Jellyseerr is a fork of Overseerr; same REST API, OpenAPI-documented,
session-cookie or API-key auth. No Swift client exists for it (checked —
nothing in Swiftfin's Package.resolved or a search for a Jellyseerr Swift
SDK). Two paths:
1. Hand-write a thin `Get`-based client (Swiftfin already depends on
   `kean/Get` for `JellyfinClient` itself — same pattern, small surface:
   `/api/v1/search`, `/api/v1/discover/movies`, `/api/v1/discover/tv`,
   `/api/v1/request`, `/api/v1/auth/local` or `/api/v1/auth/jellyfin`).
2. Generate from Jellyseerr's OpenAPI spec the way `jellyfin-sdk-swift` is
   generated. Cleaner long-term, more upfront work, and ties us to
   regenerating on their spec changes. Recommend (1) first — the surface
   we need is ~5 endpoints, hand-writing is genuinely less work than
   standing up a codegen pipeline for a fork-only feature.

## Where it attaches in Swiftfin's architecture

- **Config storage**: not a new CoreStore/`V2ServerModel` field — that's a
  schema migration for a fork-only feature, too heavy. Use the existing
  `SwiftfinDefaults` typed-key pattern (`Shared/Services/SwiftfinDefaults.swift`,
  `UserKey`/`AppKey` factories, backed by `Defaults`) keyed per signed-in
  user the same way other per-user settings already are. API key goes in
  `Shared/Services/Keychain.swift`, same as other secrets — never in
  `Defaults`/CoreStore in plaintext.
- **Network client**: a new `JellyseerrClient`, constructed lazily the same
  way `UserSession.swift:18` builds `JellyfinClient` — but scoped
  separately since a user may not have Jellyseerr configured at all (the
  client should be `Optional`, nil when unconfigured, and every call site
  that touches it treats absence as "feature not available," not an error).
- **Discovery surface**: a new `ContentGroupProvider` conforming type,
  same shape as `DefaultContentGroupProvider`/`ItemTypeContentGroupProvider`
  in `Shared/ViewModels/ContentGroupViewModel/` — this is exactly the
  extension point `LePips` pointed at in the #2135 thread, and it's the
  same system the hero banner now uses. A `JellyseerrContentGroupProvider`
  surfacing trending/popular rows is the natural home, gated off entirely
  when no Jellyseerr client is configured.
- **Search integration**: `Shared/Views/SearchView.swift` +
  `Shared/ViewModels/SearchViewModel.swift` currently search the Jellyfin
  library only. The ask ("search the complete seer list") means: when a
  Jellyseerr client is configured, fan the same query out to it in
  parallel and merge results, with a status badge (`JellyseerrStatusIcon`
  in Streamyfin's model — "already available," "requested," "request")
  distinguishing library hits from catalog-only hits. This is the one
  piece of real UI/UX design work, not just plumbing — needs a mockup
  pass before writing view code.
- **Request flow**: a `NavigationRoute` case
  (`Shared/Coordinators/Navigation/NavigationRoute/`, same pattern as
  `itemPlaylists(item:)`) routing to a new `JellyseerrRequestView`, iOS
  and tvOS each get their own per Swiftfin's existing split (see
  `ItemPlaylistView.swift` for the iOS/tvOS-shared-viewmodel pattern from
  the playlist work just merged).
- **Settings**: a new entry under `Shared/Views/SettingsView/` alongside
  `CustomizeSettingsView.swift` et al. — server URL, auth, connection test.

## Suggested build order

1. `JellyseerrClient` + Keychain/Defaults config storage + settings screen
   with a connection-test button. Land this alone first — it's inert
   without the next two but fully testable on its own (can literally
   verify a saved config round-trips and pings the real server).
2. `JellyseerrContentGroupProvider` for a Home discover row — smallest
   surface that produces a visible result, reuses the just-landed
   `ContentGroup` machinery directly.
3. Search fan-out + status badges + request flow — the real feature,
   builds on both prior pieces.

Not scoped here: request approval/management UI (Jellyseerr has its own
admin web UI for that; Streamyfin's `RecentRequestsSlide.tsx` only shows
*your own* pending requests, which is a much smaller ask if wanted later).
