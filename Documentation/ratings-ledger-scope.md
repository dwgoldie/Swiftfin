# Ratings via the Arcade Ledger — scope

Fork-only, same reasoning as the Jellyseerr work: this integrates a third-party
service (our own, but still not Jellyfin) and upstream has consistently refused
that class of change.

Goal from the ask: rate things on a real scale instead of heart / no-heart, and
have that rating outlive the file it was attached to.

## Why this cannot go through Jellyfin

Jellyfin's `UserData` table *looks* like it supports this — it has `IsFavorite`,
`Likes` and `Rating` columns. It does not. Tested against our own server
(10.11.11, native, 2026-08-22):

    POST /Users/{user}/Items/{item}/Rating?likes=true   -> 200 OK
    POST /Users/{user}/Items/{item}/Rating?rating=8     -> 200 OK
    GET  /Users/{user}/Items/{item}  ->  Likes: null, Rating: null

Both writes are accepted and silently discarded. `Likes` and `Rating` are
vestigial Emby leftovers with no server-side implementation. Across the whole
library: 62 items played, 0 favourited, 0 rated.

This is the load-bearing fact for the design. A rating control that POSTs to
Jellyfin would look like it worked and lose every score. There is also no
Jellyfin plugin that adds a rating scale — the catalogue has Playback
Reporting (history only), Trakt and Simkl (both require third-party accounts).

## The backend already exists

`arcade-ingest` — the Arcade Ledger, running at `d/mediastack/arcade-ingest`,
FastAPI, already has the endpoint:

    POST /rate
    {
      "actor":  "goldie",          # required
      "media":  "film",            # film|tv|game|music|book|podcast
      "ref":    "tmdb:12345",      # identity key
      "rating": 8                  # required for /rate, float
    }

`/rate` sets `kind="rate"`, runs the same dedup window as every other event,
and appends to `{LEDGER_ROOT}/{actor}/{media}.jsonl`. Optional fields on the
shared `Event` model that are worth populating: `tags`, `household`, `extra`.

It is already collecting, so this is additive rather than new infrastructure:

    david/music.jsonl   84,910 listened   (spotify: refs, back to 2012)
    goldie/film.jsonl      436 progress/started/abandoned  (jellyfin: refs)
    goldie/tv.jsonl        189 progress/started/abandoned  (jellyfin: refs)
    ratings                    0          <- /rate has never been called

## Three things to settle before writing Swift

**1. `ref` must become durable.** Every film/tv event currently uses
`ref="jellyfin:{ItemId}"`, which is scoped to the library item. Delete the film
and the ref points at nothing — the exact amnesia this feature exists to fix,
just relocated from Jellyfin into the ledger. The `/jellyfin` webhook handler
already captures `Provider_tmdb`, `Provider_imdb` and `Provider_tvdb` into
`extra`, so the durable identity is being collected but not used as the key.

Ratings should key on `tmdb:` (falling back to `imdb:`), and carry the Jellyfin
item id in `extra` rather than the other way round. Worth considering a
migration pass over the existing 625 film/tv events at the same time.

**2. The ledger is not reachable from an Apple TV.** compose binds it
`127.0.0.1:8877:8765` — localhost only, deliberately. Swiftfin on tvOS needs a
LAN-reachable address. Either rebind, or front it with something that can
authenticate. Do not simply expose it: the ledger is a complete personal
viewing and listening history and currently has no auth at all.

**3. Actor identity.** The ledger has two actors: `david` (Spotify) and
`goldie` (Jellyfin). Ratings from Swiftfin arrive as the Jellyfin username, so
they will land under `goldie` while the music history sits under `david`.
Decide whether these should converge before writing ratings, because merging
JSONL after the fact is worse than choosing now.

## Files, mirroring the Jellyseerr layout

    Shared/API/Ledger/LedgerClient.swift            thin client, mirrors JellyseerrClient
    Shared/API/Ledger/LedgerModels.swift            Event, RateRequest, response
    Shared/Services/LedgerService.swift             Defaults-backed config + client factory
    Shared/ViewModels/LedgerSettingsViewModel.swift settings pane
    Shared/Components/RatingControl.swift           the 1-10 control itself
    Shared/Strings/Strings.swift                    + Translations/en.lproj/Localizable.strings
    Shared/Coordinators/.../NavigationRoute+Settings.swift   settings entry

Config follows `JellyseerrService` exactly — `Defaults.Keys` in the
`.currentUserSuite`:

    static let ledgerServerURL: Key<URL?> = .init("ledgerServerURL", suite: .currentUserSuite)

The client is simpler than Jellyseerr's: no session cookie, no login dance, one
POST. Most of the work is UI placement, not transport.

## Phases

1. Ledger settings pane — server URL, health probe against `/healthz`, same
   shape as Jellyseerr connect.
2. `RatingControl` on item detail, writing `/rate`. Read-back comes from
   `/stats` or a new `GET /rating/{ref}` — the ledger has no read-by-ref
   endpoint yet, so one is needed to show an existing score.
3. Surface ratings in lists — sort/filter by your own score.
4. Optional: reconcile with `IsFavorite` so the heart stays meaningful rather
   than becoming a second, competing signal.

## Constraint

Swiftfin is SwiftUI targeting tvOS/iOS. It cannot be built on goldie-x99
(Windows). Code can be written and committed there; compiling and deploying to
the Apple TV needs a Mac with Xcode.

## Before starting

`dwgoldie/Swiftfin` is 34 ahead / 25 behind `jellyfin/Swiftfin`. The
hero-banner work already hit "Backport API drift" once. Rebase before adding a
fifth feature branch.
