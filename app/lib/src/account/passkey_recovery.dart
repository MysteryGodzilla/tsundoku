/// Passkey recovery (roadmap 3.1, docs/phase3-design.md): a passkey saved in her Google account
/// whose PRF secret only her fingerprint releases. The secret wraps the library key, so a new
/// phone can open the synced library after a password reset.
///
/// One project domain for every user: the server never checks the passkey, the app only uses its
/// secret on the device. Proven on her phone in Phase 0 (the same secret after a reinstall).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart' show randomBytes;

import 'account_service.dart' show AccountProblem;

/// The project domain that vouches for the app (its `assetlinks.json` lists the app's signing key).
const passkeyDomain = 'mysterygodzilla.github.io';

/// What the app keeps (on the server, unlocked) to ask for the same passkey and secret again.
class PasskeyDetails {
  PasskeyDetails({required this.credentialId, required this.prfSalt, required this.secret});
  final String credentialId;
  final Uint8List prfSalt;
  final Uint8List secret;
}

/// She closed the passkey sheet: nothing to report.
class PasskeyCancelled implements Exception {}

abstract interface class PasskeyRecovery {
  /// Saves a new passkey for this account and returns its secret. Null if this phone (or its
  /// password manager) can't give the app a secret, so a recovery code is needed instead.
  Future<PasskeyDetails?> create({required String accountId, required String email});

  /// Asks for the saved passkey (her fingerprint) and returns its secret.
  Future<Uint8List> secret({required String credentialId, required Uint8List prfSalt});
}

String _b64url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List _fromB64url(String s) => base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));

Uint8List? _prfFirst(Map<String?, Object?>? ext) {
  final prf = ext?['prf'];
  if (prf is! Map) return null;
  final results = prf['results'];
  if (results is! Map) return null;
  final first = results['first'];
  if (first is! String || first.isEmpty) return null;
  final b = _fromB64url(first);
  return b.length >= 32 ? b : null;
}

class DevicePasskeys implements PasskeyRecovery {
  DevicePasskeys();

  late final _auth = PasskeyAuthenticator();

  @override
  Future<PasskeyDetails?> create({required String accountId, required String email}) => _guard(() async {
        final salt = randomBytes(32);
        final res = await _auth.register(RegisterRequestType(
          challenge: _b64url(randomBytes(32)),
          relyingParty: RelyingPartyType(id: passkeyDomain, name: 'Tsundoku'),
          // The account id as the user handle, so saving again replaces the old passkey.
          user: UserType(displayName: 'Tsundoku library', name: email, id: _b64url(utf8.encode(accountId))),
          excludeCredentials: const [],
          authSelectionType: AuthenticatorSelectionType(
            authenticatorAttachment: 'platform',
            requireResidentKey: true,
            residentKey: 'required',
            userVerification: 'required',
          ),
          pubKeyCredParams: [PubKeyCredParamType(type: 'public-key', alg: -7), PubKeyCredParamType(type: 'public-key', alg: -257)],
          prf: _b64url(salt),
        ));
        // Some phones give the secret when the passkey is made; others only when it's used.
        final secret = _prfFirst(res.clientExtensionResults) ?? await _secret(res.id, salt);
        return secret == null ? null : PasskeyDetails(credentialId: res.id, prfSalt: salt, secret: secret);
      });

  @override
  Future<Uint8List> secret({required String credentialId, required Uint8List prfSalt}) => _guard(() async {
        final s = await _secret(credentialId, prfSalt);
        if (s == null) throw AccountProblem('This phone can\'t open the library with a passkey. Use your recovery code instead.');
        return s;
      });

  Future<Uint8List?> _secret(String credentialId, Uint8List salt) async {
    final res = await _auth.authenticate(AuthenticateRequestType(
      relyingPartyId: passkeyDomain,
      challenge: _b64url(randomBytes(32)),
      mediation: MediationType.Optional,
      preferImmediatelyAvailableCredentials: false,
      userVerification: 'required',
      allowCredentials: [CredentialType(type: 'public-key', id: credentialId, transports: const [])],
      prf: _b64url(salt),
    ));
    return _prfFirst(res.clientExtensionResults);
  }

  static Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on PasskeyAuthCancelledException {
      throw PasskeyCancelled();
    } on NoCredentialsAvailableException {
      throw AccountProblem('No Tsundoku passkey was found in the Google account on this phone.');
    } on DomainNotAssociatedException {
      throw AccountProblem('This copy of Tsundoku can\'t use passkeys. Use a recovery code instead.');
    } on AuthenticatorException {
      throw AccountProblem('The passkey didn\'t work. Try again, or use a recovery code.');
    }
  }
}
