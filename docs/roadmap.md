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
- Settings has a simple appearance picker: one of **four accent colours** (Sage, Dusty blue, Blush,
  Heather) and **Light or Dark**. Nothing more (no custom colours, fonts or themes). Book covers are the
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
- Book information comes from Open Library only. If it can't find a book, you type the details.
  A book can always be saved, even with no ISBN (common for Kindle), no cover or missing details.
- Scanning shows the match and asks you to confirm before adding. If the camera isn't available
  or scanning fails, you can type the ISBN.
- Filled in from Open Library where possible: title, authors, ISBN, cover, publisher, publication
  date, edition/format, genres.
- Yours to set: format, date purchased, rating (0 to 5 stars), notes, reading status, genres, and
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
- **Deleting an account destroys its key**, so even copies still sitting in backups become
  unreadable straight away, ahead of the retention window.

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
- **Fallback:** if the Phase 0 test shows passkeys with PRF don't work on her phone, the app shows a
  one-time recovery code at sign-up instead (her original Q2 answer). The local backups and
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
  search on both, and passkey PRF on her phone. If Flutter's passkey PRF fails there, Expo is the
  fallback (decided before any real code).

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
  published rate limits. To check before building: the current limits, terms for cover use and
  caching, and how well Kindle editions are covered.

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
  secret, and get the same secret back after reinstalling the app. If this fails, try the Expo
  fallback before settling for the recovery code.
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

  Neutrals: light `#F7F6F3` background, `#1C1C1A` text; dark `#141414` background, `#EDEDEA` text.
- **Done when:** the stack is in the decisions log, and the spike worked on her phone.

### Phase 1: the owned check, on her phone (offline only)
The core job, with no accounts and no server.
- Add books: scan, ISBN, title/author search with covers, manual entry, own cover photo.
- The library grid with covers; book details; edit; delete.
- Search as you type with the **ALREADY OWNED** label, across editions and formats.
- Format, purchase date, rating, notes, reading status, genres.
- Light and dark modes. Cover cache that can be cleared.
- **Done when:** she can catalogue real books and use it in a shop with flight mode on. Install by
  a direct APK (no app store needed yet).

### Phase 2: organise and protect
- Filters (author, genre, format, status, rating) and sorting (title, author, date added, rating).
- Spreadsheet export.
- Automatic daily local backups with chosen frequency and retention; restore.
- **Done when:** she can lose her phone and get her library back from a backup.

### Phase 3: accounts and sync (self-hosted server)
- The server: accounts, authenticator set-up and password reset, passkey recovery (or the code
  fallback), optional email verification when mail is set up, change email,
  app lock (fingerprint, face or PIN after 1 day), long-inactivity logout, delete account.
- End-to-end encrypted sync between devices; conflict questions; the unsynced-changes list.
- Server backups and restore; the admin view (counts, suspend, health) with no library access.
- An automated privacy test that proves the server holds nothing readable.
- **Done when:** her phone and a second device stay in step, including after offline edits.

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

- **Q7. Books Open Library doesn't know.** Open Library is missing about two in three recent
  Australian books. Her brief says Open Library only, with no second source. Options: (a) keep Open
  Library only and type the rest in; (b) when Open Library doesn't know a book, also ask Trove, the
  National Library of Australia's free catalogue, which has nearly every Australian book (but rarely
  a cover: she'd snap a photo); (c) Google Books as the second source instead (more covers, but her
  brief ruled it out). Recommended: (b), after testing it on the same books. Details:
  [book-sources.md](book-sources.md).

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
