/// Authenticator-app codes (TOTP, RFC 6238): 6 digits, 30-second steps, HMAC-SHA1, which is what
/// authenticator apps expect.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;

const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

String base32Encode(List<int> bytes) {
  final sb = StringBuffer();
  var buffer = 0, bits = 0;
  for (final b in bytes) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5) {
      sb.write(_alphabet[(buffer >> (bits - 5)) & 31]);
      bits -= 5;
    }
  }
  if (bits > 0) sb.write(_alphabet[(buffer << (5 - bits)) & 31]);
  return sb.toString();
}

Uint8List base32Decode(String s) {
  final clean = s.toUpperCase().replaceAll(RegExp(r'[\s=-]'), '');
  final out = <int>[];
  var buffer = 0, bits = 0;
  for (final ch in clean.split('')) {
    final v = _alphabet.indexOf(ch);
    if (v < 0) throw const FormatException('Not base32');
    buffer = (buffer << 5) | v;
    bits += 5;
    if (bits >= 8) {
      out.add((buffer >> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Uint8List.fromList(out);
}

/// The code for time step [step] (seconds since 1970 divided by 30).
String totpAt(List<int> secret, int step, {int digits = 6}) {
  final msg = ByteData(8)..setInt64(0, step);
  final h = c.Hmac(c.sha1, secret).convert(msg.buffer.asUint8List()).bytes;
  final o = h[h.length - 1] & 0x0f;
  final bin = ((h[o] & 0x7f) << 24) | (h[o + 1] << 16) | (h[o + 2] << 8) | h[o + 3];
  var mod = 1;
  for (var i = 0; i < digits; i++) {
    mod *= 10;
  }
  return (bin % mod).toString().padLeft(digits, '0');
}

int totpStep(DateTime now) => now.millisecondsSinceEpoch ~/ 1000 ~/ 30;

/// The step [code] matches (allowing one step either side for clock drift), or null.
int? totpMatch(List<int> secret, String code, DateTime now) {
  final want = code.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^\d{6}$').hasMatch(want)) return null;
  final s = totpStep(now);
  for (final step in [s, s - 1, s + 1]) {
    if (totpAt(secret, step) == want) return step;
  }
  return null;
}

/// The link authenticator apps open to add an account.
Uri otpauthUri({required String secretBase32, required String account, String issuer = 'Tsundoku'}) => Uri(
      scheme: 'otpauth',
      host: 'totp',
      path: '/$issuer:$account',
      queryParameters: {'secret': secretBase32, 'issuer': issuer, 'algorithm': 'SHA1', 'digits': '6', 'period': '30'},
    );
