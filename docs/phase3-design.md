# Phase 3 design: accounts and end-to-end encrypted sync

Approved 2026-11-14. Product rules come from the roadmap (section 2); this is how they're built.
Built and tested on one computer first (simulated devices); where the server runs for real is
decided later.

## Goals (from the product rules)
- **Optional.** Everything here is for people who choose to sync. The app works completely
  without an account or server, never asks anyone to sign up, and the app lock applies only to
  signed-in phones.
- Her library works fully offline; sync is optional and catches up when online.
- **Nobody but her can read her library, including whoever runs the server.** Enforced by
  encryption on the device, not by hiding things in admin screens, and tested.
- Email address as the login name; password; authenticator app (TOTP) for password resets; a passkey
  (or, as a fallback, a recovery code) unlocks the library on a new phone. Email sending is optional.
- App lock after 1 day unused (fingerprint, face or PIN); full sign-out after 30 days unused.
- Changes are never silently lost; real conflicts are put to her.

## Keys (the Bitwarden model)
```
password ──Argon2id(salt)──► master key (never leaves the phone, never stored)
master key ──HKDF "login"──► login key   → sent to the server at sign-in; the server stores SHA-256 of it
master key ──HKDF "unlock"─► unlock key  → wraps the library key (AES-256-GCM)

library key: 32 random bytes made on the first device. Encrypts every synced change and backup.
  stored on the server only wrapped:  by the unlock key (password)
                                      by the passkey's PRF secret (HKDF of it)   [3c]
                                      by the recovery code (fallback)            [3c]
  stored on the phone in Android's secure storage (Keystore-backed), with the session token.
```
- **Salt:** random per account, stored on the server. `POST /v1/prelogin {email}` returns the salt and
  Argon2id settings. For an unknown email it returns a stable fake salt (HMAC of the email with a
  server secret), so it doesn't reveal which emails have accounts.
- **Argon2id settings** are stored per account so they can be raised later without breaking logins.
- The server never sees the password, the master key, the unlock key or the library key. A stolen
  server database gives salts, login-key hashes and locked boxes.

## Accounts (step 3a)
| Call | What |
|---|---|
| `GET /v1/health` | `{ok, version}` |
| `POST /v1/prelogin` | `{email}` → `{salt, kdf}` |
| `POST /v1/accounts` | sign up: `{email, salt, kdf, loginKey, wrappedLibraryKey}` → `{token, totpSecret}` |
| `POST /v1/totp/confirm` | `{code}`: proves the authenticator app is set up; required before sync |
| `POST /v1/sessions` | sign in: `{email, loginKey}` → `{token, wrappedLibraryKey}` |
| `DELETE /v1/sessions/current` | sign out |
| `GET /v1/account` | `{email, totpConfirmed, createdAt}` |
| `DELETE /v1/account` | `{loginKey}`: deletes the account and all its data at once |

- Tokens: 32 random bytes, sent as `Authorization: Bearer`; the server stores SHA-256 of them. A
  session not used for 30 days expires (the full sign-out rule).
- Sign-in attempts are rate-limited per email and per address.
- TOTP: RFC 6238, 6 digits, 30 seconds, SHA-1 (what authenticator apps expect); ±1 step allowed; a
  code can't be used twice. Set up with an "Add to authenticator app" link (`otpauth://`) and the key
  shown for typing, since a phone can't scan its own screen.

## Sync (step 3b)
Built 2026-11-15 as described, with one detail settled: a sync **pulls before it pushes**, so only
the device that syncs second sees a conflict, and asks once.
- Every change already goes into the phone's change log. Each entry becomes a **change event**:
  `{bookId, field, value, at (hybrid logical clock), deviceId}`, JSON, then encrypted with the
  library key (AES-256-GCM, random 96-bit nonce, the account id as associated data).
- Server storage per account: an append-only list of `(seq, deviceId, ciphertext)`. It can't read,
  merge or reorder anything; it hands out events after a cursor.
- `POST /v1/events` pushes a batch; `GET /v1/events?after=seq` pulls. Push when online and
  something changed (debounced), pull on open/resume and every few minutes while open.
- **Merging, field by field:** different fields changed on two devices both survive. The same field
  changed on both since they last synced is a **conflict**: the app keeps both values and asks her
  which to keep. A deletion against an edit also asks. Otherwise the later clock wins.
- Unsynced changes are listed in Settings; after repeated failures (about a day) a gentle notice.
- Her own cover photos sync as encrypted attachments.

## Recovery, admin, backups (step 3c)
- **New phone, password known:** sign in, the wrapped library key comes down, unlock.
- **Password forgotten:** email + authenticator code → set a new password. The library key comes
  from a signed-in device, or from her passkey (fingerprint), or the recovery code; it's re-wrapped
  under the new password. Without any of those the synced library can't be opened (by design).
- **Change email:** signed in, with the authenticator code; verification email only if the server
  has mail set up.
- **Admin (command line on the server):** `stats` (account count, storage, health), `list`
  (emails, created, last seen: no library data), `suspend`, `delete`. There is no admin web page.
- **Server backups:** nightly copy of the database (only locked boxes), kept by the retention
  setting. Deleting an account removes its key material, so its data in older backups can't be read.
- **Install guide:** one Dart executable plus a config file; Docker optional.

## Layout
- `server/`: the Dart server (`shelf`, `sqlite3`), its tests and admin commands.
- `packages/tsundoku_protocol/`: pure Dart shared by app and server: key derivation, wrapping,
  event encryption, TOTP, request and response shapes.
- `app/`: sign-up and sign-in screens, app lock, sync engine.

## Tests that prove the privacy rule
- After a full sync of a library with known titles, authors and notes, the server's database file
  is searched for every one of those strings (and their UTF-16 forms): none may appear.
- Signing in with a wrong password fails; with the right password on a "new device" the library comes
  back intact; the server alone cannot decrypt (no key material it holds unwraps the library key).
