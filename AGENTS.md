# For agents

Tsundoku: a private, offline-first catalogue of the books you own, built so you never buy one twice.
The plan is in [docs/roadmap.md](docs/roadmap.md); the app is in `app/` (Flutter).

## Build and test
App commands run in `app/` (Flutter 3.50 stable, Dart 3.14). Server: `cd server; dart test`, run with
`dart run bin/tsundoku_server.dart serve`. Shared package: `cd packages/tsundoku_protocol; dart test`.
- Test: `flutter test` (core logic with an in-memory database and fake HTTP; a widget smoke test).
- Analyse: `flutter analyze` (must be clean).
- Regenerate the database code after changing tables: `dart run build_runner build`.
- Android APK: `flutter build apk --release --split-per-abi --target-platform android-arm64`
  (compileSdk 37; needs the Android SDK's `platforms/android-37.0`).
- Web: `flutter build web` (drift's `web/sqlite3.wasm` and `web/drift_worker.js` must match the drift version).

## Layout
- `app/lib/src/books/`: models, ISBN helpers, genres, `LibraryRepository` (every read and write).
- `app/lib/src/db/`: drift tables (books, identifiers, genres, change log).
- `app/lib/src/sources/`: `BookSource` interface and Open Library. New sources go here.
- `app/lib/src/covers/`: covers saved on the device (own photos are never cleared).
- `app/lib/src/theme/`, `settings/`: the four accents, light/dark, the appearance setting.
- `app/lib/src/ui/`: screens.
- `server/`: the sync server (Dart, shelf, SQLite). It must never be able to read a library.
- `packages/tsundoku_protocol/`: keys, sealing and authenticator codes shared by app and server.
- `docs/`: the roadmap, decisions log and design notes (`phase3-design.md` for accounts and sync).

## Conventions
- The roadmap's "Product rules" are fixed by the product owner. Technical choices can change if
  those rules still hold; record every change in the roadmap's decisions log with the date.
- Don't add anything the roadmap lists under "Never in scope".
- One branch per change. Run the tests that cover what you touched.
- Test data and examples use made-up names: alice, bob, `example.com`, `192.0.2.1`.
  Never real usernames, hosts, IP addresses or local paths.
- Never commit secrets, `.env` or local config; `.gitignore` lists what stays out.
- Every write to the library goes through `LibraryRepository`, so the change log stays complete for sync.
- Gotchas: `kotlin.incremental=false` in `android/gradle.properties` (Kotlin's cache breaks across
  drives on Windows); widget tests need `closeStreamsSynchronously` and real-time pumps (see `test/app_test.dart`).
- Android-only native packages (like `saf_stream`, which uses FFI) must be imported only through
  `if (dart.library.io)` conditional exports with a stub, or the web build breaks (see `app/lib/src/backup/`).
- Keep `KeyboardInsetsGuard` (`app/lib/src/ui/keyboard_guard.dart`) around the app: it works around a
  Flutter engine bug that leaves a blank keyboard-sized area after switching apps with the keyboard open.
- No AI attribution in commits or pull requests.
- User-facing text is plain, friendly English (Australian/British spelling: "colour",
  "catalogue"). No jargon in the app.
