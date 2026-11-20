# Tsundoku: plan and roadmap

Updated 2026-11-14. "Tsundoku" is the working name; the final name and branding are still open.

This document turns the product owner's brief into a build plan. Two kinds of decision live here:

- **Product rules** (how the app works and feels for the person using it). These came from the
  product owner and only she changes them.
- **Technical choices** (how it's built). These can change, as long as every product rule still
  holds. Each one below is marked *Recommended* until it's approved, then moved to the
  [decisions log](#decisions-log).

## 1. What the app is for

One job, done well: **"Do I already own this book?"**, answered in seconds, in a shop or while
browsing online, with or without signal. Everything else (ratings, notes, reading status,
backups) supports that job without getting in its way.

## 2. Product rules

These are settled. A technical choice that breaks one of them is the wrong choice.

### The experience
- Android phone first. An iPhone version may come later but isn't a priority. Desktop use
  (including a webcam for scanning) is wanted where possible.
- A native-feeling app on the phone; a web app (PWA) only if native isn't workable.
- Calm and minimal: clean layouts, a neutral palette with one soft accent colour, light and dark modes.
- Books she is **Reading** are pinned to the top in the default order (Recently added) and in search
  results, most recently touched first. In the other sorts (Title, Author, Rating) Reading is the
  tie-breaker: sorting by author, her Reading Stephen King comes first among the Stephen Kings.
- Filters: a sort menu and a Filters button holding, in this order, format (Physical, Kindle),
  reading status (TBR, Reading, Read, DNF), then rating, genre and author. The button shows how many
  are chosen. No chips under the search bar (her choice, 2026-11-15; built in 0.5.3).
  Searching always covers the whole library, whatever the filters, so the owned check never misses a book.
- In the cover grid, each cover shows a small bubble with its reading status (when one is set) and a
  small Kindle or Physical icon. Each status has its own colour and icon beside its word, so they're
  told apart at a glance: TBR slate blue with a bookmark, Reading amber with an open book, Read green
  with a tick, DNF rose with a "no" sign (her choice, 2026-11-21; the same in every accent).
- Settings has a simple appearance picker: one of **five accent colours** (Sage, Dusty blue, Blush,
  Heather, Sunflower) and **Light or Dark**. Nothing more (no custom colours, fonts or themes). Book covers are the
  star, in a grid. No bookshelf graphics, no heavy animation, nothing that looks like social media.
- Search is prominent and easy to reach, and results update as you type.
- An owned book shows a clear **ALREADY OWNED** label in the results, with its cover and details.
  No pop-up or separate warning screen.
- It works offline: search, book details, ratings, notes, reading status, the owned check and
  cached covers all work without a connection.

### Books
- Formats: Physical or Kindle. No audiobooks.
- "Owned" means owning the work: a paperback counts as owned when you look up the Kindle
  edition, and the other way round. One copy per book; no multiple-copy tracking.
- Add a book four ways: scan the barcode, type the ISBN, search title and/or author and pick the
  right result, or enter it by hand. One book at a time; no bulk import.
- Book information comes from Open Library only. If a scanned or typed ISBN isn't there, the app
  suggests searching by title or author first, since another edition often is; if the search finds
  nothing either, you type the details. An edition added that way keeps the ISBN you scanned, so
  scanning that copy again shows you own it (her choice, 2026-11-21).
  A book can always be saved, even with no ISBN (common for Kindle), no cover or missing details.
- Scanning shows the match and asks you to confirm before adding. If the camera isn't available
  or scanning fails, you can type the ISBN.
- Filled in from Open Library where possible: title, authors, ISBN, cover, publisher, publication
  date, edition/format, genres.
- Yours to set: format, date purchased, date finished (optional; shown once a book is Read as
  "Finished reading", or DNF as "Stopped reading"; kept if the status changes back), rating (0 to 5 stars), notes, reading status, genres, and
  your own cover photo if the one found is missing or wrong.
- Reading status is optional and blank by default: TBR, Reading, Read or DNF. Nothing else, and
  it's never set automatically.
- Filter by author, genre, format, reading status and rating. Sort by title, author, date added
  and rating.
- Matching: ISBN first; otherwise title and author (and edition details). Possible matches are
  shown with covers for you to confirm. Similar titles by different authors must not match.
- Edit anything. Delete permanently (no recycle bin).

### Your data
- Your library is private. Nobody else can see it, **including whoever runs the server**. Admins
  can see how many accounts there are, suspend or delete accounts, watch the app's health and run
  backups, but never see titles, authors, ratings, notes or anything else in a library. This has
  to be enforced by how the data is stored, not by hiding it in the admin screens, and tested.
- Changes made offline sync when you're back online, almost immediately, without you doing
  anything. If sync keeps failing, you're told, and you can see what hasn't synced yet.
- Your changes are never silently lost or overwritten. If the same thing was changed differently
  on two devices and there's no safe answer, the app asks you which to keep.
- Cached covers can be cleared to save space without losing any books; they download again later.
- Automatic backups, daily by default, kept 7 days by default; both can be changed. You can
  restore from a backup. Old backups expire on their own.
- Export your whole library to a spreadsheet (Excel-compatible), with everything in it. Export
  only; no import.
- Accounts: email address (as the login name) and password. Password reset with a 6-digit code
  from an authenticator app, no email needed. A new phone gets the library back with a
  fingerprint tap (a passkey saved in her Google account); nothing to write down. Email is
  optional: a server works without sending mail, and if its owner sets mail up, address
  verification switches on. Lock after 1 day without use (opens with fingerprint, face or phone PIN), full log out
  only after a long time unused (30 days proposed). No "sign in with Google".
- Delete your account and library from inside the app, after a clear warning. Copies in backups
  expire with the backup retention, and the app says so plainly.
- Messages only when they matter: security alerts and persistent sync problems, shown inside the
  app (and by email only on servers that have mail set up). No reminders, nudges, challenges or promotions.
- **Sync is optional and for people who choose it.** The phone app on its own, with its automatic
  backups and export, is the whole product for most people. Accounts and the sync server are a more
  advanced extra for anyone who wants several devices or a self-hosted or cloud copy. Nothing asks,
  nudges or requires anyone to sign up; the app never depends on a server.
- Open source. Anyone can download, run and modify it: offline only on their own device, synced
  through their own server (for a family, or one person hosting friends), or (later) a public
  hosted service. Each user on a server has their own private library.
- Free: no subscriptions, premium features or ads. An optional Ko-fi link may appear; it never
  unlocks anything.

### Never in scope
Social features (friends, followers, feeds, public profiles), community reviews or
recommendations, reading challenges or statistics, audiobooks, custom shelves or collections,
purchase price or place, bulk import, multiple copies, Google Books or any other book database,
Amazon integration, browser extensions, retailer detection, paid tiers, advertising.

## 3. Technical approach (recommended, awaiting approval)

### 3.1 The big idea: the phone is the library; the server only keeps encrypted copies
The cleanest way to meet "admins can't read libraries", "works offline" and "nothing is lost" all
at once:

- **Local-first.** Each device keeps the full library in a local database (SQLite) and works
  against it directly. Search and the owned check never wait for the network.
- **End-to-end encryption for sync and backups.** Before anything leaves the device it's
  encrypted with a key only the user's devices hold. The server stores and passes along locked
  boxes it can't open. Admin privacy then isn't a permission setting that could be got around; the
  server simply has nothing readable. It's also easy to test: dump the server's database and check
  that no title, author or note appears in it.
- **Deleting an account** removes it and everything it synced at once. The server's own backups
  keep its locked copy until they age out (14 days by default); like everything on the server,
  nobody can open it without her password, passkey or recovery code. (Corrected 2026-11-15: a
  backup holds the same locked key as the live server, so deleting can't reach into old backups.)

If the server can't read a library, it can't rescue one either, so recovery is split in two
(decided 2026-11-14):
- **Getting into the account** (forgotten password): a 6-digit code from an authenticator app
  (TOTP, set up at sign-up). This proves who she is; it can't unlock the library, because the server
  knows the authenticator's secret and so would anyone running it. After a reset, any device that
  still has the library re-encrypts and re-uploads it.
- **Unlocking the library on a new phone** (every device lost): a passkey saved in her Google
  account. The passkey's PRF extension gives the app a secret that only her fingerprint can
  release, which unwraps the library key. Google syncs the passkey end-to-end encrypted, so it
  arrives on a new phone by itself.
- **One project domain for every user.** The server never checks the passkey; the app only uses
  its PRF secret on the device. So the passkey belongs to one fixed project domain that hosts
  nothing but `/.well-known/assetlinks.json` (Android's proof that the domain trusts the app's
  signing key), whichever sync server a person uses. A fork signed with its own key needs its own
  domain. Decided 2026-11-14: `mysterygodzilla.github.io` (GitHub Pages, repo
  MysteryGodzilla/MysteryGodzilla.github.io), free. Its `assetlinks.json` lists the spike's debug key
  for now; the real app's release key is added when it exists.
- **Proven on her phone 2026-11-14:** a passkey saved in her Google account (unlocked with her
  fingerprint) gave the same PRF secret before and after uninstalling and reinstalling the app.
- **Fallback, for other people's phones:** if a phone or password manager doesn't return a PRF
  secret, the app shows a one-time recovery code at sign-up instead (her original Q2 answer). The local backups and
  spreadsheet export stay as further safety nets.

### 3.2 App platform
**Decided 2026-11-14: Flutter (Dart)**, with the server in Dart too, so the whole project is one
language. One codebase gives a native Android app first, an iPhone app later without a rewrite, and
a web build (or a Windows app) for desktop. Why Flutter over Expo:
[stack-comparison.md](stack-comparison.md).
- Barcode scanning: `mobile_scanner`, with ML Kit on Android (fast, works in poor light) and ZXing
  in desktop browsers, not a single browser's built-in detector.
- Local database: SQLite through `drift`, on the phone and in the browser (WebAssembly, stored in
  the browser's private file system). Covers cached as files.
- Look: Material 3 themed from one soft accent colour, light and dark.
- App lock: `local_auth` (fingerprint, face or phone PIN).
- To prove in the Phase 0 spike: scanning on a real Android phone and a laptop webcam, offline
  search on both, and passkey PRF on her phone. All proven on her phone 2026-11-14 (the `passkeys`
  package worked), so the Expo fallback isn't needed.

### 3.3 Sync
- Every change is recorded on the device as a small event (field X of book Y set to Z, at time T,
  on device D). Devices exchange encrypted events through the server.
- Conflicts are handled field by field. Different fields changed on two devices simply merge (a
  rating on the phone and a note on the laptop both survive). The same field changed differently on
  both since they last synced is a real conflict: both values are kept and the app asks. A deleted
  book versus an edit on another device also asks.
- Sync runs on every change when online, on app open, and every few minutes as a fallback. Failures
  retry with back-off; after a persistent failure (roughly a day) the app shows a gentle notice and
  a list of unsynced changes.

### 3.4 Server (optional, self-hostable)
- A small Dart server (`shelf`) with SQLite (PostgreSQL optional for big installations), shipped as one Docker image plus a plain install guide. It handles accounts,
  storing encrypted events, backups and admin counts.
- Passwords are never stored in a form the server can use to read data: login and encryption use
  separate keys derived from the password on the device (an OPAQUE- or SRP-style login, or Argon2id
  hashing on the server for the login key). The library key is wrapped twice: once by the password
  key, once by the passkey's PRF secret.
- Password reset by TOTP (RFC 6238, works with any authenticator app). Account checks are
  rate-limited.
- Email is optional. With no SMTP settings the server sends no mail and alerts stay in the app. If
  the owner adds SMTP settings, address and email-change verification switch on. The public hosted
  service would need a mail provider (cost question, deferred).
- "Sync through Google Drive or Dropbox" (from the brief) can come later, using the same encrypted
  events written to a folder in the user's own cloud drive, for people who want sync without
  running a server.

### 3.5 Book information
- Open Library's API for ISBN lookup and title/author search; its Covers API for images.
- The owned check across formats uses Open Library's **work** record: every edition (paperback,
  hardback, Kindle) of a book belongs to one work, so owning any edition marks the work as owned.
  Books entered by hand fall back to normalised title plus author, with confirmation.
- Be a polite client: identify the app in requests, cache results, and respect Open Library's
  published rate limits. Checked 2026-11-14: [open-library.md](open-library.md).
- **Built for more sources later (decided 2026-11-14).** Open Library is the only source for now,
  but lookups go through one small interface so another source can be added without touching the
  rest of the app:
  - A `BookSource` has an id and name, `lookupIsbn(isbn)`, `search(title, author)`, a cover
    reference, its own rate limit, and whether it needs a key. Open Library is the first one.
  - Every source returns the same `Candidate` shape: title, authors, ISBN, publisher, date,
    subjects, a cover reference, and its **identifiers** (for example `openlibrary:work`,
    `openlibrary:edition`, `isbn13`; later `trove:work` or `inventaire:wd`).
  - A book keeps all of its identifiers in a separate table (book, scheme, value), not one
    "work key" column. The owned check matches on any shared identifier first, then on normalised
    title plus author, so books from different sources still match.
  - Sources run in a set order: an ISBN tries each enabled source until one knows it; then manual
    entry. Today the order is just Open Library.
  - A source's key (Trove's, say) lives in the app's settings or the server's config, never in the
    repo. Adding any source is the product owner's call (see Q7).

### 3.6 Backups and export
- On each device: a daily encrypted backup file, kept for the chosen number of days, which Android
  can also include in its own phone backup.
- On a server: daily snapshots of the encrypted store, expiring by the retention setting.
- Export writes an `.xlsx` file (opens in Excel, Google Sheets, LibreOffice) with every field.

### 3.7 Licence
**Decided 2026-11-14: MIT** (see `LICENSE`). Anyone may use, modify and redistribute the code,
including in their own hosted services, as long as the copyright notice stays.

## 4. Roadmap

Each phase ends with something the product owner can hold and try. Nothing moves to the next phase
until she's happy with the current one.

### Phase 0: decide and prove (before any real code)
- Approve the technical choices in section 3 (Mystery; done: MIT licence, Flutter + Dart) and answer the questions in section 5 (the
  product owner).
- Spike, thrown away afterwards (built 2026-11-14, kept outside the repo): a Flutter app on her Android phone that scans a barcode, looks it up
  on Open Library, saves it to SQLite and finds it offline. The same on a laptop webcam.
  Tried on her phone 2026-11-14: scanning, search and typed ISBNs all work. Two Australian books
  weren't found, which led to the [book sources research](book-sources.md): Open Library knew only
  17 of 48 recent Australian books. Status 2026-11-14: automated tests pass (owned check across editions, local search, live Open
  Library lookups); the Android APK and web builds work; in a desktop browser the database opens in
  persistent OPFS storage. **Still to try:** scanning on her real phone and a laptop webcam.
- Passkey test on her phone (domain ready 2026-11-14): create a passkey in her Google account from the Flutter app, read its PRF
  secret, and get the same secret back after reinstalling the app. **Passed 2026-11-14**: same code
  with her fingerprint, before and after a reinstall, no errors.
- ~~Check Open Library's limits, terms and Kindle coverage~~ Done 2026-11-14:
  [open-library.md](open-library.md). Kindle editions are rarely listed, so Kindle books are added by
  title/author search and matched by work.
- Mock-ups of the library grid and search in two or three soft accent colours, light and dark, for
  the product owner to pick from. Made 2026-11-14 in three accents, then a fourth (Heather) and a
  Settings screen with the picker were added the same day. All four ship; she chooses in Settings.
  The palette (every text pairing at least 4.5:1):

  | Accent | Light mode accent / tint | Dark mode accent / tint |
  |---|---|---|
  | Sage | `#4F6F58` / `#E3ECE5` | `#9DBFA5` / `#22302A` |
  | Dusty blue | `#4E6A85` / `#E2E9F0` | `#9DB5CC` / `#1F2A35` |
  | Blush | `#9A5B66` / `#F4E4E6` | `#E0AEB6` / `#3A262A` |
  | Heather | `#6E5A86` / `#EAE4F0` | `#B9A7D0` / `#2C2536` |
  | Sunflower | `#EDB40F` / `#FBF0CC` (text `#8A6100`) | `#F5C842` / `#3A3015` |

  Neutrals: light `#F7F6F3` background, `#1C1C1A` text; dark `#141414` background, `#EDEDEA` text.
- **Done when:** the stack is in the decisions log, and the spike worked on her phone.
- **Phase 0 done 2026-11-14.** Not tried: scanning with a laptop webcam (it belongs to Phase 4).

### Phase 1: the owned check, on her phone (offline only)
The core job, with no accounts and no server.
- Add books: scan, ISBN, title/author search with covers, manual entry, own cover photo.
- The library grid with covers; book details; edit; delete.
- Search as you type with the **ALREADY OWNED** label, across editions and formats.
- Format, purchase date, rating, notes, reading status, genres.
- Light and dark modes. Cover cache that can be cleared.
- **Done when:** she can catalogue real books and use it in a shop with flight mode on. Install by
  a direct APK (no app store needed yet).
- **First version built 2026-11-14** (in `app/`). Done:
  scan, typed ISBN, Open Library search and hand entry (each confirmed before adding); the cover
  grid; offline search with ALREADY OWNED across editions and formats; book details with reading
  status, rating, purchase date, genres (suggested from Open Library), notes, her own cover photo
  and permanent delete; Settings with the four accents and Light/Dark; saved covers that can be
  cleared without losing her photos.
- **Her first try, 2026-11-14:** adding, searching, hand entry and notes all work on her phone. Her
  request, done in 0.1.1: the status bubble and Kindle/Physical icon on grid covers. Her next three,
  done in 0.1.2: a Sunflower accent, Reading pinned to the top, and a "Finished reading" date
  (the database upgrades in place; tested).
- **Phase 1 done 2026-11-14.** Tested in flight mode: scanning a book already in the library showed
  ALREADY OWNED, and scanning books not in it showed they weren't owned, all with no internet.
  0.1.3: the finished date only shows for Read or DNF; screens keep clear of Android's navigation
  buttons; when a lookup fails the app just says "Open Library can't be reached." The phone's own
  font is used (preferred over the mock-ups' Inter).

### Phase 2: organise and protect
- Filters (author, genre, format, status, rating) and sorting (title, author, date added, rating).
- Spreadsheet export.
- Automatic daily local backups with chosen frequency and retention; restore.
- **Done when:** she can lose her phone and get her library back from a backup.
- **Built 2026-11-14 (0.2.0)**, decisions in the log. Sort: Recently added, Title, Author (by surname),
  Rating. Spreadsheet export (`.xlsx`, every field) through Android's share sheet. Backups: a zip
  (`library.json` plus her own cover photos) saved automatically when one is due (daily or weekly) and
  something changed, to a folder she picks (Google Drive, say) or on the phone until she does; kept 7,
  14, 30 or 90 days, the newest always kept; "Back up now"; restore lists backups in the folder and on
  the phone and saves a safety copy first. Backups aren't encrypted yet (Phase 3, with accounts).
- **Tested on her phone 2026-11-14:** backing up to a phone folder and restoring both work; export,
  chips and sorting work. Found: **Google Drive and OneDrive can't be chosen as the backup folder.**
  Their Android apps let other apps save and open single files, but not use their folders, so
  automatic backups go to a folder on the phone. 0.2.1 adds **Save a copy to…** (a backup file to
  Google Drive or anywhere Android can save one), **Restore from a file…** (the way back on a new
  phone), and **Save to…** for the spreadsheet beside Share. Automatic copies off the phone come with
  Phase 3's sync. 0.2.2: on her phone Android's save dialog doesn't offer Drive or OneDrive either, so
  "Save a copy" offers **Share…** too ("Save to Drive", "Upload to OneDrive"); spreadsheet Save and
  Share both work. **2026-11-15: she likes the sorting and the filtering**; the chips under the
  search bar move into the Filters menu (format first, then status, then the rest): built in
  **0.5.3** the same day, ahead of the rest of Phase 3, since it's what she sees first.

### Phase 3: accounts and sync (self-hosted server)
- The server: accounts, authenticator set-up and password reset, passkey recovery (or the code
  fallback), change email (no email is ever sent: dropped 2026-11-15),
  app lock (fingerprint, face or PIN after 1 day), long-inactivity logout, delete account.
- End-to-end encrypted sync between devices; conflict questions; the unsynced-changes list.
- Server backups and restore; the admin view (counts, suspend, health) with no library access.
- An automated privacy test that proves the server holds nothing readable.
- **Done when:** her phone and a second device stay in step, including after offline edits.
- **Plan 2026-11-14:** design in [phase3-design.md](phase3-design.md) (Bitwarden-style keys,
  AES-256-GCM events, field-level merge). Built in three steps: **3a** server, accounts,
  authenticator, app lock; **3b** encrypted sync with conflict questions; **3c** passkey recovery,
  password reset, change email, server backups, command-line admin, install guide. Built and
  tested on one computer with simulated devices; where the server runs for real waits for the
  network review.
- **Step 3a built 2026-11-14 (app 0.3.0, server 0.1.0):** the shared protocol package (Argon2id,
  HKDF, AES-256-GCM, authenticator codes, checked against the RFC test vectors); the server
  (accounts, authenticator, sessions that end after 30 unused days, rate-limited sign-in, a privacy
  check of its database file); in the app, Settings › Sync to create an account or sign in, the
  authenticator setup (an "Add to authenticator app" link and the key to type), sign out, delete
  account, and the app lock (fingerprint, face or PIN after a day unused, when signed in). The app's
  tests run against the real server code in memory, with two simulated phones. Not on a phone yet:
  there's no server it can reach until the network review. Next: step 3b, sync.
- **Step 3b built 2026-11-15 (app 0.4.0, server 0.2.0):** encrypted sync for people who choose it.
  Each change is an event (field, value, hybrid logical clock, device), locked with the library key
  before it leaves the phone; the server keeps an ordered list it can't read, plus locked photo
  attachments. A sync pulls, then pushes, so the device that syncs second notices when the same field
  changed on both and asks her (only there); different fields simply merge; a deletion against an
  edit asks too, and "keep it" brings the book back. The first sync sends the whole library; a backup
  restore reaches other devices as ordinary changes. Syncs a few seconds after a change, on opening
  and every five minutes while open; Settings shows when it last synced, changes waiting (with a
  list), questions to decide, and a problem only after about a day. Tested with two simulated phones
  through the real server code, including a check that the server's database file holds no titles,
  authors, notes or genres. Schema 3 (sync tables) upgrades in place. Not on a phone yet (no
  reachable server). Next: step 3c.
- **Step 3c built 2026-11-15 (app 0.5.0, server 0.3.0):**
  - **Recovery:** after the authenticator setup the app offers a passkey saved in her Google
    account (her fingerprint opens the library on a new phone) or a recovery code (24 letters and
    numbers, shown once). Each locks a copy of the library key that the server keeps but can't
    open. Settings › Sync shows which is set up.
  - **Forgotten password** (Sign in › Forgot password?): email and an authenticator code, then the
    passkey or recovery code opens the library, then a new password. Other devices are signed out
    and sign in with the new one. With neither, she can start the synced copy again from the
    phone's books (the old locked copy is deleted, since nothing can open it).
  - **Change password** (an authenticator code instead of the old password, so it also works when
    the old one is forgotten) and **change email**, in Settings › Sync.
  - **Home servers:** an address typed without `http://` or `https://` tries https, then plain
    http. Plain http shows a warning (what's at risk, https recommended) that she must agree to. A
    server on a home-network address (like `10.0.0.20:8797` or `nas.local`) gives up quickly when
    it's out of reach, and the "sync hasn't worked" notice waits a week instead of a day. "Sync
    now" says so when it fails.
  - **Server:** daily backups kept 14 days and a `restore` command; admin commands (`stats`,
    `list`, `suspend`, `unsuspend`, `delete`, `backup`, `health`); on start-up it says who can
    connect and which addresses to type. A `Dockerfile` and `compose.yaml`, and the install guide,
    [sync-server.md](sync-server.md) (Docker or the program alone; home network with
    `--host 0.0.0.0`, Tailscale, or https with Caddy). Email sending isn't built: nothing needs it.
  - The project domain's `assetlinks.json` now lists the app itself (signed with the same debug
    key as the spike), so its passkeys can work.
  - Tested: 90 automated tests (protocol 11, server 24, app 55), including a new phone getting the
    library back with a recovery code or passkey, starting again, other devices re-syncing
    afterwards, a home server out of reach for a week, and the plain-http warning. The server
    program was built and its commands tried on Windows, and cross-compiled for Linux. The Docker
    image hasn't been built (no Docker on this computer).
  - **Tried on her phone 2026-11-15** against a server on this computer, over the USB cable only
    (`adb reverse`), with her real library: the plain-http warning (cancel, then agree), the
    authenticator (the link opened Microsoft Authenticator), a passkey (one fingerprint), a recovery
    code, the first upload (all 8 of her books arrived, her own photo included; the server's file
    held nothing readable), change password, change email,
    sign out, both forgotten-password routes (passkey, recovery code), "can't be reached" straight
    away with the cable out, and deleting the account (the server was left empty). Two-device sync on
    real phones still waits for a reachable server.
  - **0.5.1** (from that test): the server address is remembered after signing out (for signing in
    and for a forgotten password), and a password reset goes back to Settings instead of an empty
    sign-in form. With its tests: 92 automated tests (app 57).
  - **0.5.2:** after a reset that starts the synced library again, the app goes straight to setting
    up a new passkey or recovery code (the old ones no longer open it), then back to Settings.
    93 automated tests (app 58).

### Phase 4: desktop
- The web build: the same library in a desktop browser, with webcam scanning and offline use.
- **Done when:** she can check a book on the laptop while shopping online.

### Phase 5: open-source release
- Install guides (offline only, self-hosted server), screenshots, Ko-fi link.
- Optional sync through Google Drive or Dropbox for people without a server.
- Signed Android release (Play Store or F-Droid: a cost and sign-up decision for later).

### Later, if wanted
- iPhone app (same codebase).
- A public hosted service. Needs the deferred cost work: hosting, storage, backups and email.

## 5. Questions for the product owner

Plain-language questions about how the app should behave. Ask one at a time; "skip" leaves it open.

- ~~**Q1. Name.**~~ Answered 2026-11-14: "Tsundoku" is a working title; the real name is picked before the public release.
- ~~**Q2. Forgotten password and lost phone.**~~ Answered 2026-11-14: a recovery code; then changed
  the same day to an authenticator app for password resets plus a Google-saved passkey (fingerprint)
  to unlock the library on a new phone, with the code as a fallback. See section 3.1.
- ~~**Q3. Logging out.**~~ Answered 2026-11-14: the app **locks** after 1 day without use and opens
  with her fingerprint, face or phone PIN. A full logout (email and password again) only after a long
  time unused: 30 days proposed.
- ~~**Q4. Desktop first or later.**~~ Answered 2026-11-14: phone first. The computer version comes
  in Phase 4, after sync works.
- ~~**Q5. Look and feel.**~~ Answered 2026-11-14: a neutral background with **one soft accent colour**
  for buttons and the ALREADY OWNED label. After the mock-ups: four accents (Sage, Dusty blue, Blush,
  Heather) to pick from in Settings, plus Light or Dark.
- ~~**Q6. Starting look.**~~ Answered 2026-11-14: the app opens in Sage, in light or dark to match the
  phone's own setting, until she picks in Settings.

- ~~**Q7. Books Open Library doesn't know.**~~ Answered 2026-11-14: keep **Open Library only for
  now**; books it doesn't know are typed in. The lookup is built so sources can be added later
  (section 3.5). Trove is the likely next one (key applied for, waiting); Inventaire is a possible
  open backup. Google Books and ISBNdb won't be used. Details: [book-sources.md](book-sources.md).

## 6. Open (deferred in the brief)
- Hosting provider and costs for a public service; email provider (only the hosted service needs one).
- Exact backup schedule options.
- Branding and visual identity.
- Independent security review of the privacy design.

## Decisions log

| Date | Decision | By |
|---|---|---|
| 2026-11-14 | Product rules in section 2 taken from the product owner's brief of 2026-11-14 | product owner |
| 2026-11-14 | Platform: native Android app first, iPhone later and not a priority, PWA only as a fallback (the brief's platform section supersedes its "platform undecided" list) | product owner |
| 2026-11-14 | Q1: "Tsundoku" is a working title until a name is chosen before the public release | product owner |
| 2026-11-14 | Q2: account sign-up gives a one-time recovery code to print or keep safe; it restores the library if the password and every device are lost | product owner |
| 2026-11-14 | Q3: lock after 1 day without use, unlock with fingerprint, face or phone PIN; full logout only after a long time unused (30 days proposed). Refines the brief's "log out after inactivity" | product owner |
| 2026-11-14 | Q4: Android phone first; the computer version follows in Phase 4, after sync | product owner |
| 2026-11-14 | Q5: neutral palette with one soft accent colour for buttons and the ALREADY OWNED label; the colour is chosen from mock-ups | product owner |
| 2026-11-14 | Product and experience decisions belong to the product owner; technical choices may change if the product rules hold | Mystery |
| 2026-11-14 | Licence: MIT | Mystery |
| 2026-11-14 | Recovery: authenticator app (TOTP) for password resets; a passkey saved in her Google account unlocks the library on a new phone; a written recovery code only if passkeys fail the Phase 0 test. Replaces Q2's recovery code | Mystery |
| 2026-11-14 | Email optional: the email address is the login name; servers work without mail; alerts in the app; verification emails only when mail is set up. Replaces the brief's required email verification and reset emails | Mystery |
| 2026-11-14 | Stack: Flutter (Dart) app, `drift` SQLite, `mobile_scanner`; Dart (`shelf`) server. Expo is the fallback if passkey PRF fails in Phase 0 | Mystery |
| 2026-11-14 | Settings: pick one of four accents (Sage, Dusty blue, Blush, Heather) and Light or Dark; nothing more complicated. The fourth accent is named Heather so it doesn't sound like Dusty blue | Mystery |
| 2026-11-14 | Q6: first launch uses Sage, light or dark following the phone, until changed in Settings | Mystery |
| 2026-11-14 | Passkey project domain: mysterygodzilla.github.io (GitHub Pages), hosting only `assetlinks.json` | Mystery |
| 2026-11-14 | Q7: Open Library only for now. Lookups built behind a `BookSource` interface with per-book identifiers, so more sources can be added later. Trove likely next (key applied for); Inventaire a possible open backup; Google Books and ISBNdb (paid) not used | Mystery |
| 2026-11-14 | Phase 0 done: scanning, Open Library lookup, offline search and passkey PRF recovery all worked on her phone. Passkey recovery confirmed; the recovery code stays only as a fallback for phones without PRF | Mystery (tested) |
| 2026-11-14 | Grid covers show a small status bubble (when set) and a Kindle/Physical icon | product owner |
| 2026-11-14 | Fifth accent: Sunflower (light mode uses a deeper gold wherever the accent is text, so it stays readable) | product owner |
| 2026-11-14 | Books she is Reading are pinned to the top of the library until filters arrive | product owner |
| 2026-11-14 | Optional "Finished reading" date on each book (useful for yearly stats later) | product owner |
| 2026-11-14 | Phase 1 done: the owned check works in flight mode on her phone | Mystery (tested) |
| 2026-11-14 | The finished date shows only when a book is Read ("Finished reading") or DNF ("Stopped reading"); kept, hidden, if the status changes back | product owner |
| 2026-11-14 | The phone's own font, not Inter | Mystery |
| 2026-11-14 | No offline indicator; a failed lookup just says "Open Library can't be reached." | Mystery |
| 2026-11-14 | Backups go to a folder she picks (e.g. Google Drive), or stay on the phone until she does | Mystery |
| 2026-11-14 | Backups aren't encrypted in Phase 2; encryption comes with accounts in Phase 3 | Mystery |
| 2026-11-14 | Reading pinned only in the default sort; in Title, Author and Rating sorts it's the tie-breaker | Mystery |
| 2026-11-14 | Filters: chips for format and status, a sort menu, a Filters button for author, genre, rating | Mystery |
| 2026-11-14 | Searching ignores filters (the owned check must see the whole library); author sort is by surname | Mystery (recommended) |
| 2026-11-14 | Drive/OneDrive can't be backup folders (their apps don't share folders with other apps): automatic backups stay in a phone folder; "Save a copy to…" and "Restore from a file…" cover Drive until Phase 3 | Mystery (tested) |
| 2026-11-14 | Export offers Save to… (Downloads, Drive) as well as Share… | Mystery |
| 2026-11-14 | A manual backup copy can be shared to Drive or OneDrive (their share entries are the only way in); automatic off-phone copies wait for Phase 3 | Mystery (tested) |
| 2026-11-14 | Phase 3 is built and tested on this computer first; where the server runs is decided after the network review | Mystery |
| 2026-11-14 | Encryption: Bitwarden model (Argon2id master key; login key to the server; unlock key wraps a random library key; AES-256-GCM) | Mystery |
| 2026-11-14 | Server admin is a command-line tool (no admin web page) | Mystery |
| 2026-11-14 | Phase 3 in three steps: 3a accounts and app lock, 3b sync, 3c recovery, admin and backups | Mystery |
| 2026-11-14 | Sync is optional, an advanced extra: the phone app with backups is complete without it; nothing pushes anyone to sign up | Mystery |
| 2026-11-15 | No background sync: it syncs only while the app is open (on opening, after a change, every few minutes). The library is too small to need it | Mystery |
| 2026-11-15 | Home-network servers (a local address like 10.0.0.20:8797) are supported; the guide says to run the server with `--host 0.0.0.0` for them | Mystery |
| 2026-11-15 | Plain http is allowed but not recommended: the app explains the risk, recommends https and needs her agreement first; the guide says the same | Mystery |
| 2026-11-15 | Docker: a Dockerfile and compose.yaml for the server, with Docker instructions in the guide | Mystery |
| 2026-11-15 | A home-network server waits a week before the "sync hasn't worked" notice (an internet server: a day) | Mystery |
| 2026-11-15 | No email sending: it was only ever for recovery, which the authenticator app and passkey (or recovery code) now cover; changing email takes an authenticator code | Mystery |
| 2026-11-15 | Correction: deleting an account can't reach into the server's older backups; they keep a locked copy until they age out | correction |
| 2026-11-15 | Phase 2 sorting and filtering approved. The chips under the search bar go into the Filters menu: format (Physical, Kindle) first, status second, then author, genre and rating as now. Built at the end of Phase 3 | product owner |
| 2026-11-15 | The last server address is remembered after signing out; a password reset returns to Settings | Mystery (tested) |
| 2026-11-15 | Step 3c works on her phone (single device, server over USB): recovery, reset, change password and email, delete | Mystery (tested) |
| 2026-11-15 | After a reset that starts the synced library again, go straight to setting up a new passkey or recovery code | Mystery |
| 2026-11-15 | The filters change goes in now (0.5.3), not at the end of Phase 3: it's what she sees first | Mystery |
| 2026-11-21 | A scan (or typed ISBN) Open Library doesn't know steers to searching by title or author, not to entering it by hand; a search that finds nothing offers entering it by hand. Built in 0.5.4 | product owner |
| 2026-11-21 | An edition added from that search is saved with the ISBN she scanned (as its ISBN, and kept with the edition's own), so the next scan of that copy shows ALREADY OWNED | recommendation, to confirm |
| 2026-11-21 | Status bubbles on covers each get their own colour and icon, keeping the word (her examples: Read with a tick, TBR another colour or icon). Colours chosen to read at 4.5:1 or better in light and dark; built in 0.5.5, open to her adjustments | product owner |
