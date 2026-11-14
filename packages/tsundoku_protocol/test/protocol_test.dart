import 'dart:convert';

import 'package:convert/convert.dart' show hex;
import 'package:test/test.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart';

void main() {
  group('authenticator codes (RFC 6238, SHA-1 vectors, last 6 digits)', () {
    final secret = utf8.encode('12345678901234567890');
    test('known times', () {
      expect(totpAt(secret, 59 ~/ 30), '287082');
      expect(totpAt(secret, 1111111109 ~/ 30), '081804');
      expect(totpAt(secret, 1234567890 ~/ 30), '005924');
      expect(totpAt(secret, 2000000000 ~/ 30), '279037');
    });
    test('allows one step of clock drift either side, and rejects junk', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1234567890 * 1000);
      expect(totpMatch(secret, '005924', now), 1234567890 ~/ 30);
      expect(totpMatch(secret, totpAt(secret, 1234567890 ~/ 30 - 1), now), isNotNull);
      expect(totpMatch(secret, totpAt(secret, 1234567890 ~/ 30 + 2), now), isNull);
      expect(totpMatch(secret, '00592', now), isNull);
      expect(totpMatch(secret, 'abcdef', now), isNull);
    });
    test('base32 (RFC 4648) and the authenticator link', () {
      expect(base32Encode(utf8.encode('foobar')), 'MZXW6YTBOI');
      expect(utf8.decode(base32Decode('mzxw 6ytb oi')), 'foobar');
      final uri = otpauthUri(secretBase32: 'MZXW6YTBOI', account: 'alice@example.com');
      expect(uri.scheme, 'otpauth');
      expect(uri.host, 'totp');
      expect(uri.queryParameters['secret'], 'MZXW6YTBOI');
    });
  });

  test('HKDF-SHA256 matches RFC 5869 test case 1', () {
    final okm = hkdfSha256(
      List.filled(22, 0x0b),
      salt: hex.decode('000102030405060708090a0b0c'),
      info: hex.decode('f0f1f2f3f4f5f6f7f8f9'),
      length: 42,
    );
    expect(hex.encode(okm), '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865');
  });

  group('keys', () {
    test('the same password and salt give the same keys; login and unlock keys differ', () {
      final salt = utf8.encode('0123456789abcdef');
      final a = AccountKeys.fromMaster(deriveMasterKey('correct horse', salt, KdfParams.fastForTests));
      final b = AccountKeys.fromMaster(deriveMasterKey('correct horse', salt, KdfParams.fastForTests));
      final c = AccountKeys.fromMaster(deriveMasterKey('correct horse', utf8.encode('fedcba9876543210'), KdfParams.fastForTests));
      expect(a.loginKey, b.loginKey);
      expect(a.unlockKey, b.unlockKey);
      expect(a.loginKey, isNot(a.unlockKey));
      expect(a.loginKey, isNot(c.loginKey));
      expect(loginKeyHash(a.loginKey), loginKeyHash(b.loginKey));
    });

    test('settings round-trip and silly ones are refused', () {
      expect(KdfParams.fromJson(KdfParams.standard.toJson()), KdfParams.standard);
      expect(() => KdfParams.fromJson({'alg': 'md5'}), throwsFormatException);
      expect(() => KdfParams.fromJson({'alg': 'argon2id', 'm': 1, 't': 1, 'p': 1}), throwsFormatException);
    });

    test('the standard settings take a sensible time here (printed)', () {
      final sw = Stopwatch()..start();
      deriveMasterKey('a password', randomBytes(16), KdfParams.standard);
      // ignore: avoid_print
      print('Argon2id 64 MiB, 3 passes: ${sw.elapsedMilliseconds} ms on this computer');
      expect(sw.elapsed, lessThan(const Duration(seconds: 20)));
    });
  });

  group('sealing', () {
    test('round-trips, and a wrong key, other associated data or a changed byte are refused', () async {
      final key = randomBytes(32);
      final sealed = await seal(key, utf8.encode('The Salt Orchard'), aad: utf8.encode('account-1'));
      expect(utf8.decode(await open(key, sealed, aad: utf8.encode('account-1'))), 'The Salt Orchard');
      expect(() => open(randomBytes(32), sealed, aad: utf8.encode('account-1')), throwsA(isA<SealException>()));
      expect(() => open(key, sealed, aad: utf8.encode('account-2')), throwsA(isA<SealException>()));
      final changed = List<int>.of(sealed)..[20] ^= 1;
      expect(() => open(key, changed, aad: utf8.encode('account-1')), throwsA(isA<SealException>()));
      final again = await seal(key, utf8.encode('The Salt Orchard'), aad: utf8.encode('account-1'));
      expect(again, isNot(sealed), reason: 'a fresh nonce every time');
    });
  });
}
