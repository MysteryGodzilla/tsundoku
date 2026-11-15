/// The sync server's API (docs/phase3-design.md). JSON in and out; binary values are base64.
library;

import 'dart:convert';
import 'dart:io' show HttpConnectionInfo;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart';

import 'store.dart';

const serverVersion = '0.3.0';

class ApiError implements Exception {
  ApiError(this.status, this.message);
  final int status;
  final String message;
}

/// Counts failed sign-ins per email and per address in a sliding window.
class RateLimiter {
  RateLimiter({this.window = const Duration(minutes: 15), this.perEmail = 10, this.perAddress = 30});
  final Duration window;
  final int perEmail;
  final int perAddress;
  final _fails = <String, List<DateTime>>{};

  List<DateTime> _recent(String key, DateTime now) =>
      (_fails[key] ??= []) ..removeWhere((t) => now.difference(t) > window);

  bool blocked(String email, String address, DateTime now) =>
      _recent('e:$email', now).length >= perEmail || _recent('a:$address', now).length >= perAddress;

  void fail(String email, String address, DateTime now) {
    _recent('e:$email', now).add(now);
    _recent('a:$address', now).add(now);
  }
}

class TsundokuApi {
  TsundokuApi(this.store, {DateTime Function()? clock, this.sessionMaxIdle = const Duration(days: 30), RateLimiter? limiter})
      : _clock = clock ?? DateTime.now,
        _limiter = limiter ?? RateLimiter();

  final Store store;
  final DateTime Function() _clock;
  final RateLimiter _limiter;

  /// A session not used for this long ends (the 30-day full sign-out rule).
  final Duration sessionMaxIdle;

  /// Password resets in progress: a short-lived token, given once the authenticator code is right.
  final _resets = <String, ({String accountId, DateTime expires})>{};
  static const resetTime = Duration(minutes: 15);

  static const maxBody = 1024 * 1024;

  /// Pushes of events and photo attachments may be bigger.
  static const maxSyncBody = 12 * 1024 * 1024;

  Handler get handler => const Pipeline().addMiddleware(_errors).addHandler(_router.call);

  late final Router _router = Router(notFoundHandler: (_) => _json(404, {'error': 'Not found'}))
    ..get('/v1/health', (Request r) => _json(200, {'ok': true, 'version': serverVersion}))
    ..post('/v1/prelogin', _prelogin)
    ..post('/v1/accounts', _signUp)
    ..get('/v1/totp/setup', _totpSetup)
    ..post('/v1/totp/confirm', _confirmTotp)
    ..post('/v1/sessions', _signIn)
    ..delete('/v1/sessions/current', _signOut)
    ..get('/v1/account', _getAccount)
    ..delete('/v1/account', _deleteAccount)
    ..post('/v1/events', _pushEvents)
    ..get('/v1/events', _pullEvents)
    ..put('/v1/blobs/<id>', _putBlob)
    ..get('/v1/blobs/<id>', _getBlob)
    ..get('/v1/recovery', _getRecovery)
    ..put('/v1/recovery', _putRecovery)
    ..post('/v1/reset/start', _resetStart)
    ..post('/v1/reset/finish', _resetFinish)
    ..post('/v1/account/password', _changePassword)
    ..post('/v1/account/email', _changeEmail);

  Middleware get _errors => (inner) => (request) async {
        try {
          return await inner(request);
        } on ApiError catch (e) {
          return _json(e.status, {'error': e.message});
        } on FormatException {
          return _json(400, {'error': 'That request wasn\'t understood.'});
        }
      };

  static Response _json(int status, Object body) =>
      Response(status, body: jsonEncode(body), headers: {'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store'});

  static Future<Map<String, Object?>> _body(Request r, {int max = maxBody}) async {
    final len = r.contentLength;
    if (len != null && len > max) throw ApiError(413, 'Too big.');
    final bytes = <int>[];
    await for (final chunk in r.read()) {
      bytes.addAll(chunk);
      if (bytes.length > max) throw ApiError(413, 'Too big.');
    }
    final j = jsonDecode(utf8.decode(bytes));
    if (j is! Map<String, Object?>) throw const FormatException();
    return j;
  }

  static String _str(Map<String, Object?> j, String k, {int max = 320}) {
    final v = j[k];
    if (v is! String || v.isEmpty || v.length > max) throw const FormatException();
    return v;
  }

  static Uint8List _b64(Map<String, Object?> j, String k, {int? exact, int max = 4096}) {
    final b = base64Decode(_str(j, k, max: max * 2));
    if ((exact != null && b.length != exact) || b.length > max) throw const FormatException();
    return b;
  }

  static String _tokenHash(String token) => base64Encode(c.sha256.convert(base64Url.decode(token)).bytes);

  String _address(Request r) =>
      (r.context['shelf.io.connection_info'] as HttpConnectionInfo?)?.remoteAddress.address ?? 'unknown';

  Account _auth(Request r) {
    final h = r.headers['authorization'] ?? '';
    if (!h.startsWith('Bearer ')) throw ApiError(401, 'Please sign in again.');
    final Account? a;
    try {
      a = store.useSession(_tokenHash(h.substring(7)), _clock(), sessionMaxIdle);
    } on FormatException {
      throw ApiError(401, 'Please sign in again.');
    }
    if (a == null) throw ApiError(401, 'Please sign in again.');
    if (a.suspended) throw ApiError(403, 'This account is suspended.');
    return a;
  }

  String _newSession(String accountId) {
    final token = base64Url.encode(randomBytes(32));
    store.insertSession(_tokenHash(token), accountId, _clock());
    return token;
  }

  bool _validEmail(String e) => e.length <= 254 && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e);

  Future<Response> _prelogin(Request r) async {
    final email = normaliseEmail(_str(await _body(r), 'email'));
    final a = store.accountByEmail(email);
    if (a != null) return _json(200, {'salt': base64Encode(a.salt), 'kdf': a.kdf.toJson()});
    // Unknown email: a stable fake answer, so this call can't be used to find out who has an account.
    final fake = c.Hmac(c.sha256, store.serverSecret).convert(utf8.encode(email)).bytes.sublist(0, 16);
    return _json(200, {'salt': base64Encode(fake), 'kdf': KdfParams.standard.toJson()});
  }

  Future<Response> _signUp(Request r) async {
    final j = await _body(r);
    final email = normaliseEmail(_str(j, 'email'));
    if (!_validEmail(email)) throw ApiError(400, 'That email address doesn\'t look right.');
    final salt = _b64(j, 'salt', exact: 16);
    final kdf = KdfParams.fromJson((j['kdf']! as Map).cast<String, Object?>());
    final loginKey = _b64(j, 'loginKey', exact: 32);
    final wrapped = _b64(j, 'wrappedLibraryKey', max: 1024);
    if (store.accountByEmail(email) != null) throw ApiError(409, 'There\'s already an account with that email.');
    final now = _clock();
    final totpSecret = randomBytes(20);
    final id = base64Url.encode(randomBytes(16)).replaceAll('=', '');
    store.insertAccount(Account(
      id: id,
      email: email,
      salt: salt,
      kdf: kdf,
      loginHash: loginKeyHash(loginKey),
      wrappedLibraryKey: wrapped,
      totpSecret: totpSecret,
      totpConfirmed: false,
      totpLastStep: 0,
      createdAt: now,
      lastSeenAt: now,
      suspended: false,
    ));
    return _json(201, {'token': _newSession(id), 'accountId': id, 'totpSecret': base32Encode(totpSecret)});
  }

  /// The authenticator key again, so setup can be finished later. Only while it's unconfirmed.
  Future<Response> _totpSetup(Request r) async {
    final a = _auth(r);
    if (a.totpConfirmed) throw ApiError(409, 'The authenticator app is already set up.');
    return _json(200, {'totpSecret': base32Encode(a.totpSecret)});
  }

  Future<Response> _confirmTotp(Request r) async {
    final a = _auth(r);
    final code = _str(await _body(r), 'code', max: 12);
    final step = totpMatch(a.totpSecret, code, _clock());
    if (step == null || step <= a.totpLastStep) throw ApiError(400, 'That code didn\'t work. Try the newest one.');
    store.confirmTotp(a.id, step);
    return _json(200, {'totpConfirmed': true});
  }

  Future<Response> _signIn(Request r) async {
    final j = await _body(r);
    final email = normaliseEmail(_str(j, 'email'));
    final loginKey = _b64(j, 'loginKey', exact: 32);
    final now = _clock();
    final address = _address(r);
    if (_limiter.blocked(email, address, now)) throw ApiError(429, 'Too many tries. Wait a few minutes and try again.');
    final a = store.accountByEmail(email);
    if (a == null || !constantTimeEquals(utf8.encode(loginKeyHash(loginKey)), utf8.encode(a.loginHash))) {
      _limiter.fail(email, address, now);
      throw ApiError(401, 'That email or password isn\'t right.');
    }
    if (a.suspended) throw ApiError(403, 'This account is suspended.');
    store.touchAccount(a.id, now);
    return _json(200, {
      'token': _newSession(a.id),
      'accountId': a.id,
      'wrappedLibraryKey': base64Encode(a.wrappedLibraryKey),
      'totpConfirmed': a.totpConfirmed,
    });
  }

  Future<Response> _signOut(Request r) async {
    _auth(r);
    store.deleteSession(_tokenHash(r.headers['authorization']!.substring(7)));
    return _json(200, {'ok': true});
  }

  Future<Response> _getAccount(Request r) async {
    final a = _auth(r);
    return _json(200, {'accountId': a.id, 'email': a.email, 'totpConfirmed': a.totpConfirmed, 'createdAt': a.createdAt.toUtc().toIso8601String()});
  }

  /// Sync needs the authenticator set up, so a forgotten password can be reset (design, 3b).
  Account _syncer(Request r) {
    final a = _auth(r);
    if (!a.totpConfirmed) throw ApiError(403, 'Finish setting up the authenticator app first.');
    return a;
  }

  static final _id = RegExp(r'^[A-Za-z0-9_-]{1,80}$');

  Future<Response> _pushEvents(Request r) async {
    final a = _syncer(r);
    final j = await _body(r, max: maxSyncBody);
    final device = _str(j, 'device', max: 80);
    if (!_id.hasMatch(device)) throw const FormatException();
    final raw = j['events'];
    if (raw is! List || raw.length > 1000) throw const FormatException();
    final events = [
      for (final e in raw)
        if (e is String) base64Decode(e) else throw const FormatException(),
    ];
    if (events.any((e) => e.isEmpty || e.length > 256 * 1024)) throw ApiError(413, 'Too big.');
    return _json(200, {'lastSeq': store.addEvents(a.id, device, events, _clock())});
  }

  Future<Response> _pullEvents(Request r) async {
    final a = _syncer(r);
    final after = int.tryParse(r.url.queryParameters['after'] ?? '0') ?? 0;
    final limit = (int.tryParse(r.url.queryParameters['limit'] ?? '500') ?? 500).clamp(1, 1000);
    final rows = store.eventsAfter(a.id, after, limit + 1);
    final page = rows.take(limit).toList();
    return _json(200, {
      'events': [for (final e in page) {'seq': e.seq, 'device': e.device, 'data': base64Encode(e.data)}],
      'more': rows.length > limit,
      'lastSeq': store.lastSeq(a.id),
    });
  }

  Future<Response> _putBlob(Request r, String id) async {
    final a = _syncer(r);
    if (!_id.hasMatch(id)) throw const FormatException();
    final data = _b64(await _body(r, max: maxSyncBody), 'data', max: 8 * 1024 * 1024);
    store.putBlob(a.id, id, data, _clock());
    return _json(200, {'ok': true});
  }

  Future<Response> _getBlob(Request r, String id) async {
    final a = _syncer(r);
    if (!_id.hasMatch(id)) throw const FormatException();
    final data = store.getBlob(a.id, id);
    if (data == null) throw ApiError(404, 'Not found');
    return _json(200, {'data': base64Encode(data)});
  }

  Future<Response> _deleteAccount(Request r) async {
    final a = _auth(r);
    final loginKey = _b64(await _body(r), 'loginKey', exact: 32);
    if (!constantTimeEquals(utf8.encode(loginKeyHash(loginKey)), utf8.encode(a.loginHash))) {
      // 403, not 401: a mistyped password mustn't look like an ended session.
      throw ApiError(403, 'That password isn\'t right.');
    }
    store.deleteAccount(a.id);
    return _json(200, {'deleted': true});
  }

  // ---------- Recovery, password reset, change password and email (step 3c) ----------

  /// An authenticator code, checked like a password: rate-limited, and never accepted twice.
  void _checkTotp(Account a, String code, Request r) {
    final now = _clock();
    final address = _address(r);
    if (_limiter.blocked(a.email, address, now)) throw ApiError(429, 'Too many tries. Wait a few minutes and try again.');
    final step = totpMatch(a.totpSecret, code, now);
    if (step == null || step <= a.totpLastStep) {
      _limiter.fail(a.email, address, now);
      throw ApiError(400, 'That code didn\'t work. Try the newest one.');
    }
    store.setTotpLastStep(a.id, step);
  }

  /// The new password's settings and keys, as the app sends them.
  ({Uint8List salt, KdfParams kdf, String loginHash, Uint8List wrapped}) _newPassword(Map<String, Object?> j) => (
        salt: _b64(j, 'salt', exact: 16),
        kdf: KdfParams.fromJson((j['kdf']! as Map).cast<String, Object?>()),
        loginHash: loginKeyHash(_b64(j, 'loginKey', exact: 32)),
        wrapped: _b64(j, 'wrappedLibraryKey', max: 1024),
      );

  Future<Response> _getRecovery(Request r) async {
    final a = _syncer(r);
    final rec = store.recovery(a.id);
    return _json(200, {'passkey': rec['passkey'] != null, 'code': rec['code'] != null});
  }

  /// Sets (or, with null, removes) the passkey and recovery-code copies of the library key. They're
  /// locked: only the passkey's secret or the code itself opens them, and the server has neither.
  Future<Response> _putRecovery(Request r) async {
    final a = _syncer(r);
    final j = await _body(r);
    final rec = store.recovery(a.id);
    if (j.containsKey('passkey')) {
      final p = j['passkey'];
      if (p == null) {
        rec.remove('passkey');
      } else if (p is Map<String, Object?>) {
        rec['passkey'] = {
          'credentialId': _str(p, 'credentialId', max: 1024),
          'prfSalt': base64Encode(_b64(p, 'prfSalt', exact: 32)),
          'wrapped': base64Encode(_b64(p, 'wrapped', max: 256)),
        };
      } else {
        throw const FormatException();
      }
    }
    if (j.containsKey('code')) {
      final c = j['code'];
      if (c == null) {
        rec.remove('code');
      } else if (c is Map<String, Object?>) {
        rec['code'] = {'wrapped': base64Encode(_b64(c, 'wrapped', max: 256))};
      } else {
        throw const FormatException();
      }
    }
    store.setRecovery(a.id, rec);
    return _json(200, {'passkey': rec['passkey'] != null, 'code': rec['code'] != null});
  }

  /// Forgotten password, step 1: email and authenticator code. Answers the same way whether or not
  /// the email has an account. Returns the locked recovery copies, so the app can unlock the library.
  Future<Response> _resetStart(Request r) async {
    final j = await _body(r);
    final email = normaliseEmail(_str(j, 'email'));
    final code = _str(j, 'code', max: 12);
    final now = _clock();
    final address = _address(r);
    if (_limiter.blocked(email, address, now)) throw ApiError(429, 'Too many tries. Wait a few minutes and try again.');
    final a = store.accountByEmail(email);
    final step = a == null || !a.totpConfirmed ? null : totpMatch(a.totpSecret, code, now);
    if (a == null || step == null || step <= a.totpLastStep) {
      _limiter.fail(email, address, now);
      throw ApiError(400, 'That email or code isn\'t right. Use the newest code from your authenticator app.');
    }
    if (a.suspended) throw ApiError(403, 'This account is suspended.');
    store.setTotpLastStep(a.id, step);
    _resets.removeWhere((_, v) => now.isAfter(v.expires));
    final token = base64Url.encode(randomBytes(32));
    _resets[token] = (accountId: a.id, expires: now.add(resetTime));
    return _json(200, {'resetToken': token, 'accountId': a.id, 'recovery': store.recovery(a.id)});
  }

  /// Forgotten password, step 2: the new password, wrapping the library key the app unlocked (or a
  /// new one, with `fresh`, when there was no way to unlock it). Signs out every other device.
  Future<Response> _resetFinish(Request r) async {
    final j = await _body(r);
    final token = _str(j, 'resetToken', max: 100);
    final pw = _newPassword(j);
    final fresh = j['fresh'] == true;
    final reset = _resets.remove(token);
    if (reset == null || _clock().isAfter(reset.expires)) throw ApiError(400, 'That took too long. Please start again.');
    final a = store.accountById(reset.accountId);
    if (a == null) throw ApiError(400, 'That took too long. Please start again.');
    if (fresh) store.wipeLibrary(a.id);
    store.setPassword(a.id, salt: pw.salt, kdf: pw.kdf, loginHash: pw.loginHash, wrappedLibraryKey: pw.wrapped);
    store.endSessions(a.id);
    store.touchAccount(a.id, _clock());
    return _json(200, {'token': _newSession(a.id), 'accountId': a.id, 'email': a.email, 'totpConfirmed': true});
  }

  /// Signed in: a new password, with the authenticator code (so it also works when the old one is
  /// forgotten). Other devices are signed out and sign in with the new password.
  Future<Response> _changePassword(Request r) async {
    final a = _syncer(r);
    final j = await _body(r);
    final pw = _newPassword(j);
    _checkTotp(a, _str(j, 'code', max: 12), r);
    store.setPassword(a.id, salt: pw.salt, kdf: pw.kdf, loginHash: pw.loginHash, wrappedLibraryKey: pw.wrapped);
    store.endSessions(a.id, keep: _tokenHash(r.headers['authorization']!.substring(7)));
    return _json(200, {'ok': true});
  }

  Future<Response> _changeEmail(Request r) async {
    final a = _syncer(r);
    final j = await _body(r);
    final email = normaliseEmail(_str(j, 'email'));
    if (!_validEmail(email)) throw ApiError(400, 'That email address doesn\'t look right.');
    final other = store.accountByEmail(email);
    if (other != null && other.id != a.id) throw ApiError(409, 'There\'s already an account with that email.');
    _checkTotp(a, _str(j, 'code', max: 12), r);
    store.setEmail(a.id, email);
    return _json(200, {'email': email});
  }
}
