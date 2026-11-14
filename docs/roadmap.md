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
- Calm and minimal: clean layouts, a neutral palette, light and dark modes. Book covers are the
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
- Accounts: email and password, password reset, change of email (the new address is verified
  first), log out after a period of inactivity. No "sign in with Google".
- Delete your account and library from inside the app, after a clear warning. Copies in backups
  expire with the backup retention, and the app says so plainly.
- Messages only when they matter: verifying your email, password resets, security alerts and
  persistent sync problems. No reminders, nudges, challenges or promotions.
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

One consequence needs the product owner's say (see [question Q2](#5-questions-for-the-product-owner)):
if the server can't read a library, it can't rescue one either. Forgetting the password is fine
while any signed-in device still has the library (it re-encrypts and re-uploads after a reset).
Forgetting the password **and** losing every device would lose the synced copy, unless a recovery
code was saved somewhere safe. The local backups and spreadsheet export are the other safety nets.

### 3.2 App platform
*Recommended:* **React Native with Expo, in TypeScript.** One codebase gives a true native Android
app first, an iPhone app later without a rewrite, and a web build for desktop. The sync server is
written in TypeScript too, so the whole project is one language.
- Barcode scanning: the native camera scanner on Android (fast, works in poor light); a JavaScript
  barcode library (ZXing family) on desktop browsers, not a single browser's built-in detector.
- Local database: SQLite on the phone; SQLite in the browser (WebAssembly, stored in the browser's
  private file system) for the web build. Covers cached as files.
- *Alternative:* Flutter, which is similar in reach. Either works; Expo is recommended for the
  shared language with the server and the size of its ecosystem.
- To prove in the Phase 0 spike: scanning on a real Android phone and a laptop webcam, and offline
  SQLite search on both.

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
- *Recommended:* a small Node/TypeScript server with SQLite (PostgreSQL optional for big
  installations), shipped as one Docker image plus a plain install guide. It handles accounts,
  storing encrypted events, backups and admin counts.
- Passwords are never stored in a form the server can use to read data: login and encryption use
  separate keys derived from the password on the device (an OPAQUE- or SRP-style login, or Argon2id
  hashing on the server for the login key).
- Email for verification and resets goes through whatever SMTP service the server's owner sets up.
  Self-hosters bring their own; the public hosted service needs a provider (cost question, deferred).
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
*Recommended:* **AGPL-3.0**: anyone may use and modify it, and anyone who runs a modified version
as a public service must share their changes. MIT is the simpler, more permissive option. To be
decided by Mystery (it's a technical/legal choice that doesn't change the experience).

## 4. Roadmap

Each phase ends with something the product owner can hold and try. Nothing moves to the next phase
until she's happy with the current one.

### Phase 0: decide and prove (before any real code)
- Approve the technical choices in section 3 (Mystery) and answer the questions in section 5 (the
  product owner).
- Spike, thrown away afterwards: an Expo app on her Android phone that scans a barcode, looks it up
  on Open Library, saves it to SQLite and finds it offline. The same on a laptop webcam.
- Check Open Library's limits, terms and Kindle coverage; write the findings in `docs/`.
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
- The server: accounts, email verification, recovery code at sign-up, password reset, change email, inactivity logout,
  delete account.
- End-to-end encrypted sync between devices; conflict questions; the unsynced-changes list.
- Server backups and restore; the admin view (counts, suspend, health) with no library access.
- An automated privacy test that proves the server holds nothing readable.
- **Done when:** her phone and a second device stay in step, including after offline edits.

### Phase 4: desktop
- The web build: the same library in a desktop browser, with webcam scanning and offline use.
- **Done when:** she can check a book on the laptop while shopping online.

### Phase 5: open-source release
- Install guides (offline only, self-hosted server), screenshots, licence, Ko-fi link.
- Optional sync through Google Drive or Dropbox for people without a server.
- Signed Android release (Play Store or F-Droid: a cost and sign-up decision for later).

### Later, if wanted
- iPhone app (same codebase).
- A public hosted service. Needs the deferred cost work: hosting, storage, backups and email.

## 5. Questions for the product owner

Plain-language questions about how the app should behave. Ask one at a time; "skip" leaves it open.

- ~~**Q1. Name.**~~ Answered 2026-11-14: "Tsundoku" is a working title; the real name is picked before the public release.
- ~~**Q2. Forgotten password and lost phone.**~~ Answered 2026-11-14: a recovery code. At sign-up
  the app shows a code once and asks her to print it or keep it somewhere safe; with it she can always
  get her library back.
- **Q3. Logging out.** On a phone, being logged out often gets in the way of a quick check in a
  shop. Would you prefer the app to lock after a while and open with your fingerprint or PIN, or to
  log you out fully? How long before it locks: 15 minutes, an hour, a day?
- **Q4. Desktop first or later.** Is the phone alone enough to start, with the computer coming in
  Phase 4?
- **Q5. Look and feel.** Any colours, apps or websites whose look you like, to guide the first
  design?

## 6. Open (deferred in the brief)
- Hosting provider and costs for a public service; email provider.
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
| 2026-11-14 | Product and experience decisions belong to the product owner; technical choices may change if the product rules hold | Mystery |
