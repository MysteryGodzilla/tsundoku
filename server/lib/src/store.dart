/// The server's database (SQLite). It holds accounts, sessions and locked boxes (change events,
/// photos and the wrapped copies of each library key). It never holds a password, a key that can
/// open a library, or any book data in readable form.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart';

class Account {
  Account({
    required this.id,
    required this.email,
    required this.salt,
    required this.kdf,
    required this.loginHash,
    required this.wrappedLibraryKey,
    required this.totpSecret,
    required this.totpConfirmed,
    required this.totpLastStep,
    required this.createdAt,
    required this.lastSeenAt,
    required this.suspended,
  });
  final String id;
  final String email;
  final Uint8List salt;
  final KdfParams kdf;
  final String loginHash;
  final Uint8List wrappedLibraryKey;
  final Uint8List totpSecret;
  final bool totpConfirmed;
  final int totpLastStep;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final bool suspended;
}

class Store {
  Store._(this.db) {
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('''
      CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value BLOB NOT NULL);
      CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        salt BLOB NOT NULL,
        kdf TEXT NOT NULL,
        login_hash TEXT NOT NULL,
        wrapped_library_key BLOB NOT NULL,
        totp_secret BLOB NOT NULL,
        totp_confirmed INTEGER NOT NULL DEFAULT 0,
        totp_last_step INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        last_seen_at INTEGER NOT NULL,
        suspended INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS events (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        device TEXT NOT NULL,
        data BLOB NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS events_by_account ON events (account_id, seq);
      CREATE TABLE IF NOT EXISTS blobs (
        account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        id TEXT NOT NULL,
        data BLOB NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (account_id, id)
      );
      CREATE TABLE IF NOT EXISTS sessions (
        token_hash TEXT PRIMARY KEY,
        account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        created_at INTEGER NOT NULL,
        last_used_at INTEGER NOT NULL
      );
    ''');
    // 0.3.0: the library key wrapped by a passkey and/or a recovery code (JSON, locked boxes only).
    final columns = db.select('PRAGMA table_info(accounts)').map((r) => r['name'] as String).toSet();
    if (!columns.contains('recovery')) db.execute('ALTER TABLE accounts ADD COLUMN recovery TEXT');
  }

  factory Store.open(String path) => Store._(sqlite3.open(path));
  factory Store.inMemory() => Store._(sqlite3.openInMemory());

  final Database db;

  void close() => db.close();

  /// A random secret made on first run; it makes fake salts for unknown emails stable.
  String? getMeta(String key) => db.select('SELECT value FROM meta WHERE key = ?', [key]).firstOrNull?['value']?.toString();

  void setMeta(String key, String value) =>
      db.execute('INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT (key) DO UPDATE SET value = excluded.value', [key, value]);

  Uint8List get serverSecret {
    final row = db.select("SELECT value FROM meta WHERE key = 'server_secret'").firstOrNull;
    if (row != null) return Uint8List.fromList(row['value'] as List<int>);
    final s = randomBytes(32);
    db.execute("INSERT INTO meta (key, value) VALUES ('server_secret', ?)", [s]);
    return s;
  }

  Account _account(Row r) => Account(
        id: r['id'] as String,
        email: r['email'] as String,
        salt: Uint8List.fromList(r['salt'] as List<int>),
        kdf: KdfParams.fromJson((jsonDecode(r['kdf'] as String) as Map).cast<String, Object?>()),
        loginHash: r['login_hash'] as String,
        wrappedLibraryKey: Uint8List.fromList(r['wrapped_library_key'] as List<int>),
        totpSecret: Uint8List.fromList(r['totp_secret'] as List<int>),
        totpConfirmed: (r['totp_confirmed'] as int) == 1,
        totpLastStep: r['totp_last_step'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        lastSeenAt: DateTime.fromMillisecondsSinceEpoch(r['last_seen_at'] as int),
        suspended: (r['suspended'] as int) == 1,
      );

  Account? accountByEmail(String email) =>
      db.select('SELECT * FROM accounts WHERE email = ?', [normaliseEmail(email)]).map(_account).firstOrNull;

  Account? accountById(String id) => db.select('SELECT * FROM accounts WHERE id = ?', [id]).map(_account).firstOrNull;

  List<Account> allAccounts() => db.select('SELECT * FROM accounts ORDER BY created_at').map(_account).toList();

  void insertAccount(Account a) => db.execute(
        'INSERT INTO accounts (id, email, salt, kdf, login_hash, wrapped_library_key, totp_secret, created_at, last_seen_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          a.id, normaliseEmail(a.email), a.salt, jsonEncode(a.kdf.toJson()), a.loginHash, a.wrappedLibraryKey, a.totpSecret,
          a.createdAt.millisecondsSinceEpoch, a.lastSeenAt.millisecondsSinceEpoch,
        ],
      );

  void confirmTotp(String accountId, int step) =>
      db.execute('UPDATE accounts SET totp_confirmed = 1, totp_last_step = ? WHERE id = ?', [step, accountId]);

  void setTotpLastStep(String accountId, int step) => db.execute('UPDATE accounts SET totp_last_step = ? WHERE id = ?', [step, accountId]);

  void touchAccount(String accountId, DateTime now) =>
      db.execute('UPDATE accounts SET last_seen_at = ? WHERE id = ?', [now.millisecondsSinceEpoch, accountId]);

  void setSuspended(String accountId, bool suspended) {
    db.execute('UPDATE accounts SET suspended = ? WHERE id = ?', [suspended ? 1 : 0, accountId]);
    if (suspended) db.execute('DELETE FROM sessions WHERE account_id = ?', [accountId]);
  }

  /// Removes the account and, through the foreign keys, everything that belongs to it.
  void deleteAccount(String accountId) => db.execute('DELETE FROM accounts WHERE id = ?', [accountId]);

  void insertSession(String tokenHash, String accountId, DateTime now) => db.execute(
        'INSERT INTO sessions (token_hash, account_id, created_at, last_used_at) VALUES (?, ?, ?, ?)',
        [tokenHash, accountId, now.millisecondsSinceEpoch, now.millisecondsSinceEpoch],
      );

  /// The account for a session, if it exists and was used within [maxIdle]; marks it used.
  Account? useSession(String tokenHash, DateTime now, Duration maxIdle) {
    final row = db.select('SELECT account_id, last_used_at FROM sessions WHERE token_hash = ?', [tokenHash]).firstOrNull;
    if (row == null) return null;
    final last = DateTime.fromMillisecondsSinceEpoch(row['last_used_at'] as int);
    if (now.difference(last) > maxIdle) {
      deleteSession(tokenHash);
      return null;
    }
    db.execute('UPDATE sessions SET last_used_at = ? WHERE token_hash = ?', [now.millisecondsSinceEpoch, tokenHash]);
    final id = row['account_id'] as String;
    touchAccount(id, now);
    return accountById(id);
  }

  /// Appends locked change events; returns the last sequence number.
  int addEvents(String accountId, String device, List<Uint8List> events, DateTime now) {
    final stmt = db.prepare('INSERT INTO events (account_id, device, data, created_at) VALUES (?, ?, ?, ?)');
    db.execute('BEGIN');
    try {
      for (final e in events) {
        stmt.execute([accountId, device, e, now.millisecondsSinceEpoch]);
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    } finally {
      stmt.close();
    }
    return lastSeq(accountId);
  }

  int lastSeq(String accountId) =>
      (db.select('SELECT MAX(seq) AS s FROM events WHERE account_id = ?', [accountId]).first['s'] as int?) ?? 0;

  List<({int seq, String device, Uint8List data})> eventsAfter(String accountId, int after, int limit) => [
        for (final r in db.select('SELECT seq, device, data FROM events WHERE account_id = ? AND seq > ? ORDER BY seq LIMIT ?', [accountId, after, limit]))
          (seq: r['seq'] as int, device: r['device'] as String, data: Uint8List.fromList(r['data'] as List<int>)),
      ];

  void putBlob(String accountId, String id, Uint8List data, DateTime now) => db.execute(
        'INSERT INTO blobs (account_id, id, data, updated_at) VALUES (?, ?, ?, ?) '
        'ON CONFLICT (account_id, id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at',
        [accountId, id, data, now.millisecondsSinceEpoch],
      );

  Uint8List? getBlob(String accountId, String id) {
    final r = db.select('SELECT data FROM blobs WHERE account_id = ? AND id = ?', [accountId, id]).firstOrNull;
    return r == null ? null : Uint8List.fromList(r['data'] as List<int>);
  }

  void deleteSession(String tokenHash) => db.execute('DELETE FROM sessions WHERE token_hash = ?', [tokenHash]);

  /// Ends every session for the account, except [keep] (the one making the change).
  void endSessions(String accountId, {String? keep}) =>
      db.execute('DELETE FROM sessions WHERE account_id = ? AND token_hash IS NOT ?', [accountId, keep]);

  // ---------- Recovery, password and email (step 3c) ----------

  /// The wrapped copies of the library key: `{passkey: {credentialId, prfSalt, wrapped}, code: {wrapped}}`.
  Map<String, Object?> recovery(String accountId) {
    final v = db.select('SELECT recovery FROM accounts WHERE id = ?', [accountId]).firstOrNull?['recovery'] as String?;
    return v == null ? {} : (jsonDecode(v) as Map).cast<String, Object?>();
  }

  void setRecovery(String accountId, Map<String, Object?> r) =>
      db.execute('UPDATE accounts SET recovery = ? WHERE id = ?', [r.isEmpty ? null : jsonEncode(r), accountId]);

  void setPassword(String accountId, {required Uint8List salt, required KdfParams kdf, required String loginHash, required Uint8List wrappedLibraryKey}) =>
      db.execute(
        'UPDATE accounts SET salt = ?, kdf = ?, login_hash = ?, wrapped_library_key = ? WHERE id = ?',
        [salt, jsonEncode(kdf.toJson()), loginHash, wrappedLibraryKey, accountId],
      );

  void setEmail(String accountId, String email) => db.execute('UPDATE accounts SET email = ? WHERE id = ?', [normaliseEmail(email), accountId]);

  /// Starting the library again (a reset with no way to unlock the old one): its locked changes,
  /// photos and recovery copies can never be opened, so they go.
  void wipeLibrary(String accountId) {
    db.execute('DELETE FROM events WHERE account_id = ?', [accountId]);
    db.execute('DELETE FROM blobs WHERE account_id = ?', [accountId]);
    setRecovery(accountId, {});
  }

  // ---------- Admin and backups ----------

  /// Storage per account: how many locked changes and photos, and their size. No library data.
  ({int events, int eventBytes, int photos, int photoBytes}) usage(String accountId) {
    final e = db.select('SELECT COUNT(*) AS n, COALESCE(SUM(LENGTH(data)), 0) AS b FROM events WHERE account_id = ?', [accountId]).first;
    final p = db.select('SELECT COUNT(*) AS n, COALESCE(SUM(LENGTH(data)), 0) AS b FROM blobs WHERE account_id = ?', [accountId]).first;
    return (events: e['n'] as int, eventBytes: e['b'] as int, photos: p['n'] as int, photoBytes: p['b'] as int);
  }

  /// The database's size on disk, in bytes.
  int get sizeBytes {
    final pages = db.select('PRAGMA page_count').first.values.first as int;
    final size = db.select('PRAGMA page_size').first.values.first as int;
    return pages * size;
  }

  /// A consistent copy of the whole database, made while the server keeps running.
  void backupTo(String path) => db.execute('VACUUM INTO ?', [path]);
}
