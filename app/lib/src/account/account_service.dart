/// Accounts on the app side (docs/phase3-design.md). The password never leaves the phone: it's
/// stretched into a login key (sent) and an unlock key (kept) that opens the library key.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:tsundoku_protocol/tsundoku_protocol.dart';

/// Where the session and keys are kept: Android's secure storage on a phone, memory in tests.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> deleteAll();
}

class DeviceSecretStore implements SecretStore {
  const DeviceSecretStore();
  static const _s = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  @override
  Future<void> deleteAll() => _s.deleteAll();
}

class MemorySecretStore implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> deleteAll() async => values.clear();
}

/// A problem to show her, in plain words.
class AccountProblem implements Exception {
  AccountProblem(this.message, {this.signedOut = false});
  final String message;

  /// The server no longer knows this session (30 days unused, signed out elsewhere, suspended).
  final bool signedOut;
  @override
  String toString() => message;
}

class AccountState {
  const AccountState({required this.serverUrl, required this.email, required this.accountId, required this.totpConfirmed});
  final String serverUrl;
  final String email;
  final String accountId;
  final bool totpConfirmed;
}

/// Minimum password length. A long password matters more than odd characters.
const minPasswordLength = 10;

Uint8List _derive((String, Uint8List, KdfParams) a) => deriveMasterKey(a.$1, a.$2, a.$3);

class AccountService extends ChangeNotifier {
  AccountService({SecretStore? secrets, http.Client? client, this.kdf = KdfParams.standard})
      : _secrets = secrets ?? const DeviceSecretStore(),
        _http = client ?? http.Client();

  final SecretStore _secrets;
  final http.Client _http;

  /// Argon2id settings for new accounts (tests use cheaper ones).
  final KdfParams kdf;

  AccountState? _state;
  String? _token;
  Uint8List? _libraryKey;

  AccountState? get state => _state;
  bool get signedIn => _state != null;

  /// The key that encrypts her synced library (step 3b). Only in memory and secure storage.
  Uint8List? get libraryKey => _libraryKey;

  static const _kUrl = 'account.server', _kEmail = 'account.email', _kId = 'account.id';
  static const _kToken = 'account.token', _kLib = 'account.libraryKey', _kTotp = 'account.totpConfirmed';

  Future<void> load() async {
    final url = await _secrets.read(_kUrl);
    final token = await _secrets.read(_kToken);
    final lib = await _secrets.read(_kLib);
    if (url == null || token == null || lib == null) return;
    _state = AccountState(
      serverUrl: url,
      email: await _secrets.read(_kEmail) ?? '',
      accountId: await _secrets.read(_kId) ?? '',
      totpConfirmed: await _secrets.read(_kTotp) == 'true',
    );
    _token = token;
    _libraryKey = base64Decode(lib);
    notifyListeners();
  }

  Future<void> _save(AccountState s, String token, Uint8List libraryKey) async {
    await _secrets.write(_kUrl, s.serverUrl);
    await _secrets.write(_kEmail, s.email);
    await _secrets.write(_kId, s.accountId);
    await _secrets.write(_kTotp, '${s.totpConfirmed}');
    await _secrets.write(_kToken, token);
    await _secrets.write(_kLib, base64Encode(libraryKey));
    _state = s;
    _token = token;
    _libraryKey = libraryKey;
    notifyListeners();
  }

  /// Forget the account on this phone. Her library stays.
  Future<void> _forget() async {
    await _secrets.deleteAll();
    _state = null;
    _token = null;
    _libraryKey = null;
    notifyListeners();
  }

  static String cleanServerUrl(String url) {
    var u = url.trim();
    if (!u.contains('://')) u = 'https://$u';
    return u.replaceAll(RegExp(r'/+$'), '');
  }

  Future<Map<String, Object?>> _call(String method, String serverUrl, String path, {Map<String, Object?>? body, String? token}) async {
    final req = http.Request(method, Uri.parse('$serverUrl$path'))
      ..headers['content-type'] = 'application/json'
      ..headers.addAll({if (token != null) 'authorization': 'Bearer $token'});
    if (body != null) req.body = jsonEncode(body);
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 30)));
    } catch (_) {
      throw AccountProblem('The sync server can\'t be reached. Check the address and that you\'re online.');
    }
    Map<String, Object?> j;
    try {
      j = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, Object?>();
    } catch (_) {
      throw AccountProblem('That address doesn\'t look like a Tsundoku sync server.');
    }
    if (res.statusCode >= 400) {
      throw AccountProblem(j['error'] as String? ?? 'Something went wrong (${res.statusCode}).', signedOut: res.statusCode == 401 && token != null);
    }
    return j;
  }

  Future<AccountKeys> _keys(String password, List<int> salt, KdfParams p) async =>
      AccountKeys.fromMaster(await compute(_derive, (password, Uint8List.fromList(salt), p)));

  /// Creates the account. Returns the authenticator key to add to her authenticator app.
  Future<String> signUp({required String serverUrl, required String email, required String password}) async {
    if (password.length < minPasswordLength) throw AccountProblem('Use at least $minPasswordLength characters.');
    final url = cleanServerUrl(serverUrl);
    final salt = randomBytes(16);
    final keys = await _keys(password, salt, kdf);
    final libraryKey = randomBytes(32);
    final j = await _call('POST', url, '/v1/accounts', body: {
      'email': normaliseEmail(email),
      'salt': base64Encode(salt),
      'kdf': kdf.toJson(),
      'loginKey': base64Encode(keys.loginKey),
      'wrappedLibraryKey': base64Encode(await seal(keys.unlockKey, libraryKey)),
    });
    await _save(
      AccountState(serverUrl: url, email: normaliseEmail(email), accountId: j['accountId']! as String, totpConfirmed: false),
      j['token']! as String,
      libraryKey,
    );
    return j['totpSecret']! as String;
  }

  /// The authenticator key, while setup isn't finished.
  Future<String> totpSetupSecret() async {
    final s = _state!;
    final j = await _guard(() => _call('GET', s.serverUrl, '/v1/totp/setup', token: _token));
    return j['totpSecret']! as String;
  }

  Future<void> confirmTotp(String code) async {
    final s = _state!;
    await _guard(() => _call('POST', s.serverUrl, '/v1/totp/confirm', body: {'code': code.trim()}, token: _token));
    await _secrets.write(_kTotp, 'true');
    _state = AccountState(serverUrl: s.serverUrl, email: s.email, accountId: s.accountId, totpConfirmed: true);
    notifyListeners();
  }

  Future<void> signIn({required String serverUrl, required String email, required String password}) async {
    final url = cleanServerUrl(serverUrl);
    final pre = await _call('POST', url, '/v1/prelogin', body: {'email': normaliseEmail(email)});
    final keys = await _keys(
      password,
      base64Decode(pre['salt']! as String),
      KdfParams.fromJson((pre['kdf']! as Map).cast<String, Object?>()),
    );
    final j = await _call('POST', url, '/v1/sessions', body: {'email': normaliseEmail(email), 'loginKey': base64Encode(keys.loginKey)});
    final Uint8List libraryKey;
    try {
      libraryKey = await open(keys.unlockKey, base64Decode(j['wrappedLibraryKey']! as String));
    } on SealException {
      throw AccountProblem('That password opened the account but not the library. Please tell whoever runs the server.');
    }
    await _save(
      AccountState(serverUrl: url, email: normaliseEmail(email), accountId: j['accountId']! as String, totpConfirmed: j['totpConfirmed'] == true),
      j['token']! as String,
      libraryKey,
    );
  }

  /// Checks the session is still good and updates what the server says about the account.
  Future<void> refresh() async {
    final s = _state;
    if (s == null) return;
    final j = await _guard(() => _call('GET', s.serverUrl, '/v1/account', token: _token));
    final confirmed = j['totpConfirmed'] == true;
    if (confirmed != s.totpConfirmed) {
      await _secrets.write(_kTotp, '$confirmed');
      _state = AccountState(serverUrl: s.serverUrl, email: s.email, accountId: s.accountId, totpConfirmed: confirmed);
      notifyListeners();
    }
  }

  /// Signs out on this phone. Her library stays on the phone.
  Future<void> signOut() async {
    final s = _state;
    if (s == null) return;
    try {
      await _call('DELETE', s.serverUrl, '/v1/sessions/current', token: _token);
    } catch (_) {
      // Offline or already ended: forgetting it here is what matters.
    }
    await _forget();
  }

  /// Deletes the account and everything synced. Her library stays on this phone.
  Future<void> deleteAccount(String password) async {
    final s = _state!;
    final pre = await _call('POST', s.serverUrl, '/v1/prelogin', body: {'email': s.email});
    final keys = await _keys(password, base64Decode(pre['salt']! as String), KdfParams.fromJson((pre['kdf']! as Map).cast<String, Object?>()));
    await _guard(() => _call('DELETE', s.serverUrl, '/v1/account', body: {'loginKey': base64Encode(keys.loginKey)}, token: _token));
    await _forget();
  }

  /// If the server says the session has ended, forget it here too.
  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on AccountProblem catch (e) {
      if (e.signedOut) {
        await _forget();
        throw AccountProblem('You\'ve been signed out. Please sign in again.', signedOut: true);
      }
      rethrow;
    }
  }
}
