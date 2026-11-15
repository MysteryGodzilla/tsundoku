/// Shared by the step 3c tests: the real server code in memory, and simulated phones.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;
import 'package:tsundoku/src/account/account_service.dart';
import 'package:tsundoku/src/account/passkey_recovery.dart';
import 'package:tsundoku/src/books/library_repository.dart';
import 'package:tsundoku/src/covers/cover_store.dart';
import 'package:tsundoku/src/db/database.dart';
import 'package:tsundoku/src/sources/book_source.dart';
import 'package:tsundoku/src/sources/open_library_source.dart';
import 'package:tsundoku/src/sync/sync_service.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart';

/// Sends the app's requests straight into the real server code. It can play a server that only
/// speaks plain http (a home server), or one that's out of reach (away from home, offline).
class ServerBridge extends http.BaseClient {
  ServerBridge(this.handler, {this.httpsWorks = true});
  final shelf.Handler handler;
  bool httpsWorks;
  bool online = true;
  final seen = <Uri>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    seen.add(request.url);
    if (!online || (!httpsWorks && request.url.scheme == 'https')) throw http.ClientException('No route to host', request.url);
    final body = request is http.Request ? request.body : '';
    final res = await handler(shelf.Request(request.method, request.url.replace(scheme: 'http'), body: body, headers: request.headers));
    return http.StreamedResponse(res.read(), res.statusCode, headers: res.headers);
  }
}

/// A passkey that always gives the same secret, like a real one saved in her Google account.
class FakePasskeys implements PasskeyRecovery {
  FakePasskeys({this.prf = true});
  final bool prf;
  final prfSecret = randomBytes(32);
  int asked = 0;

  @override
  Future<PasskeyDetails?> create({required String accountId, required String email}) async {
    asked++;
    return prf ? PasskeyDetails(credentialId: 'cred-$accountId', prfSalt: randomBytes(32), secret: prfSecret) : null;
  }

  @override
  Future<Uint8List> secret({required String credentialId, required Uint8List prfSalt}) async {
    asked++;
    return prfSecret;
  }
}

/// One phone: its own library database, covers folder, account and sync.
class Phone {
  Phone(ServerBridge bridge, Directory dir, String name, {DateTime Function()? clock})
      : db = AppDatabase(NativeDatabase.memory()),
        account = AccountService(secrets: MemorySecretStore(), client: bridge, kdf: KdfParams.fastForTests) {
    library = LibraryRepository(db);
    covers = CoverStore(BookLookup([OpenLibrarySource()]), baseDir: () async => Directory('${dir.path}/$name'));
    sync = SyncService(library: library, covers: covers, account: account, clock: clock);
  }
  final AppDatabase db;
  final AccountService account;
  late final LibraryRepository library;
  late final CoverStore covers;
  late final SyncService sync;

  Future<LibraryBook> book(String title) async => (await library.allBooks()).firstWhere((b) => b.title == title);
  Future<Set<String>> titles() async => (await library.allBooks()).map((b) => b.title).toSet();

  Future<void> syncOk() async {
    final ok = await sync.syncNow();
    expect(ok, isTrue, reason: '${sync.problem} / ${sync.lastError}');
  }
}
