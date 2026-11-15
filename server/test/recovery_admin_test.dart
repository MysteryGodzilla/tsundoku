import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart';
import 'package:tsundoku_server/tsundoku_server.dart';

import 'support.dart';

void main() {
  late Store store;
  late Handler handler;
  late DateTime now;
  const email = 'alice@example.com';
  const password = 'correct horse battery staple';

  setUp(() {
    now = DateTime.utc(2026, 11, 15, 9);
    store = Store.inMemory();
    handler = TsundokuApi(store, clock: () => now).handler;
  });
  tearDown(() => store.close());

  /// The next authenticator code (each code works once, so tests step the clock on).
  String code(String secret) {
    now = now.add(const Duration(seconds: 30));
    return totpAt(base32Decode(secret), totpStep(now));
  }

  /// A signed-up account with the authenticator set up, as the app leaves it.
  Future<(FakeDevice, Uint8List, String)> account(String email) async {
    final d = FakeDevice(handler);
    final salt = randomBytes(16);
    final keys = AccountKeys.fromMaster(deriveMasterKey(password, salt, KdfParams.fastForTests));
    final libraryKey = randomBytes(32);
    final (_, b) = await d.call('POST', '/v1/accounts', {
      'email': email,
      'salt': base64Encode(salt),
      'kdf': KdfParams.fastForTests.toJson(),
      'loginKey': base64Encode(keys.loginKey),
      'wrappedLibraryKey': base64Encode(await seal(keys.unlockKey, libraryKey)),
    });
    d.token = b['token'] as String;
    final secret = b['totpSecret'] as String;
    expect((await d.call('POST', '/v1/totp/confirm', {'code': code(secret)})).$1, 200);
    return (d, libraryKey, secret);
  }

  /// A new password as the app sends it, wrapping [libraryKey].
  Future<Map<String, Object?>> newPassword(String pw, Uint8List libraryKey) async {
    final salt = randomBytes(16);
    final keys = AccountKeys.fromMaster(deriveMasterKey(pw, salt, KdfParams.fastForTests));
    return {
      'salt': base64Encode(salt),
      'kdf': KdfParams.fastForTests.toJson(),
      'loginKey': base64Encode(keys.loginKey),
      'wrappedLibraryKey': base64Encode(await seal(keys.unlockKey, libraryKey)),
    };
  }

  Future<(int, Map<String, Object?>)> signIn(String email, String pw) async {
    final d = FakeDevice(handler);
    final keys = await d.keysFor(email, pw);
    return d.call('POST', '/v1/sessions', {'email': email, 'loginKey': base64Encode(keys.loginKey)});
  }

  group('recovery copies', () {
    test('a passkey copy and a code copy are stored locked, and can be removed', () async {
      final (d, libraryKey, _) = await account(email);
      expect((await d.call('GET', '/v1/recovery')).$2, {'passkey': false, 'code': false});

      final prf = randomBytes(32);
      final codeBytes = parseRecoveryCode(newRecoveryCode())!;
      final (s, b) = await d.call('PUT', '/v1/recovery', {
        'passkey': {
          'credentialId': 'cred-1',
          'prfSalt': base64Encode(randomBytes(32)),
          'wrapped': base64Encode(await seal(passkeyWrapKey(prf), libraryKey)),
        },
        'code': {'wrapped': base64Encode(await seal(recoveryWrapKey(codeBytes), libraryKey))},
      });
      expect(s, 200, reason: '$b');
      expect(b, {'passkey': true, 'code': true});

      expect((await d.call('PUT', '/v1/recovery', {'code': null})).$2, {'passkey': true, 'code': false}, reason: 'only what is sent changes');
      expect((await d.call('PUT', '/v1/recovery', {'passkey': {'credentialId': 'x', 'prfSalt': 'short', 'wrapped': 'AA=='}})).$1, 400);
      expect(FakeDevice(handler).call('GET', '/v1/recovery').then((r) => r.$1), completion(401));
    });
  });

  group('forgotten password', () {
    test('email and authenticator code, then a new password: the same library key, every other device signed out', () async {
      final (phone, libraryKey, secret) = await account(email);
      final prf = randomBytes(32);
      await phone.call('PUT', '/v1/recovery', {
        'passkey': {'credentialId': 'cred-1', 'prfSalt': base64Encode(randomBytes(32)), 'wrapped': base64Encode(await seal(passkeyWrapKey(prf), libraryKey))},
      });

      final newPhone = FakeDevice(handler);
      final (s, start) = await newPhone.call('POST', '/v1/reset/start', {'email': 'Alice@Example.com', 'code': code(secret)});
      expect(s, 200, reason: '$start');
      final rec = (start['recovery']! as Map).cast<String, Object?>();
      final passkey = (rec['passkey']! as Map).cast<String, Object?>();
      expect(passkey['credentialId'], 'cred-1');
      final unlocked = await open(passkeyWrapKey(prf), base64Decode(passkey['wrapped']! as String));
      expect(unlocked, libraryKey, reason: 'the passkey copy opens the library key');

      final (s2, fin) = await newPhone.call('POST', '/v1/reset/finish', {
        'resetToken': start['resetToken'],
        ...await newPassword('a brand new password', unlocked),
      });
      expect(s2, 200, reason: '$fin');
      expect(fin['totpConfirmed'], true);
      newPhone.token = fin['token'] as String;
      expect((await newPhone.call('GET', '/v1/account')).$1, 200);
      expect((await phone.call('GET', '/v1/account')).$1, 401, reason: 'other devices are signed out');

      expect((await signIn(email, password)).$1, 401, reason: 'the old password no longer works');
      final (s3, b3) = await signIn(email, 'a brand new password');
      expect(s3, 200);
      final keys = await FakeDevice(handler).keysFor(email, 'a brand new password');
      expect(await open(keys.unlockKey, base64Decode(b3['wrappedLibraryKey']! as String)), libraryKey);
      expect((await phone.call('POST', '/v1/reset/finish', {'resetToken': start['resetToken'], ...await newPassword('again and again', libraryKey)})).$1, 400,
          reason: 'a reset token works once');
    });

    test('a wrong or reused code, or an unknown email, all answer the same; too many tries are slowed', () async {
      final (_, _, secret) = await account(email);
      final good = code(secret);
      final (s, b) = await FakeDevice(handler).call('POST', '/v1/reset/start', {'email': 'nobody@example.com', 'code': good});
      expect(s, 400);
      final (s2, b2) = await FakeDevice(handler).call('POST', '/v1/reset/start', {'email': email, 'code': good == '123456' ? '654321' : '123456'});
      expect(s2, 400);
      expect(b2['error'], b['error'], reason: 'no hint about which emails have accounts');
      expect((await FakeDevice(handler).call('POST', '/v1/reset/start', {'email': email, 'code': good})).$1, 200);
      expect((await FakeDevice(handler).call('POST', '/v1/reset/start', {'email': email, 'code': good})).$1, 400, reason: 'no reuse');
      for (var i = 0; i < 10; i++) {
        await FakeDevice(handler).call('POST', '/v1/reset/start', {'email': email, 'code': '000000'});
      }
      expect((await FakeDevice(handler).call('POST', '/v1/reset/start', {'email': email, 'code': code(secret)})).$1, 429);
    });

    test('the reset token runs out', () async {
      final (_, libraryKey, secret) = await account(email);
      final (_, start) = await FakeDevice(handler).call('POST', '/v1/reset/start', {'email': email, 'code': code(secret)});
      now = now.add(const Duration(minutes: 16));
      final (s, b) = await FakeDevice(handler).call('POST', '/v1/reset/finish', {'resetToken': start['resetToken'], ...await newPassword('too late now', libraryKey)});
      expect(s, 400);
      expect(b['error'], contains('too long'));
    });

    test('starting again without the old library removes its locked copies', () async {
      final (phone, libraryKey, secret) = await account(email);
      await phone.call('POST', '/v1/events', {'device': 'phone1', 'events': [base64Encode([1, 2])]});
      await phone.call('PUT', '/v1/blobs/photo-1', {'data': base64Encode([3])});
      await phone.call('PUT', '/v1/recovery', {'code': {'wrapped': base64Encode(await seal(recoveryWrapKey(randomBytes(15)), libraryKey))}});
      final d = FakeDevice(handler);
      final (_, start) = await d.call('POST', '/v1/reset/start', {'email': email, 'code': code(secret)});
      final fresh = randomBytes(32);
      final (s, fin) = await d.call('POST', '/v1/reset/finish', {'resetToken': start['resetToken'], 'fresh': true, ...await newPassword('starting over now', fresh)});
      expect(s, 200);
      d.token = fin['token'] as String;
      expect(((await d.call('GET', '/v1/events?after=0')).$2['events']! as List), isEmpty);
      expect((await d.call('GET', '/v1/blobs/photo-1')).$1, 404);
      expect((await d.call('GET', '/v1/recovery')).$2, {'passkey': false, 'code': false});
    });
  });

  group('signed in', () {
    test('change password needs the authenticator code; this device stays signed in, others are signed out', () async {
      final (phone, libraryKey, secret) = await account(email);
      final (_, other) = await signIn(email, password);
      final tablet = FakeDevice(handler)..token = other['token'] as String;

      final body = await newPassword('a much better password', libraryKey);
      expect((await phone.call('POST', '/v1/account/password', {...body, 'code': '000000'})).$1, 400);
      final (s, b) = await phone.call('POST', '/v1/account/password', {...body, 'code': code(secret)});
      expect(s, 200, reason: '$b');
      expect((await phone.call('GET', '/v1/account')).$1, 200);
      expect((await tablet.call('GET', '/v1/account')).$1, 401);
      expect((await signIn(email, 'a much better password')).$1, 200);
    });

    test('change email needs the authenticator code and a free address', () async {
      final (phone, _, secret) = await account(email);
      await account('bob@example.com');
      expect((await phone.call('POST', '/v1/account/email', {'email': 'bob@example.com', 'code': code(secret)})).$1, 409);
      expect((await phone.call('POST', '/v1/account/email', {'email': 'not an email', 'code': code(secret)})).$1, 400);
      expect((await phone.call('POST', '/v1/account/email', {'email': 'alice@example.org', 'code': '000000'})).$1, 400);
      final (s, b) = await phone.call('POST', '/v1/account/email', {'email': ' Alice@Example.org ', 'code': code(secret)});
      expect(s, 200, reason: '$b');
      expect((await phone.call('GET', '/v1/account')).$2['email'], 'alice@example.org');
      expect((await signIn('alice@example.org', password)).$1, 200, reason: 'the password still works with the new email');
      expect((await signIn(email, password)).$1, 401);
    });
  });

  group('admin', () {
    test('stats and list show accounts and storage, never library data', () async {
      final (alice, _, _) = await account(email);
      await account('bob@example.com');
      await alice.call('POST', '/v1/events', {'device': 'phone1', 'events': [base64Encode(utf8.encode('locked box'))]});
      await alice.call('PUT', '/v1/blobs/photo-1', {'data': base64Encode(List.filled(2048, 7))});
      final admin = Admin(store, clock: () => now);
      final stats = admin.stats().join('\n');
      expect(stats, contains('Accounts: 2 (2 set up, 2 used in the last 30 days, 0 suspended)'));
      expect(stats, contains('Synced changes: 1'));
      expect(stats, contains('photos: 1 (2.0 KB)'));
      final list = admin.list();
      expect(list.first, startsWith('Email'));
      expect(list.join('\n'), allOf(contains(email), contains('bob@example.com'), contains('2026-11-15')));
      expect(list.join('\n'), isNot(contains('locked box')));
    });

    test('suspend signs the account out and blocks sign-in; unsuspend lets it back; delete removes it', () async {
      final (alice, _, _) = await account(email);
      final admin = Admin(store, clock: () => now);
      expect(admin.suspend('ALICE@example.com'), contains('Suspended'));
      expect((await alice.call('GET', '/v1/account')).$1, 401);
      expect((await signIn(email, password)).$1, 403);
      admin.suspend(email, suspended: false);
      expect((await signIn(email, password)).$1, 200);
      expect(admin.delete(email), contains('Deleted'));
      expect(store.accountByEmail(email), isNull);
      expect(() => admin.delete(email), throwsA(isA<AdminProblem>()));
    });
  });

  group('backups', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('tsundoku-backups-'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('one a day, a readable copy, and old ones pruned (the newest is always kept)', () async {
      await account(email);
      var clock = DateTime(2026, 11, 1, 3);
      final backups = Backups(store, p.join(tmp.path, 'backups'), keepDays: 3, clock: () => clock);
      final first = backups.runIfDue()!;
      expect(p.basename(first), 'tsundoku-2026-11-01-0300.db');
      clock = clock.add(const Duration(hours: 5));
      expect(backups.runIfDue(), isNull, reason: 'not due yet');
      for (var d = 0; d < 6; d++) {
        clock = clock.add(const Duration(days: 1));
        backups.runIfDue();
      }
      final kept = backups.list();
      expect(kept.length, 4, reason: 'kept for 3 days, plus today');
      expect(kept.first.at.day, 7);

      final copy = sqlite3.open(kept.first.path, mode: OpenMode.readOnly);
      expect(copy.select('SELECT email FROM accounts').single['email'], email);
      copy.close();

      clock = clock.add(const Duration(days: 30));
      final only = Backups(store, backups.dir, keepDays: 3, clock: () => clock)..prune();
      expect(only.list().length, 1, reason: 'never prunes the last copy');
    });

    test('stats show the last backup', () async {
      final backups = Backups(store, p.join(tmp.path, 'b'), clock: () => DateTime(2026, 11, 15, 2));
      expect(Admin(store, backups: backups).stats().last, contains('none yet'));
      backups.backupNow();
      expect(Admin(store, backups: backups).stats().last, contains('last 2026-11-15, 1 kept'));
    });
  });

  test('a database from 0.2.0 gains the recovery column when opened', () {
    final tmp = Directory.systemTemp.createTempSync('tsundoku-upgrade-');
    final path = p.join(tmp.path, 'old.db');
    final old = sqlite3.open(path);
    old.execute('''CREATE TABLE accounts (id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE, salt BLOB NOT NULL, kdf TEXT NOT NULL,
        login_hash TEXT NOT NULL, wrapped_library_key BLOB NOT NULL, totp_secret BLOB NOT NULL,
        totp_confirmed INTEGER NOT NULL DEFAULT 0, totp_last_step INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL, last_seen_at INTEGER NOT NULL, suspended INTEGER NOT NULL DEFAULT 0)''');
    old.close();
    final s = Store.open(path);
    expect(s.db.select('PRAGMA table_info(accounts)').map((r) => r['name']), contains('recovery'));
    s.close();
    Store.open(path).close(); // Opening again doesn't try to add it twice.
    tmp.deleteSync(recursive: true);
  });
}
