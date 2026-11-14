/// AES-256-GCM sealing: the library key under the unlock key, and every synced change under the
/// library key. Output: version byte, 12-byte random nonce, ciphertext, 16-byte tag.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const _version = 1;
final _aes = AesGcm.with256bits();

Future<Uint8List> seal(List<int> key, List<int> plaintext, {List<int> aad = const []}) async {
  final box = await _aes.encrypt(plaintext, secretKey: SecretKey(key), aad: aad);
  return Uint8List.fromList([_version, ...box.nonce, ...box.cipherText, ...box.mac.bytes]);
}

/// Throws [SealException] if the key is wrong or the data was changed.
Future<Uint8List> open(List<int> key, List<int> sealed, {List<int> aad = const []}) async {
  if (sealed.length < 1 + 12 + 16 || sealed[0] != _version) throw const SealException();
  final nonce = sealed.sublist(1, 13);
  final mac = Mac(sealed.sublist(sealed.length - 16));
  final cipherText = sealed.sublist(13, sealed.length - 16);
  try {
    final plain = await _aes.decrypt(SecretBox(cipherText, nonce: nonce, mac: mac), secretKey: SecretKey(key), aad: aad);
    return Uint8List.fromList(plain);
  } on SecretBoxAuthenticationError {
    throw const SealException();
  }
}

class SealException implements Exception {
  const SealException();
  @override
  String toString() => 'Wrong key, or the data was changed';
}
