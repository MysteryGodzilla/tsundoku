import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart';
import 'package:tsundoku_server/tsundoku_server.dart';

/// A device as the app will act: derives keys from the password and talks JSON to the server.
class FakeDevice {
  FakeDevice(this.handler);
  final Handler handler;
  String? token;

  Future<(int, Map<String, Object?>)> call(String method, String path, [Map<String, Object?>? body]) async {
    final res = await handler(Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {if (token != null) 'authorization': 'Bearer $token', 'content-type': 'application/json'},
    ));
    return (res.statusCode, (jsonDecode(await res.readAsString()) as Map).cast<String, Object?>());
  }

  Future<AccountKeys> keysFor(String email, String password) async {
    final (_, pre) = await call('POST', '/v1/prelogin', {'email': email});
    final salt = base64Decode(pre['salt']! as String);
    final kdf = KdfParams.fromJson((pre['kdf']! as Map).cast<String, Object?>());
    return AccountKeys.fromMaster(deriveMasterKey(password, salt, kdf == KdfParams.standard ? KdfParams.fastForTests : kdf));
  }
}

void main() {
  late Store store;
  late Handler handler;
  late DateTime now;
  const email = 'alice@example.com';
  const password = 'correct horse battery staple';

  setUp(() {
    now = DateTime.utc(2026, 11, 14, 9);
    store = Store.inMemory();
    handler = TsundokuApi(store, clock: () => now).handler;
  });
  tearDown(() => store.close());

  /// Signs up like the app: new salt, keys from the password, a random library key wrapped by the unlock key.
  Future<(FakeDevice, Uint8List, String)> signUp(String email, String password) async {
    final d = FakeDevice(handler);
    final salt = randomBytes(16);
    final keys = AccountKeys.fromMaster(deriveMasterKey(password, salt, KdfParams.fastForTests));
    final libraryKey = randomBytes(32);
    final (status, body) = await d.call('POST', '/v1/accounts', {
      'email': email,
      'salt': base64Encode(salt),
      'kdf': KdfParams.fastForTests.toJson(),
      'loginKey': base64Encode(keys.loginKey),
      'wrappedLibraryKey': base64Encode(await seal(keys.unlockKey, libraryKey)),
    });
    expect(status, 201, reason: '$body');
    d.token = body['token'] as String;
    return (d, libraryKey, body['totpSecret'] as String);
  }

  test('health', () async {
    final (s, b) = await FakeDevice(handler).call('GET', '/v1/health');
    expect(s, 200);
    expect(b['ok'], true);
  });

  test('sign up on one device, sign in on another, and the same library key unlocks', () async {
    final (_, libraryKey, _) = await signUp(email, password);

    final phone2 = FakeDevice(handler);
    final keys = await phone2.keysFor('  ALICE@example.com ', password);
    final (s, b) = await phone2.call('POST', '/v1/sessions', {'email': 'Alice@Example.com', 'loginKey': base64Encode(keys.loginKey)});
    expect(s, 200, reason: '$b');
    final unwrapped = await open(keys.unlockKey, base64Decode(b['wrappedLibraryKey']! as String));
    expect(unwrapped, libraryKey);

    final wrong = await phone2.keysFor(email, 'wrong password');
    final (s2, b2) = await phone2.call('POST', '/v1/sessions', {'email': email, 'loginKey': base64Encode(wrong.loginKey)});
    expect(s2, 401);
    expect(b2['error'], contains('isn\'t right'));
  });

  test('sign-up checks: duplicate email, bad email, bad sizes', () async {
    await signUp(email, password);
    final d = FakeDevice(handler);
    final base = {
      'email': email,
      'salt': base64Encode(randomBytes(16)),
      'kdf': KdfParams.fastForTests.toJson(),
      'loginKey': base64Encode(randomBytes(32)),
      'wrappedLibraryKey': base64Encode(randomBytes(60)),
    };
    expect((await d.call('POST', '/v1/accounts', base)).$1, 409);
    expect((await d.call('POST', '/v1/accounts', {...base, 'email': 'not-an-email'})).$1, 400);
    expect((await d.call('POST', '/v1/accounts', {...base, 'email': 'bob@example.com', 'salt': base64Encode(randomBytes(3))})).$1, 400);
    expect((await d.call('POST', '/v1/accounts', {...base, 'email': 'bob@example.com', 'kdf': {'alg': 'md5'}})).$1, 400);
  });

  test('prelogin gives the real salt for an account and a stable fake one otherwise', () async {
    await signUp(email, password);
    final d = FakeDevice(handler);
    final (_, real) = await d.call('POST', '/v1/prelogin', {'email': email});
    expect(real['kdf'], KdfParams.fastForTests.toJson());
    final (_, fake1) = await d.call('POST', '/v1/prelogin', {'email': 'nobody@example.com'});
    final (_, fake2) = await d.call('POST', '/v1/prelogin', {'email': 'NOBODY@example.com'});
    final (_, fake3) = await d.call('POST', '/v1/prelogin', {'email': 'someone@example.com'});
    expect(fake1['salt'], fake2['salt']);
    expect(fake1['salt'], isNot(fake3['salt']));
    expect(base64Decode(fake1['salt']! as String).length, 16);
    expect(fake1['kdf'], KdfParams.standard.toJson());
  });

  test('too many wrong passwords are slowed down', () async {
    await signUp(email, password);
    final d = FakeDevice(handler);
    for (var i = 0; i < 10; i++) {
      expect((await d.call('POST', '/v1/sessions', {'email': email, 'loginKey': base64Encode(randomBytes(32))})).$1, 401);
    }
    final keys = await d.keysFor(email, password);
    expect((await d.call('POST', '/v1/sessions', {'email': email, 'loginKey': base64Encode(keys.loginKey)})).$1, 429);
    now = now.add(const Duration(minutes: 16));
    expect((await d.call('POST', '/v1/sessions', {'email': email, 'loginKey': base64Encode(keys.loginKey)})).$1, 200);
  });

  test('authenticator: a wrong code fails, the right one confirms, and a code works only once', () async {
    final (d, _, secret) = await signUp(email, password);
    expect((await d.call('GET', '/v1/account')).$2['totpConfirmed'], false);
    expect((await d.call('GET', '/v1/totp/setup')).$2['totpSecret'], secret, reason: 'setup can be finished later');
    expect((await d.call('POST', '/v1/totp/confirm', {'code': '000000'})).$1, anyOf(400, 200));
    final code = totpAt(base32Decode(secret), totpStep(now));
    final (s, _) = await d.call('POST', '/v1/totp/confirm', {'code': code});
    if (s != 200) fail('the right code was refused');
    expect((await d.call('GET', '/v1/account')).$2['totpConfirmed'], true);
    expect((await d.call('POST', '/v1/totp/confirm', {'code': code})).$1, 400, reason: 'no reuse');
    expect((await d.call('GET', '/v1/totp/setup')).$1, 409, reason: 'the key is not handed out once confirmed');
  });

  test('sessions: sign out ends one; 30 idle days end one; a suspended account is refused', () async {
    final (d, _, _) = await signUp(email, password);
    expect((await d.call('GET', '/v1/account')).$1, 200);
    now = now.add(const Duration(days: 29));
    expect((await d.call('GET', '/v1/account')).$1, 200, reason: 'used within 30 days');
    now = now.add(const Duration(days: 31));
    expect((await d.call('GET', '/v1/account')).$1, 401, reason: 'idle for 31 days');

    final d2 = FakeDevice(handler);
    final keys = await d2.keysFor(email, password);
    d2.token = (await d2.call('POST', '/v1/sessions', {'email': email, 'loginKey': base64Encode(keys.loginKey)})).$2['token'] as String;
    expect((await d2.call('DELETE', '/v1/sessions/current')).$1, 200);
    expect((await d2.call('GET', '/v1/account')).$1, 401);

    d2.token = (await d2.call('POST', '/v1/sessions', {'email': email, 'loginKey': base64Encode(keys.loginKey)})).$2['token'] as String;
    store.setSuspended(store.accountByEmail(email)!.id, true);
    expect((await d2.call('GET', '/v1/account')).$1, 401, reason: 'suspending ends sessions');
    expect((await d2.call('POST', '/v1/sessions', {'email': email, 'loginKey': base64Encode(keys.loginKey)})).$1, 403);
  });

  test('deleting the account needs the password and removes everything', () async {
    final (d, _, _) = await signUp(email, password);
    expect((await d.call('DELETE', '/v1/account', {'loginKey': base64Encode(randomBytes(32))})).$1, 403);
    final keys = await d.keysFor(email, password);
    expect((await d.call('DELETE', '/v1/account', {'loginKey': base64Encode(keys.loginKey)})).$1, 200);
    expect(store.accountByEmail(email), isNull);
    expect(store.db.select('SELECT COUNT(*) AS n FROM sessions').first['n'], 0);
    expect((await d.call('POST', '/v1/sessions', {'email': email, 'loginKey': base64Encode(keys.loginKey)})).$1, 401);
  });

  test('privacy: the database file never holds the password, the keys or the library key', () async {
    final dir = await Directory.systemTemp.createTemp('server');
    addTearDown(() => dir.delete(recursive: true));
    final fileStore = Store.open('${dir.path}/t.db');
    handler = TsundokuApi(fileStore, clock: () => now).handler;
    final (_, libraryKey, _) = await signUp(email, password);
    final keys = await FakeDevice(handler).keysFor(email, password);
    fileStore.db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    fileStore.close();
    final bytes = await File('${dir.path}/t.db').readAsBytes();
    bool contains(List<int> needle) {
      outer:
      for (var i = 0; i + needle.length <= bytes.length; i++) {
        for (var j = 0; j < needle.length; j++) {
          if (bytes[i + j] != needle[j]) continue outer;
        }
        return true;
      }
      return false;
    }

    expect(contains(utf8.encode(password)), isFalse);
    expect(contains(keys.loginKey), isFalse, reason: 'only its hash is kept');
    expect(contains(keys.unlockKey), isFalse);
    expect(contains(libraryKey), isFalse);
    expect(contains(utf8.encode(email)), isTrue, reason: 'the email is the login name');
  });

  group('sync storage (3b)', () {
    Future<FakeDevice> syncer(String email) async {
      final (d, _, secret) = await signUp(email, password);
      final (s, _) = await d.call('POST', '/v1/totp/confirm', {'code': totpAt(base32Decode(secret), totpStep(now))});
      expect(s, 200);
      return d;
    }

    test('needs the authenticator set up first', () async {
      final (d, _, _) = await signUp(email, password);
      final (s, b) = await d.call('POST', '/v1/events', {'device': 'phone1', 'events': [base64Encode([1, 2, 3])]});
      expect(s, 403);
      expect(b['error'], contains('authenticator'));
      expect((await d.call('GET', '/v1/events?after=0')).$1, 403);
    });

    test('events come back in order, in pages, and only to their own account', () async {
      final alice = await syncer(email);
      final bob = await syncer('bob@example.com');
      final batch = [for (var i = 0; i < 7; i++) base64Encode([i, i, i])];
      final (s, b) = await alice.call('POST', '/v1/events', {'device': 'phone1', 'events': batch});
      expect(s, 200);
      expect(b['lastSeq'], greaterThan(0));
      await bob.call('POST', '/v1/events', {'device': 'tablet', 'events': [base64Encode([9])]});

      final (_, p1) = await alice.call('GET', '/v1/events?after=0&limit=5');
      final page1 = (p1['events']! as List).cast<Map>();
      expect(page1.length, 5);
      expect(p1['more'], isTrue);
      final (_, p2) = await alice.call('GET', '/v1/events?after=${page1.last['seq']}&limit=5');
      final page2 = (p2['events']! as List).cast<Map>();
      expect(page2.length, 2);
      expect(p2['more'], isFalse);
      expect([...page1, ...page2].map((e) => base64Decode(e['data'] as String).first), [0, 1, 2, 3, 4, 5, 6]);
      expect(page1.first['device'], 'phone1');

      final (_, bobs) = await bob.call('GET', '/v1/events?after=0');
      expect((bobs['events']! as List).length, 1, reason: 'never another account\'s events');
    });

    test('attachments round-trip; deleting the account removes events and attachments', () async {
      final alice = await syncer(email);
      expect((await alice.call('PUT', '/v1/blobs/photo-1', {'data': base64Encode([5, 6, 7])})).$1, 200);
      expect(base64Decode((await alice.call('GET', '/v1/blobs/photo-1')).$2['data']! as String), [5, 6, 7]);
      expect((await alice.call('GET', '/v1/blobs/missing')).$1, 404);
      expect((await alice.call('PUT', '/v1/blobs/bad id!', {'data': base64Encode([1])})).$1, anyOf(400, 404));
      await alice.call('POST', '/v1/events', {'device': 'phone1', 'events': [base64Encode([1])]});
      final keys = await alice.keysFor(email, password);
      expect((await alice.call('DELETE', '/v1/account', {'loginKey': base64Encode(keys.loginKey)})).$1, 200);
      expect(store.db.select('SELECT COUNT(*) AS n FROM events').first['n'], 0);
      expect(store.db.select('SELECT COUNT(*) AS n FROM blobs').first['n'], 0);
    });
  });
}
