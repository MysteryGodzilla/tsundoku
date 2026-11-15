/// Accounts on the app side (docs/phase3-design.md). The password never leaves the phone: it's
/// stretched into a login key (sent) and an unlock key (kept) that opens the library key.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:tsundoku_protocol/tsundoku_protocol.dart';

import 'server_address.dart' as address;

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
  AccountProblem(this.message, {this.signedOut = false, this.unreachable = false});
  final String message;

  /// The server no longer knows this session (30 days unused, signed out elsewhere, suspended).
  final bool signedOut;

  /// Nothing answered at the address (offline, or away from a home server).
  final bool unreachable;
  @override
  String toString() => message;
}

class AccountState {
  const AccountState({required this.serverUrl, required this.email, required this.accountId, required this.totpConfirmed});
  final String serverUrl;
  final String email;
  final String accountId;
  final bool totpConfirmed;

  AccountState copyWith({String? email, bool? totpConfirmed}) =>
      AccountState(serverUrl: serverUrl, email: email ?? this.email, accountId: accountId, totpConfirmed: totpConfirmed ?? this.totpConfirmed);
}

/// Which ways back into the library are set up (step 3c).
class RecoveryStatus {
  const RecoveryStatus({required this.passkey, required this.code});
  final bool passkey;
  final bool code;
  bool get any => passkey || code;
}

/// A password reset in progress: the authenticator code was right; the library still needs unlocking.
class PasswordReset {
  PasswordReset._({required this.serverUrl, required this.email, required this.accountId, required this.token, this.passkeyId, this.passkeySalt, this.passkeyWrapped, this.codeWrapped});
  final String serverUrl;
  final String email;
  final String accountId;
  final String token;
  final String? passkeyId;
  final Uint8List? passkeySalt;
  final Uint8List? passkeyWrapped;
  final Uint8List? codeWrapped;
  bool get hasPasskey => passkeyId != null && passkeySalt != null && passkeyWrapped != null;
  bool get hasCode => codeWrapped != null;
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

  /// Argon2id settings for new accounts and new passwords (tests use cheaper ones).
  final KdfParams kdf;

  AccountState? _state;
  String? _token;
  Uint8List? _libraryKey;

  AccountState? get state => _state;
  bool get signedIn => _state != null;

  /// The key that encrypts her synced library. Only in memory and secure storage.
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

  Future<void> _update(AccountState s) async {
    await _secrets.write(_kEmail, s.email);
    await _secrets.write(_kTotp, '${s.totpConfirmed}');
    _state = s;
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

  static String cleanServerUrl(String url) => address.cleanServerUrl(url);

  Future<Map<String, Object?>> _call(String method, String serverUrl, String path,
      {Map<String, Object?>? body, String? token, Duration timeout = const Duration(seconds: 30)}) async {
    final req = http.Request(method, Uri.parse('$serverUrl$path'))
      ..headers['content-type'] = 'application/json'
      ..headers.addAll({if (token != null) 'authorization': 'Bearer $token'});
    if (body != null) req.body = jsonEncode(body);
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(timeout));
    } catch (_) {
      throw AccountProblem('The sync server can\'t be reached. Check the address and that you\'re online.', unreachable: true);
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

  /// Finds the Tsundoku server at the address she typed and returns it in full. With no `http://`
  /// or `https://`, it tries https first, then plain http (how a home server usually runs). The
  /// screen warns her before using a plain http address.
  Future<String> checkServer(String typed) async {
    final url = address.cleanServerUrl(typed);
    try {
      await _health(url);
      return url;
    } on AccountProblem catch (e) {
      if (address.hasScheme(typed) || !e.unreachable) rethrow;
    }
    final plain = address.asPlainHttp(url);
    await _health(plain);
    return plain;
  }

  Future<void> _health(String url) async {
    final j = await _call('GET', url, '/v1/health', timeout: const Duration(seconds: 10));
    if (j['ok'] != true) throw AccountProblem('That address doesn\'t look like a Tsundoku sync server.');
  }

  /// A quick check that the server answers, so a sync away from a home server gives up quickly.
  Future<void> ping() async {
    final s = _state;
    if (s == null) throw AccountProblem('Not signed in.');
    await _health(s.serverUrl);
  }

  Future<AccountKeys> _keys(String password, List<int> salt, KdfParams p) async =>
      AccountKeys.fromMaster(await compute(_derive, (password, Uint8List.fromList(salt), p)));

  /// A new password's salt, settings, login key and the library key wrapped by it, ready to send.
  Future<Map<String, Object?>> _passwordBody(String password, Uint8List libraryKey) async {
    if (password.length < minPasswordLength) throw AccountProblem('Use at least $minPasswordLength characters.');
    final salt = randomBytes(16);
    final keys = await _keys(password, salt, kdf);
    return {
      'salt': base64Encode(salt),
      'kdf': kdf.toJson(),
      'loginKey': base64Encode(keys.loginKey),
      'wrappedLibraryKey': base64Encode(await seal(keys.unlockKey, libraryKey)),
    };
  }

  /// Creates the account. Returns the authenticator key to add to her authenticator app.
  Future<String> signUp({required String serverUrl, required String email, required String password}) async {
    final url = cleanServerUrl(serverUrl);
    final libraryKey = randomBytes(32);
    final body = await _passwordBody(password, libraryKey);
    final j = await _call('POST', url, '/v1/accounts', body: {'email': normaliseEmail(email), ...body});
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
    await _update(s.copyWith(totpConfirmed: true));
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
    final email = j['email'] as String? ?? s.email;
    if (confirmed != s.totpConfirmed || email != s.email) await _update(s.copyWith(email: email, totpConfirmed: confirmed));
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

  // ---------- Recovery, change password and email (step 3c) ----------

  Future<RecoveryStatus> recoveryStatus() async {
    final j = await authed('GET', '/v1/recovery');
    return RecoveryStatus(passkey: j['passkey'] == true, code: j['code'] == true);
  }

  /// Keeps a copy of the library key on the server, locked by the passkey's secret.
  Future<RecoveryStatus> savePasskeyRecovery({required String credentialId, required Uint8List prfSalt, required Uint8List secret}) async {
    final wrapped = await seal(passkeyWrapKey(secret), _libraryKey!);
    final j = await authed('PUT', '/v1/recovery', body: {
      'passkey': {'credentialId': credentialId, 'prfSalt': base64Encode(prfSalt), 'wrapped': base64Encode(wrapped)},
    });
    return RecoveryStatus(passkey: j['passkey'] == true, code: j['code'] == true);
  }

  /// Makes a new recovery code (replacing any old one) and keeps a copy of the library key on the
  /// server locked by it. The code is shown to her once and never stored.
  Future<String> makeRecoveryCode() async {
    final code = newRecoveryCode();
    final wrapped = await seal(recoveryWrapKey(parseRecoveryCode(code)!), _libraryKey!);
    await authed('PUT', '/v1/recovery', body: {'code': {'wrapped': base64Encode(wrapped)}});
    return code;
  }

  /// A new password, with an authenticator code. Works when the old password is forgotten too.
  /// Other devices are signed out and sign in again with the new one.
  Future<void> changePassword({required String code, required String newPassword}) async {
    final body = await _passwordBody(newPassword, _libraryKey!);
    await authed('POST', '/v1/account/password', body: {...body, 'code': code.trim()});
  }

  Future<void> changeEmail({required String email, required String code}) async {
    final j = await authed('POST', '/v1/account/email', body: {'email': normaliseEmail(email), 'code': code.trim()});
    await _update(_state!.copyWith(email: j['email'] as String? ?? normaliseEmail(email)));
  }

  /// Forgotten password, step 1: email and authenticator code (not signed in).
  Future<PasswordReset> startReset({required String serverUrl, required String email, required String code}) async {
    final url = cleanServerUrl(serverUrl);
    final j = await _call('POST', url, '/v1/reset/start', body: {'email': normaliseEmail(email), 'code': code.trim()});
    final rec = (j['recovery'] as Map? ?? const {}).cast<String, Object?>();
    final p = (rec['passkey'] as Map?)?.cast<String, Object?>();
    final c = (rec['code'] as Map?)?.cast<String, Object?>();
    return PasswordReset._(
      serverUrl: url,
      email: normaliseEmail(email),
      accountId: j['accountId']! as String,
      token: j['resetToken']! as String,
      passkeyId: p?['credentialId'] as String?,
      passkeySalt: p == null ? null : base64Decode(p['prfSalt']! as String),
      passkeyWrapped: p == null ? null : base64Decode(p['wrapped']! as String),
      codeWrapped: c == null ? null : base64Decode(c['wrapped']! as String),
    );
  }

  /// Step 2, with the recovery code she kept.
  Future<Uint8List> unlockWithCode(PasswordReset r, String code) async {
    final bytes = parseRecoveryCode(code);
    if (bytes == null) throw AccountProblem('That isn\'t a whole recovery code. It has 24 letters and numbers.');
    try {
      return await open(recoveryWrapKey(bytes), r.codeWrapped!);
    } on SealException {
      throw AccountProblem('That recovery code didn\'t open the library. Check it and try again.');
    }
  }

  /// Step 2, with the secret her passkey gave.
  Future<Uint8List> unlockWithPasskey(PasswordReset r, Uint8List secret) async {
    try {
      return await open(passkeyWrapKey(secret), r.passkeyWrapped!);
    } on SealException {
      throw AccountProblem('That passkey didn\'t open the library. Try your recovery code.');
    }
  }

  /// Step 3: the new password. With [libraryKey] null the synced library starts again from this
  /// phone's books (there was no way to unlock the old one). Signs in here; other devices are
  /// signed out.
  Future<void> finishReset(PasswordReset r, {required String newPassword, Uint8List? libraryKey}) async {
    final key = libraryKey ?? randomBytes(32);
    final body = await _passwordBody(newPassword, key);
    final j = await _call('POST', r.serverUrl, '/v1/reset/finish', body: {'resetToken': r.token, 'fresh': libraryKey == null, ...body});
    await _save(
      AccountState(serverUrl: r.serverUrl, email: j['email'] as String? ?? r.email, accountId: j['accountId']! as String, totpConfirmed: true),
      j['token']! as String,
      key,
    );
  }

  /// A signed-in call to the server, for sync. Signs out here if the server has ended the session.
  Future<Map<String, Object?>> authed(String method, String path, {Map<String, Object?>? body}) {
    final s = _state;
    if (s == null) throw AccountProblem('Not signed in.');
    return _guard(() => _call(method, s.serverUrl, path, body: body, token: _token));
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
