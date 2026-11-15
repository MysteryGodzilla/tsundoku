import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku/src/account/account_service.dart';
import 'package:tsundoku/src/account/server_address.dart';
import 'package:tsundoku/src/app_scope.dart';
import 'package:tsundoku/src/backup/backup_service.dart';
import 'package:tsundoku/src/books/library_repository.dart';
import 'package:tsundoku/src/books/models.dart';
import 'package:tsundoku/src/covers/cover_store.dart';
import 'package:tsundoku/src/db/database.dart';
import 'package:tsundoku/src/settings/appearance.dart';
import 'package:tsundoku/src/settings/view_settings.dart';
import 'package:tsundoku/src/sources/book_source.dart';
import 'package:tsundoku/src/sources/open_library_source.dart';
import 'package:tsundoku/src/sync/sync_service.dart';
import 'package:tsundoku/src/ui/account_screen.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart';
import 'package:tsundoku_server/tsundoku_server.dart';

import 'helpers.dart';

void main() {
  const email = 'alice@example.com';
  const password = 'correct horse battery';
  const home = 'http://10.0.0.20:8797';

  group('addresses', () {
    test('https is assumed; a typed scheme is kept', () {
      expect(cleanServerUrl(' books.example.com/ '), 'https://books.example.com');
      expect(cleanServerUrl('http://10.0.0.20:8797/'), home);
      expect(hasScheme('10.0.0.20:8797'), isFalse);
      expect(hasScheme('http://10.0.0.20:8797'), isTrue);
      expect(asPlainHttp('10.0.0.20:8797'), home);
      expect(isPlainHttp('10.0.0.20:8797'), isFalse, reason: 'no scheme means https until checked');
      expect(isPlainHttp(home), isTrue);
    });

    test('home network addresses are recognised; internet ones are not', () {
      for (final a in [
        '10.0.0.20:8797', '172.16.5.4', '172.31.0.1', '192.168.1.20:8797', '127.0.0.1:8797', 'localhost:8797',
        'nas:8797', 'nas.local', 'books.lan', 'box.home.arpa', 'http://[fd12:3456::1]:8797', 'http://[fe80::1]:8797', 'http://[::1]:8797',
      ]) {
        expect(isHomeNetworkUrl(a), isTrue, reason: a);
      }
      for (final a in ['books.example.com', '192.0.2.1:8797', '203.0.113.5', '172.32.0.1', '172.15.0.1', 'https://[2001:db8::1]:8797']) {
        expect(isHomeNetworkUrl(a), isFalse, reason: a);
      }
    });
  });

  group('with the server', () {
    late Store store;
    late ServerBridge bridge;
    late Directory dir;
    var serverOffset = Duration.zero;
    DateTime serverNow() => DateTime.now().add(serverOffset);

    /// The next authenticator code (each works once, so the server's clock moves on 30 seconds).
    String code(String secret) {
      serverOffset += const Duration(seconds: 30);
      return totpAt(base32Decode(secret), totpStep(serverNow()));
    }

    setUp(() async {
      serverOffset = Duration.zero;
      dir = await Directory.systemTemp.createTemp('recovery');
      store = Store.inMemory();
      bridge = ServerBridge(TsundokuApi(store, clock: serverNow).handler);
    });
    tearDown(() async {
      store.close();
      await dir.delete(recursive: true);
    });

    AccountService device() => AccountService(secrets: MemorySecretStore(), client: bridge, kdf: KdfParams.fastForTests);

    Future<(AccountService, String)> account({String url = 'https://sync.example.com'}) async {
      final phone = device();
      final secret = await phone.signUp(serverUrl: url, email: email, password: password);
      await phone.confirmTotp(code(secret));
      return (phone, secret);
    }

    group('finding the server', () {
      test('with no scheme: https first, then plain http, for a home server', () async {
        bridge.httpsWorks = false;
        expect(await device().checkServer('10.0.0.20:8797'), home);
        expect(bridge.seen.map((u) => u.scheme), ['https', 'http']);
      });

      test('an https server is used as is, and a typed https:// is never downgraded', () async {
        expect(await device().checkServer('sync.example.com'), 'https://sync.example.com');
        bridge.httpsWorks = false;
        await expectLater(device().checkServer('https://10.0.0.20:8797'), throwsA(isA<AccountProblem>().having((e) => e.unreachable, 'unreachable', isTrue)));
      });

      test('nothing answering says so plainly', () async {
        bridge.online = false;
        await expectLater(
          device().checkServer('10.0.0.20:8797'),
          throwsA(isA<AccountProblem>().having((e) => e.message, 'message', contains('can\'t be reached'))),
        );
      });
    });

    group('recovery and passwords', () {
      test('a recovery code lets a new phone set a new password and open the same library', () async {
        final (phone, secret) = await account();
        final code0 = await phone.makeRecoveryCode();
        expect(parseRecoveryCode(code0), isNotNull);
        expect((await phone.recoveryStatus()).code, isTrue);

        final newPhone = device();
        final reset = await newPhone.startReset(serverUrl: 'sync.example.com', email: 'Alice@Example.com', code: code(secret));
        expect((reset.hasCode, reset.hasPasskey), (true, false));
        await expectLater(newPhone.unlockWithCode(reset, newRecoveryCode()), throwsA(isA<AccountProblem>()));
        await expectLater(newPhone.unlockWithCode(reset, 'too short'), throwsA(isA<AccountProblem>()));
        final key = await newPhone.unlockWithCode(reset, code0.toLowerCase().replaceAll('-', ' '));
        expect(key, phone.libraryKey);
        await newPhone.finishReset(reset, newPassword: 'a brand new password', libraryKey: key);
        expect(newPhone.signedIn, isTrue);
        expect(newPhone.libraryKey, phone.libraryKey);
        expect(newPhone.state!.totpConfirmed, isTrue);

        // The old phone is signed out; the new password brings it back to the same library.
        await expectLater(phone.recoveryStatus(), throwsA(isA<AccountProblem>().having((e) => e.signedOut, 'signedOut', isTrue)));
        expect(phone.signedIn, isFalse);
        final again = device();
        await again.signIn(serverUrl: 'https://sync.example.com', email: email, password: 'a brand new password');
        expect(again.libraryKey, newPhone.libraryKey);
      });

      test('a passkey\'s secret opens the library on a new phone', () async {
        final passkeys = FakePasskeys();
        final (phone, secret) = await account();
        final d = (await passkeys.create(accountId: phone.state!.accountId, email: email))!;
        final status = await phone.savePasskeyRecovery(credentialId: d.credentialId, prfSalt: d.prfSalt, secret: d.secret);
        expect((status.passkey, status.code), (true, false));

        final newPhone = device();
        final reset = await newPhone.startReset(serverUrl: 'https://sync.example.com', email: email, code: code(secret));
        expect(reset.hasPasskey, isTrue);
        expect(reset.passkeyId, d.credentialId);
        final key = await newPhone.unlockWithPasskey(reset, await passkeys.secret(credentialId: reset.passkeyId!, prfSalt: reset.passkeySalt!));
        expect(key, phone.libraryKey);
        await expectLater(newPhone.unlockWithPasskey(reset, randomBytes(32)), throwsA(isA<AccountProblem>()));
      });

      test('with no way to unlock, starting again makes a new library key and empties the server', () async {
        final (phone, secret) = await account();
        await phone.authed('POST', '/v1/events', body: {'device': 'phone1', 'events': [base64Encode([1, 2, 3])]});
        final newPhone = device();
        final reset = await newPhone.startReset(serverUrl: 'https://sync.example.com', email: email, code: code(secret));
        expect((reset.hasCode, reset.hasPasskey), (false, false));
        await newPhone.finishReset(reset, newPassword: 'starting over again');
        expect(newPhone.libraryKey, isNot(phone.libraryKey));
        expect((await newPhone.authed('GET', '/v1/events?after=0'))['events'], isEmpty);
      });

      test('a wrong authenticator code is refused, and a short password is refused before anything is sent', () async {
        final (phone, secret) = await account();
        await expectLater(device().startReset(serverUrl: 'https://sync.example.com', email: email, code: '000000'), throwsA(isA<AccountProblem>()));
        final sent = bridge.seen.length;
        await expectLater(phone.changePassword(code: code(secret), newPassword: 'short'), throwsA(isA<AccountProblem>()));
        expect(bridge.seen.length, sent);
      });

      test('change password keeps the library key and signs other devices out', () async {
        final (phone, secret) = await account();
        final tablet = device();
        await tablet.signIn(serverUrl: 'https://sync.example.com', email: email, password: password);
        await phone.changePassword(code: code(secret), newPassword: 'a much better password');
        await phone.refresh();
        expect(phone.signedIn, isTrue);
        await expectLater(tablet.refresh(), throwsA(isA<AccountProblem>()));
        expect(tablet.signedIn, isFalse);
        final again = device();
        await again.signIn(serverUrl: 'https://sync.example.com', email: email, password: 'a much better password');
        expect(again.libraryKey, phone.libraryKey);
      });

      test('change email', () async {
        final (phone, secret) = await account();
        await phone.changeEmail(email: ' Alice@Example.org ', code: code(secret));
        expect(phone.state!.email, 'alice@example.org');
        final again = device();
        await again.signIn(serverUrl: 'https://sync.example.com', email: 'alice@example.org', password: password);
        expect(again.libraryKey, phone.libraryKey);
      });
    });

    group('sync', () {
      late Phone a, b;
      late String secret;
      var now = DateTime(2026, 11, 15, 9);

      Future<void> setUpPhones(String url) async {
        now = DateTime(2026, 11, 15, 9);
        a = Phone(bridge, dir, 'a', clock: () => now);
        b = Phone(bridge, dir, 'b', clock: () => now);
        await a.library.addManual(title: 'Carrie', authors: ['Stephen King'], format: OwnershipFormat.physical);
        await a.library.addManual(title: 'The Shining', authors: ['Stephen King'], format: OwnershipFormat.kindle);
        secret = await a.account.signUp(serverUrl: url, email: email, password: password);
        await a.account.confirmTotp(code(secret));
        await a.syncOk();
        await b.account.signIn(serverUrl: url, email: email, password: password);
        await b.syncOk();
      }

      tearDown(() async {
        await a.db.close();
        await b.db.close();
      });

      test('after starting again from one phone, the other signs in again and its books come back too', () async {
        await setUpPhones('https://sync.example.com');
        await b.library.addManual(title: 'Misery', authors: ['Stephen King'], format: OwnershipFormat.physical);
        await b.syncOk();

        // Phone A forgot the password and had no way to unlock: it starts the synced copy again.
        final reset = await a.account.startReset(serverUrl: 'https://sync.example.com', email: email, code: code(secret));
        await a.account.finishReset(reset, newPassword: 'starting over again');
        await a.syncOk();
        expect(await a.titles(), {'Carrie', 'The Shining'});

        // Phone B is signed out, signs in with the new password, and sends what only it had.
        expect(await b.sync.syncNow(), isFalse);
        expect(b.account.signedIn, isFalse);
        await b.account.signIn(serverUrl: 'https://sync.example.com', email: email, password: 'starting over again');
        await b.syncOk();
        await a.syncOk();
        for (final p in [a, b]) {
          expect(await p.titles(), {'Carrie', 'The Shining', 'Misery'});
          expect(p.sync.decisions, 0);
        }
      });

      test('a home server out of reach: changes wait, it gives up quickly, and only says so after a week', () async {
        await setUpPhones(home);
        expect(a.sync.homeServer, isTrue);
        bridge.online = false;
        await a.library.addManual(title: 'Misery', authors: ['Stephen King'], format: OwnershipFormat.physical);
        expect(await a.sync.syncNow(), isFalse);
        expect(a.sync.problem, contains('home sync server'));
        expect(a.sync.pending, greaterThan(0));
        now = now.add(const Duration(days: 2));
        expect(a.sync.problemPersists, isFalse, reason: 'a weekend away is normal');
        now = now.add(const Duration(days: 6));
        expect(a.sync.problemPersists, isTrue);

        // Home again: it catches up and the notice goes.
        bridge.online = true;
        await a.syncOk();
        await b.syncOk();
        expect(await b.titles(), contains('Misery'));
        expect(a.sync.problemPersists, isFalse);
      });

      test('an internet server is reported after a day, as before', () async {
        await setUpPhones('https://sync.example.com');
        expect(a.sync.homeServer, isFalse);
        bridge.online = false;
        expect(await a.sync.syncNow(), isFalse);
        expect(a.sync.problem, contains('can\'t be reached'));
        now = now.add(const Duration(hours: 25));
        expect(a.sync.problemPersists, isTrue);
      });

      test('a change that can\'t be opened is skipped and sync carries on', () async {
        await setUpPhones('https://sync.example.com');
        await b.account.authed('POST', '/v1/events', body: {'device': 'stranger', 'events': [base64Encode(randomBytes(60))]});
        await b.library.addManual(title: 'Misery', authors: ['Stephen King'], format: OwnershipFormat.physical);
        await b.syncOk();
        await a.syncOk();
        expect(a.sync.skipped, 1);
        expect(await a.titles(), contains('Misery'));
      });
    });

    testWidgets('a plain http home server asks first: cancelling stops, agreeing carries on', (tester) async {
      bridge.httpsWorks = false;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
      SharedPreferences.setMockInitialValues({});
      final services = await tester.runAsync(() async {
        final library = LibraryRepository(db);
        final covers = CoverStore(BookLookup([OpenLibrarySource()]), baseDir: () async => dir);
        final account = AccountService(secrets: MemorySecretStore(), client: bridge, kdf: KdfParams.fastForTests);
        return AppServices(
          library: library,
          lookup: BookLookup([OpenLibrarySource()]),
          covers: covers,
          appearance: await AppearanceSettings.load(),
          view: await ViewSettings.load(),
          backups: BackupService(library: library, covers: covers, prefs: await SharedPreferences.getInstance(), localDir: () async => dir),
          account: account,
          sync: SyncService(library: library, covers: covers, account: account),
          passkeys: FakePasskeys(),
        );
      });
      await tester.pumpWidget(AppScope(services: services!, child: const MaterialApp(home: AccountScreen())));

      Future<void> settle() async {
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tester.tap(find.text('Create account'));
      await tester.pump();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '10.0.0.20:8797');
      await tester.enterText(fields.at(1), email);
      await tester.enterText(fields.at(2), password);
      await tester.enterText(fields.at(3), password);
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await settle();
      expect(find.text('This server isn\'t secure'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle();
      expect(services.account.signedIn, isFalse);

      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await settle();
      final carryOn = find.widgetWithText(FilledButton, 'Carry on');
      expect(tester.widget<FilledButton>(carryOn).onPressed, isNull, reason: 'she has to agree first');
      await tester.tap(find.text('I understand the risks'));
      await tester.pump();
      await tester.tap(carryOn);
      await settle();
      expect(services.account.signedIn, isTrue);
      expect(services.account.state!.serverUrl, home);
      expect(find.text('Authenticator app'), findsOneWidget);
      await tester.runAsync(db.close);
    });
  });
}

