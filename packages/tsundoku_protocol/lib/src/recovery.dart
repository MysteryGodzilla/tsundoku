/// Ways back into a library on a new phone (docs/phase3-design.md, step 3c). Each one wraps the
/// same library key; the server only ever stores the wrapped (locked) copies.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;

import 'keys.dart';
import 'totp.dart';

/// Recovery codes are 15 random bytes (120 bits): 24 letters and digits in six groups of four.
/// That's far too many to guess, so they need no slow stretching like a password does.
const recoveryCodeBytes = 15;

/// A new recovery code, ready to show: `ABCD-EFGH-…`.
String newRecoveryCode() => formatRecoveryCode(randomBytes(recoveryCodeBytes));

String formatRecoveryCode(List<int> bytes) {
  final s = base32Encode(bytes);
  return [for (var i = 0; i < s.length; i += 4) s.substring(i, i + 4 > s.length ? s.length : i + 4)].join('-');
}

/// The code's bytes, or null if it isn't a whole code. Forgiving about spaces, dashes, case and
/// the look-alikes 0/O, 1/I and 8/B (the code only uses A–Z and 2–7).
Uint8List? parseRecoveryCode(String input) {
  final clean = input
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-_.]'), '')
      .replaceAll('0', 'O')
      .replaceAll('1', 'I')
      .replaceAll('8', 'B');
  if (clean.length != 24 || !RegExp(r'^[A-Z2-7]+$').hasMatch(clean)) return null;
  final b = base32Decode(clean);
  return b.length == recoveryCodeBytes ? b : null;
}

/// The key a recovery code wraps the library key with.
Uint8List recoveryWrapKey(List<int> codeBytes) => hkdfSha256(codeBytes, info: utf8.encode('tsundoku recovery code v1'));

/// The key a passkey's PRF secret wraps the library key with.
Uint8List passkeyWrapKey(List<int> prfSecret) => hkdfSha256(prfSecret, info: utf8.encode('tsundoku passkey v1'));

/// A short name for a library key, so a device can tell when the library was started again
/// (a reset without any way to unlock it) and sync from the beginning. Reveals nothing about the key.
String libraryKeyId(List<int> libraryKey) =>
    base64Url.encode(c.sha256.convert([...utf8.encode('tsundoku library id v1'), ...libraryKey]).bytes.sublist(0, 12));
