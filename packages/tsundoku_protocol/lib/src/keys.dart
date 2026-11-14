/// Key derivation (docs/phase3-design.md, "Keys").
///
/// password --Argon2id(salt)--> master key --HKDF "login"--> login key (the server's only proof)
///                                         --HKDF "unlock"-> unlock key (wraps the library key)
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:hashlib/hashlib.dart' show Argon2, Argon2Type, Argon2Version;

/// Argon2id settings, stored with each account so they can be raised later.
class KdfParams {
  const KdfParams({required this.memoryKiB, required this.iterations, required this.parallelism});

  /// 64 MiB, 3 passes, 1 lane: OWASP's guidance allows trading memory for passes; this costs about a
  /// second on a mid-range phone and makes guessing a password from a stolen database expensive.
  static const standard = KdfParams(memoryKiB: 64 * 1024, iterations: 3, parallelism: 1);

  /// For tests only.
  static const fastForTests = KdfParams(memoryKiB: 256, iterations: 1, parallelism: 1);

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  Map<String, Object?> toJson() => {'alg': 'argon2id', 'm': memoryKiB, 't': iterations, 'p': parallelism};

  static KdfParams fromJson(Map<String, Object?> j) {
    if (j['alg'] != 'argon2id') throw const FormatException('Unknown key derivation');
    final p = KdfParams(memoryKiB: j['m']! as int, iterations: j['t']! as int, parallelism: j['p']! as int);
    if (p.memoryKiB < 8 || p.iterations < 1 || p.parallelism < 1 || p.memoryKiB > 1024 * 1024) {
      throw const FormatException('Unreasonable key derivation settings');
    }
    return p;
  }

  @override
  bool operator ==(Object other) =>
      other is KdfParams && other.memoryKiB == memoryKiB && other.iterations == iterations && other.parallelism == parallelism;
  @override
  int get hashCode => Object.hash(memoryKiB, iterations, parallelism);
}

final _rng = Random.secure();

Uint8List randomBytes(int n) => Uint8List.fromList(List<int>.generate(n, (_) => _rng.nextInt(256)));

/// Emails are compared lower-cased and trimmed.
String normaliseEmail(String email) => email.trim().toLowerCase();

/// The slow step. Run it off the main thread in the app (it takes about a second).
Uint8List deriveMasterKey(String password, List<int> salt, KdfParams p) => Uint8List.fromList(Argon2(
      type: Argon2Type.argon2id,
      version: Argon2Version.v13,
      memorySizeKB: p.memoryKiB,
      iterations: p.iterations,
      parallelism: p.parallelism,
      hashLength: 32,
      salt: salt,
    ).convert(utf8.encode(password)).bytes);

/// HKDF-SHA256 (RFC 5869).
Uint8List hkdfSha256(List<int> ikm, {List<int> salt = const [], required List<int> info, int length = 32}) {
  final prk = c.Hmac(c.sha256, salt.isEmpty ? List.filled(32, 0) : salt).convert(ikm).bytes;
  final out = <int>[];
  var t = <int>[];
  for (var i = 1; out.length < length; i++) {
    t = c.Hmac(c.sha256, prk).convert([...t, ...info, i]).bytes;
    out.addAll(t);
  }
  return Uint8List.fromList(out.sublist(0, length));
}

class AccountKeys {
  AccountKeys._(this.loginKey, this.unlockKey);

  /// Sent to the server at sign-in. The server keeps only its SHA-256.
  final Uint8List loginKey;

  /// Never leaves the device. Wraps the library key.
  final Uint8List unlockKey;

  factory AccountKeys.fromMaster(List<int> masterKey) => AccountKeys._(
        hkdfSha256(masterKey, info: utf8.encode('tsundoku/v1/login')),
        hkdfSha256(masterKey, info: utf8.encode('tsundoku/v1/unlock')),
      );
}

/// What the server stores for a login key.
String loginKeyHash(List<int> loginKey) => base64Encode(c.sha256.convert(loginKey).bytes);

/// Comparison that takes the same time whatever the input, for secrets.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
