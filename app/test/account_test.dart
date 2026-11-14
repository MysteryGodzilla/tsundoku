import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:tsundoku/src/account/account_service.dart';
import 'package:tsundoku/src/account/app_lock.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart';
import 'package:tsundoku_server/tsundoku_server.dart';

/// Sends the app's HTTP requests straight into the real server code, in memory.
class ServerBridge extends http.BaseClient {
  ServerBridge(this.handler);
  final shelf.Handler handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    final res = await handler(shelf.Request(request.method, request.url, body: body, headers: request.headers));
    return http.StreamedResponse(res.read(), res.statusCode, headers: res.headers);
  }
}

class FakeAuth implements DeviceAuth {
  FakeAuth({this.supported = true});
  final bool supported;
  bool answer = true;
  int asked = 0;
  @override
  Future<bool> available() async => supported;
  @override
  Future<bool> confirm() async {
    asked++;
    return answer;
  }
}

void main() {
  const url = 'http://sync.example.com';
  const email = 'alice@example.com';
  const password = 'correct horse battery';
  late Store store;
  late ServerBridge bridge;
  late DateTime now;

  setUp(() {
    now = DateTime.now();
    store = Store.inMemory();
    bridge = ServerBridge(TsundokuApi(store, clock: () => now).handler);
  });
  tearDown(() => store.close());

  AccountService device([MemorySecretStore? secrets]) =>
      AccountService(secrets: secrets ?? MemorySecretStore(), client: bridge, kdf: KdfParams.fastForTests);

  test('creating an account signs in with a new library key; https is assumed', () async {
    final phone1 = device();
    await phone1.signUp(serverUrl: 'sync.example.com/', email: ' Alice@Example.com', password: password);
    expect(phone1.signedIn, isTrue);
    expect(phone1.state!.serverUrl, 'https://sync.example.com');
    expect(phone1.state!.email, email);
    expect(phone1.libraryKey!.length, 32);
    expect(phone1.state!.totpConfirmed, isFalse);
  });

  group('with an account', () {
    late AccountService phone1;
    late MemorySecretStore secrets1;
    late String secret;
    setUp(() async {
      secrets1 = MemorySecretStore();
      phone1 = device(secrets1);
      secret = await phone1.signUp(serverUrl: url, email: email, password: password);
    });

    test('authenticator setup can be finished later, and the right code confirms it', () async {
      expect(await phone1.totpSetupSecret(), secret);
      await phone1.confirmTotp(totpAt(base32Decode(secret), totpStep(DateTime.now())));
      expect(phone1.state!.totpConfirmed, isTrue);
    });

    test('a wrong authenticator code is refused without signing her out', () async {
      final right = totpAt(base32Decode(secret), totpStep(DateTime.now()));
      final wrong = right == '111111' ? '222222' : '111111';
      await expectLater(phone1.confirmTotp(wrong), throwsA(isA<AccountProblem>()));
      expect(phone1.signedIn, isTrue);
      expect(phone1.state!.totpConfirmed, isFalse);
    });

    test('a second phone signs in and gets the same library key; a wrong password is refused', () async {
      final phone2 = device();
      await phone2.signIn(serverUrl: url, email: 'ALICE@example.com', password: password);
      expect(phone2.libraryKey, phone1.libraryKey);
      final phone3 = device();
      await expectLater(
        phone3.signIn(serverUrl: url, email: email, password: 'not my password'),
        throwsA(isA<AccountProblem>().having((e) => e.message, 'message', contains('isn\'t right'))),
      );
      expect(phone3.signedIn, isFalse);
    });

    test('the account survives a restart (kept in secure storage)', () async {
      final again = device(secrets1);
      await again.load();
      expect(again.state!.email, email);
      expect(again.libraryKey, phone1.libraryKey);
      await again.refresh();
      expect(again.signedIn, isTrue);
    });

    test('sign out forgets the account here and ends the session', () async {
      await phone1.signOut();
      expect(phone1.signedIn, isFalse);
      expect(secrets1.values, isEmpty);
      expect(store.db.select('SELECT COUNT(*) AS n FROM sessions').first['n'], 0);
    });

    test('delete: a wrong password keeps everything; the right one deletes it', () async {
      await expectLater(phone1.deleteAccount('wrong password!!'), throwsA(isA<AccountProblem>()));
      expect(phone1.signedIn, isTrue, reason: 'a typo must not sign her out');
      await phone1.deleteAccount(password);
      expect(phone1.signedIn, isFalse);
      expect(store.accountByEmail(email), isNull);
    });

    test('a session ended on the server (30 days unused) signs her out here', () async {
      now = now.add(const Duration(days: 31));
      await expectLater(phone1.refresh(), throwsA(isA<AccountProblem>().having((e) => e.signedOut, 'signedOut', isTrue)));
      expect(phone1.signedIn, isFalse);
    });

    test('a short password is refused before anything is sent', () async {
      await expectLater(device().signUp(serverUrl: url, email: 'bob@example.com', password: 'short'), throwsA(isA<AccountProblem>()));
      expect(store.accountByEmail('bob@example.com'), isNull);
    });
  });

  group('app lock', () {
    var n = 0;
    Future<FakeAuth> pumpGate(WidgetTester tester, {required bool signedIn, required Duration away, bool supported = true}) async {
      SharedPreferences.setMockInitialValues({'lock.lastActive': DateTime.now().subtract(away).toIso8601String()});
      final account = device();
      if (signedIn) await tester.runAsync(() => account.signUp(serverUrl: url, email: 'reader${n++}@example.com', password: password));
      final auth = FakeAuth(supported: supported)..answer = false;
      await tester.pumpWidget(MaterialApp(
        home: AppLockGate(key: UniqueKey(), account: account, auth: auth, child: const Text('My library')),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      return auth;
    }

    testWidgets('locks after a day away and unlocks when the phone confirms it is her', (tester) async {
      final auth = await pumpGate(tester, signedIn: true, away: const Duration(days: 2));
      expect(find.text('Tsundoku is locked'), findsOneWidget);
      expect(auth.asked, 1, reason: 'it asks straight away');
      auth.answer = true;
      await tester.tap(find.text('Unlock'));
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(find.text('Tsundoku is locked'), findsNothing);
      expect(find.text('My library'), findsOneWidget);
    });

    testWidgets('no lock within a day, when signed out, or on a phone with no screen lock', (tester) async {
      await pumpGate(tester, signedIn: true, away: const Duration(hours: 20));
      expect(find.text('Tsundoku is locked'), findsNothing);
      await pumpGate(tester, signedIn: false, away: const Duration(days: 3));
      expect(find.text('Tsundoku is locked'), findsNothing);
      await pumpGate(tester, signedIn: true, away: const Duration(days: 3), supported: false);
      expect(find.text('Tsundoku is locked'), findsNothing);
    });
  });
}
