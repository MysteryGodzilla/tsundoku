import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart';

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
