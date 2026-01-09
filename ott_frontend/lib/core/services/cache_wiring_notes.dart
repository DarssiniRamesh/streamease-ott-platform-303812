/*
Notes for step-01 analysis: cache-first wiring status and missing pieces.

This file is intentionally documentation-only to keep code changes minimal.

Current wiring (verified):
- SharedPreferences-backed cache:
  - `SimpleCache` is created in `AppBootstrap.bootstrap()`
  - Injected into:
    - `HomeController` (home feed cache-first with TTL + stale fallback)
    - `AppSearchController` (recent searches string list)
    - `SettingsController` (quality + subtitles settings)
- SQLite (sqflite) database:
  - `AppDatabase` is created and opened in `AppBootstrap.bootstrap()`
  - Injected into:
    - `DownloadController` (downloads + download_queue tables)

Local caching gaps / stubs that may block full “local-first” feature flows:
- Content caching beyond home feed:
  - `ContentDetailsScreen` calls `ContentRepository.getById()` directly.
  - There is no cache layer for `getById` results (could be added via `SimpleCache`
    or via a local SQLite content table).
- Search result caching:
  - Search caches only recent queries; results are not cached.
- Watch history / continue watching:
  - `watch_history` table exists in `AppDatabase` but is not used anywhere yet.
  - No controller/repository methods to upsert watch position.
- Downloads vs actual offline media:
  - `FakeDownloadEngine` simulates progress only; no file persistence.
  - This is expected per requirements: keep FakeContentRepository as source,
    do not introduce backend.

No backend is used; `FakeContentRepository` remains the single source for content data.
*/
