import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;
import 'package:tsundoku/src/account/account_service.dart';
import 'package:tsundoku/src/books/library_repository.dart';
import 'package:tsundoku/src/books/models.dart';
import 'package:tsundoku/src/covers/cover_store.dart';
import 'package:tsundoku/src/db/database.dart';
import 'package:tsundoku/src/sources/book_source.dart';
import 'package:tsundoku/src/sources/open_library_source.dart';
import 'package:tsundoku/src/sync/sync_service.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart';
import 'package:tsundoku_server/tsundoku_server.dart';

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

/// One phone: its own library database, covers folder, account and sync.
class Phone {
  Phone(ServerBridge bridge, Directory dir, String name)
      : db = AppDatabase(NativeDatabase.memory()),
        account = AccountService(secrets: MemorySecretStore(), client: bridge, kdf: KdfParams.fastForTests) {
    library = LibraryRepository(db);
    covers = CoverStore(BookLookup([OpenLibrarySource()]), baseDir: () async => Directory('${dir.path}/$name'));
    sync = SyncService(library: library, covers: covers, account: account);
  }
  final AppDatabase db;
  final AccountService account;
  late final LibraryRepository library;
  late final CoverStore covers;
  late final SyncService sync;

  Future<LibraryBook> book(String title) async => (await library.allBooks()).firstWhere((b) => b.title == title);

  Future<void> syncOk() async {
    final ok = await sync.syncNow();
    expect(ok, isTrue, reason: '${sync.problem} / ${sync.lastError}');
  }
}

void main() {
  const url = 'http://sync.example.com';
  const email = 'alice@example.com';
  const password = 'correct horse battery';
  late Directory dir;
  late Store store;
  late ServerBridge bridge;
  late Phone a, b;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sync');
    store = Store.open('${dir.path}/server.db');
    bridge = ServerBridge(TsundokuApi(store).handler);
    a = Phone(bridge, dir, 'a');
    b = Phone(bridge, dir, 'b');

    // Phone A: her existing library, then sync set up.
    await a.library.addManual(title: 'Carrie', authors: ['Stephen King'], format: OwnershipFormat.physical);
    final shining = await a.library.addManual(title: 'The Shining', authors: ['Stephen King'], format: OwnershipFormat.kindle);
    await a.library.update(shining, const BookChanges(status: ReadingStatus.reading, notes: 'Scary hotel'));
    await a.covers.saveOwnPhoto(shining, Uint8List.fromList(List.filled(400, 7)));
    await a.library.update(shining, const BookChanges(ownCover: true));
    final secret = await a.account.signUp(serverUrl: url, email: email, password: password);
    await a.account.confirmTotp(totpAt(base32Decode(secret), totpStep(DateTime.now())));
    await a.syncOk();

    // Phone B signs in and gets everything.
    await b.account.signIn(serverUrl: url, email: email, password: password);
    await b.syncOk();
  });

  tearDown(() async {
    await a.db.close();
    await b.db.close();
    store.close();
    await dir.delete(recursive: true);
  });

  test('the second phone gets the whole library, her photo included', () async {
    final books = await b.library.allBooks();
    expect(books.map((x) => x.title).toSet(), {'Carrie', 'The Shining'});
    final shining = await b.book('The Shining');
    expect(shining.status, ReadingStatus.reading);
    expect(shining.row.notes, 'Scary hotel');
    expect(shining.format, OwnershipFormat.kindle);
    expect(shining.hasOwnCover, isTrue);
    expect(await b.covers.ownPhotoBytes(shining.id), List.filled(400, 7));
    expect(b.sync.pending, 0);
  });

  test('offline edits to different fields on each phone both survive', () async {
    final carrieA = await a.book('Carrie');
    await a.library.update(carrieA.id, const BookChanges(rating: 5));
    await b.library.update(carrieA.id, const BookChanges(notes: 'Prom night'));
    await b.library.setGenres(carrieA.id, ['Horror']);
    await a.syncOk();
    await b.syncOk();
    await a.syncOk();
    for (final p in [a, b]) {
      final c = await p.book('Carrie');
      expect((c.row.rating, c.row.notes, c.genres.join(',')), (5, 'Prom night', 'Horror'));
    }
    expect(b.sync.decisions, 0);
  });

  test('the same field changed on both is asked on the phone that syncs second; either answer ends up everywhere', () async {
    final id = (await a.book('Carrie')).id;
    await a.library.update(id, const BookChanges(status: ReadingStatus.read));
    await b.library.update(id, const BookChanges(status: ReadingStatus.dnf));
    await a.syncOk();
    await b.syncOk();
    expect(a.sync.decisions, 0);
    expect(b.sync.decisions, 1);
    final d = (await b.sync.decisionsList()).single;
    expect((d.what, d.here, d.there), ('Reading status', 'Did not finish', 'Read'));

    // Keep the other phone's answer.
    await b.sync.decide(d.id, keepHere: false);
    await b.syncOk();
    await a.syncOk();
    expect((await a.book('Carrie')).status, ReadingStatus.read);
    expect((await b.book('Carrie')).status, ReadingStatus.read);

    // Again, and this time keep this phone's answer.
    await a.library.update(id, const BookChanges(rating: 2));
    await b.library.update(id, const BookChanges(rating: 4));
    await a.syncOk();
    await b.syncOk();
    final d2 = (await b.sync.decisionsList()).single;
    await b.sync.decide(d2.id, keepHere: true);
    await b.syncOk();
    await a.syncOk();
    expect((await a.book('Carrie')).row.rating, 4);
    expect((await b.book('Carrie')).row.rating, 4);
  });

  test('deleted on one phone while changed on the other: keeping it brings it back', () async {
    final id = (await a.book('Carrie')).id;
    await a.library.delete(id);
    await b.library.update(id, const BookChanges(notes: 'Keep this one'));
    await a.syncOk();
    await b.syncOk();
    final d = (await b.sync.decisionsList()).single;
    expect(d.kind, 'deletedThere');
    await b.sync.decide(d.id, keepHere: true);
    await b.syncOk();
    await a.syncOk();
    expect((await a.book('Carrie')).row.notes, 'Keep this one', reason: 'back on the phone that deleted it');
  });

  test('a deletion with no edits elsewhere just happens', () async {
    final id = (await a.book('Carrie')).id;
    await a.library.delete(id);
    await a.syncOk();
    await b.syncOk();
    expect((await b.library.allBooks()).map((x) => x.title), ['The Shining']);
  });

  test('privacy: the server database holds none of her titles, authors, notes or genres', () async {
    await b.library.setGenres((await b.book('Carrie')).id, ['Horror']);
    await b.syncOk();
    store.db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    final bytes = await File('${dir.path}/server.db').readAsBytes();
    bool has(String s) {
      for (final needle in [utf8.encode(s), [for (final u in s.codeUnits) ...[u & 0xff, u >> 8]]]) {
        outer:
        for (var i = 0; i + needle.length <= bytes.length; i++) {
          for (var j = 0; j < needle.length; j++) {
            if (bytes[i + j] != needle[j]) continue outer;
          }
          return true;
        }
      }
      return false;
    }

    for (final s in ['Carrie', 'The Shining', 'Stephen King', 'Scary hotel', 'Horror', 'reading', 'kindle']) {
      expect(has(s), isFalse, reason: '"$s" must not be readable on the server');
    }
    expect(store.db.select('SELECT COUNT(*) AS n FROM events').first['n'], greaterThan(0));
  });

  test('without the authenticator set up, sync waits and says why nothing happened', () async {
    final c = Phone(bridge, dir, 'c');
    await c.account.signUp(serverUrl: url, email: 'bob@example.com', password: password);
    expect(c.sync.ready, isFalse);
    expect(await c.sync.syncNow(), isFalse);
    await c.db.close();
  });
}
