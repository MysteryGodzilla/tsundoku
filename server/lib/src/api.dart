/// The account API (docs/phase3-design.md, step 3a). JSON in and out; binary values are base64.
library;

import 'dart:convert';
import 'dart:io' show HttpConnectionInfo;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart';

import 'store.dart';

const serverVersion = '0.1.0';

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

  static const maxBody = 1024 * 1024;

  Handler get handler => const Pipeline().addMiddleware(_errors).addHandler(_router.call);

  late final Router _router = Router(notFoundHandler: (_) => _json(404, {'error': 'Not found'}))
    ..get('/v1/health', (Request r) => _json(200, {'ok': true, 'version': serverVersion}))
    ..post('/v1/prelogin', _prelogin)
    ..post('/v1/accounts', _signUp)
    ..post('/v1/totp/confirm', _confirmTotp)
    ..post('/v1/sessions', _signIn)
    ..delete('/v1/sessions/current', _signOut)
    ..get('/v1/account', _getAccount)
    ..delete('/v1/account', _deleteAccount);

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

  static Future<Map<String, Object?>> _body(Request r) async {
    final len = r.contentLength;
    if (len != null && len > maxBody) throw ApiError(413, 'Too big.');
    final bytes = <int>[];
    await for (final chunk in r.read()) {
      bytes.addAll(chunk);
      if (bytes.length > maxBody) throw ApiError(413, 'Too big.');
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

  Future<Response> _deleteAccount(Request r) async {
    final a = _auth(r);
    final loginKey = _b64(await _body(r), 'loginKey', exact: 32);
    if (!constantTimeEquals(utf8.encode(loginKeyHash(loginKey)), utf8.encode(a.loginHash))) {
      throw ApiError(401, 'That password isn\'t right.');
    }
    store.deleteAccount(a.id);
    return _json(200, {'deleted': true});
  }
}
