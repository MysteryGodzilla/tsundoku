/// The server's database (SQLite). It holds accounts, sessions and, from step 3b, locked boxes.
/// It never holds a password, a key that can open a library, or any book data in readable form.
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
      CREATE TABLE IF NOT EXISTS sessions (
        token_hash TEXT PRIMARY KEY,
        account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        created_at INTEGER NOT NULL,
        last_used_at INTEGER NOT NULL
      );
    ''');
  }

  factory Store.open(String path) => Store._(sqlite3.open(path));
  factory Store.inMemory() => Store._(sqlite3.openInMemory());

  final Database db;

  void close() => db.close();

  /// A random secret made on first run; it makes fake salts for unknown emails stable.
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

  void deleteSession(String tokenHash) => db.execute('DELETE FROM sessions WHERE token_hash = ?', [tokenHash]);
}
