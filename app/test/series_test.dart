import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku/main.dart';
import 'package:tsundoku/src/account/account_service.dart';
import 'package:tsundoku/src/app_scope.dart';
import 'package:tsundoku/src/backup/backup_format.dart';
import 'package:tsundoku/src/backup/backup_service.dart';
import 'package:tsundoku/src/books/library_repository.dart';
import 'package:tsundoku/src/books/models.dart';
import 'package:tsundoku/src/books/series_filler.dart';
import 'package:tsundoku/src/covers/cover_store.dart';
import 'package:tsundoku/src/db/database.dart';
import 'package:tsundoku/src/export/library_export.dart';
import 'package:tsundoku/src/settings/appearance.dart';
import 'package:tsundoku/src/settings/view_settings.dart';
import 'package:tsundoku/src/sources/book_source.dart';
import 'package:tsundoku/src/sources/open_library_source.dart';
import 'package:tsundoku/src/sync/sync_service.dart';
import 'package:tsundoku/src/ui/add_flow.dart';
import 'package:tsundoku/src/ui/widgets.dart';
import 'package:tsundoku_protocol/tsundoku_protocol.dart';
import 'package:tsundoku_server/tsundoku_server.dart';

import 'helpers.dart';

/// Open Library as it answered for Dune on 2026-11-21: works point at a series record by key, with
/// a position; editions carry a messy free-text series that must be ignored.
Map<String, Object?>? _openLibrary(String path) => switch (path) {
      '/isbn/9780441172719.json' => {
          'key': '/books/OL1M',
          'title': 'Dune',
          'works': [{'key': '/works/OL893414W'}],
          'authors': [{'key': '/authors/OL1A'}],
          'subjects': ['Science fiction'],
          'series': ['Ace Science Fiction, 17620'],
        },
      '/works/OL893414W.json' => {
          'series': [{'series': {'key': '/series/OL331367L'}, 'position': '1'}],
        },
      '/works/OL893516W.json' => {
          'series': [{'series': {'key': '/series/OL331367L'}, 'position': '3'}],
        },
      '/works/OL1W.json' => {'title': 'The Salt Orchard'},
      '/series/OL331367L.json' => {'name': 'Dune'},
      '/authors/OL1A.json' => {'name': 'Frank Herbert'},
      _ => null,
    };

MockClient _client(List<String> asked) => MockClient((req) async {
      asked.add(req.url.path);
      final body = _openLibrary(req.url.path);
      return body == null ? http.Response('', 404) : http.Response(jsonEncode(body), 200);
    });

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<AppServices> _services(AppDatabase db, BookLookup lookup, Directory tmp) async {
  final library = LibraryRepository(db);
  final covers = CoverStore(lookup, baseDir: () async => tmp);
  final account = AccountService(secrets: MemorySecretStore());
  return AppServices(
    library: library,
    lookup: lookup,
    covers: covers,
    appearance: await AppearanceSettings.load(),
    view: await ViewSettings.load(),
    backups: BackupService(library: library, covers: covers, prefs: await SharedPreferences.getInstance(), localDir: () async => tmp),
    account: account,
    sync: SyncService(library: library, covers: covers, account: account),
  );
}

void main() {
  test('labels: "Dune · Book 3", other positions as given, or just the name', () {
    expect(const BookSeries('Dune', '3').label, 'Dune · Book 3');
    expect(const BookSeries('Discworld', '0.5').label, 'Discworld · Book 0.5');
    expect(const BookSeries('Dune', 'Prequel').label, 'Dune · Prequel');
    expect(const BookSeries('Dune').label, 'Dune');
    expect(const BookSeries('Dune', ' ').label, 'Dune');
  });

  group('Open Library', () {
    test('an ISBN lookup brings the series from the work; the edition\'s free text is ignored', () async {
      final asked = <String>[];
      final ol = OpenLibrarySource(client: _client(asked));
      final c = (await ol.lookupIsbn('9780441172719'))!;
      expect(c.series, const BookSeries('Dune', '1'));
      expect(asked, contains('/series/OL331367L.json'));
    });

    test('a search result\'s series is asked by its work, and a series name is fetched once', () async {
      final asked = <String>[];
      final ol = OpenLibrarySource(client: _client(asked));
      expect(await ol.seriesFor(const [Identifier(Schemes.openLibraryWork, 'OL893414W')]), const BookSeries('Dune', '1'));
      expect(await ol.seriesFor(const [Identifier(Schemes.openLibraryWork, 'OL893516W')]), const BookSeries('Dune', '3'));
      expect(asked.where((p) => p.startsWith('/series/')).length, 1, reason: 'cached');
      expect(await ol.seriesFor(const [Identifier(Schemes.openLibraryWork, 'OL1W')]), isNull, reason: 'a work in no series');
      expect(await ol.seriesFor(const [Identifier(Schemes.isbn13, '9780441172719')]), isNull, reason: 'needs a work id');
    });
  });

  group('the library', () {
    late AppDatabase db;
    late LibraryRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = LibraryRepository(db);
    });
    tearDown(() => db.close());

    test('saved from a lookup, found by searching the series, kept in backups and the spreadsheet', () async {
      final id = await repo.addFromCandidate(
        const Candidate(sourceId: 'openlibrary', title: 'Children of Dune', authors: ['Frank Herbert'], series: BookSeries('Dune', '3')),
        OwnershipFormat.physical,
      );
      await repo.addManual(title: 'The Salt Orchard', authors: ['Mira Hale'], format: OwnershipFormat.kindle);
      final books = await repo.allBooks();
      expect((await repo.getBook(id))!.series, const BookSeries('Dune', '3'));
      expect(LibraryRepository.filter(books, 'dune').map((b) => b.title), ['Children of Dune']);

      final back = decodeBackup(encodeBackup(books, {}, createdAt: DateTime(2026, 11, 21))).books;
      expect(back.firstWhere((b) => b.id == id).series, const BookSeries('Dune', '3'));
      expect(back.firstWhere((b) => b.title == 'The Salt Orchard').series, isNull);

      final row = exportRows(books.where((b) => b.id == id).toList()).single;
      expect(row[exportHeaders.indexOf('Series')], 'Dune');
      expect(row[exportHeaders.indexOf('Number in series')], '3');
    });

    test('an older backup without series still restores', () async {
      final old = bookToJson((await repo.getBook(await repo.addManual(title: 'Carrie', format: OwnershipFormat.physical)))!)
        ..remove('series')
        ..remove('seriesPosition');
      expect(bookFromJson(old).series, isNull);
    });

    test('filling in: books from Open Library get their series once; hers are never overwritten', () async {
      final asked = <String>[];
      final lookup = BookLookup([OpenLibrarySource(client: _client(asked))]);
      final dune = await repo.addFromCandidate(
        const Candidate(sourceId: 'openlibrary', title: 'Dune', identifiers: [Identifier(Schemes.openLibraryWork, 'OL893414W')]),
        OwnershipFormat.physical,
      );
      final children = await repo.addFromCandidate(
        const Candidate(sourceId: 'openlibrary', title: 'Children of Dune', identifiers: [Identifier(Schemes.openLibraryWork, 'OL893516W')]),
        OwnershipFormat.kindle,
      );
      await repo.update(children, const BookChanges(series: 'My Dune shelf', seriesPosition: 'three'));
      final orchard = await repo.addFromCandidate(
        const Candidate(sourceId: 'openlibrary', title: 'The Salt Orchard', identifiers: [Identifier(Schemes.openLibraryWork, 'OL1W')]),
        OwnershipFormat.kindle,
      );
      await repo.addManual(title: 'Typed in', format: OwnershipFormat.physical);

      final filler = SeriesFiller(library: repo, lookup: lookup);
      expect(await filler.run(), 1);
      expect((await repo.getBook(dune))!.series, const BookSeries('Dune', '1'));
      expect((await repo.getBook(children))!.series, const BookSeries('My Dune shelf', 'three'), reason: 'hers stays');
      expect((await repo.getBook(orchard))!.series, isNull);

      asked.clear();
      await repo.update(dune, const BookChanges(clear: {'series', 'seriesPosition'}));
      expect(await filler.run(), 0);
      expect(asked, isEmpty, reason: 'each book is asked about once, and a series she cleared stays cleared');
    });

    test('filling in offline stops quietly and tries again later', () async {
      var online = false;
      final lookup = BookLookup([
        OpenLibrarySource(client: MockClient((req) async {
          if (!online) throw http.ClientException('offline');
          final body = _openLibrary(req.url.path);
          return body == null ? http.Response('', 404) : http.Response(jsonEncode(body), 200);
        })),
      ]);
      final dune = await repo.addFromCandidate(
        const Candidate(sourceId: 'openlibrary', title: 'Dune', identifiers: [Identifier(Schemes.openLibraryWork, 'OL893414W')]),
        OwnershipFormat.physical,
      );
      final filler = SeriesFiller(library: repo, lookup: lookup);
      expect(await filler.run(), 0);
      expect(await repo.getMeta(SeriesFiller.checkedKey(dune)), isNull, reason: 'not marked, so it is asked again');
      online = true;
      expect(await filler.run(), 1);
      expect((await repo.getBook(dune))!.series, const BookSeries('Dune', '1'));
    });
  });

  test('a series set on one phone reaches the other through sync', () async {
    final dir = await Directory.systemTemp.createTemp('series-sync');
    final store = Store.inMemory();
    final bridge = ServerBridge(TsundokuApi(store).handler);
    final a = Phone(bridge, dir, 'a'), b = Phone(bridge, dir, 'b');
    addTearDown(() async {
      await a.db.close();
      await b.db.close();
      store.close();
      await dir.delete(recursive: true);
    });
    final id = await a.library.addManual(title: 'Children of Dune', format: OwnershipFormat.physical);
    final secret = await a.account.signUp(serverUrl: 'https://sync.example.com', email: 'alice@example.com', password: 'correct horse battery');
    await a.account.confirmTotp(totpAt(base32Decode(secret), totpStep(DateTime.now())));
    await a.syncOk();
    await b.account.signIn(serverUrl: 'https://sync.example.com', email: 'alice@example.com', password: 'correct horse battery');
    await b.syncOk();
    expect((await b.library.getBook(id))!.series, isNull);

    await a.library.update(id, const BookChanges(series: 'Dune', seriesPosition: '3'));
    await a.syncOk();
    await b.syncOk();
    expect((await b.library.getBook(id))!.series, const BookSeries('Dune', '3'));
  });

  testWidgets('under the covers: the series line fits, even with large text', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340); // A phone 360 wide at 3x.
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final tmp = Directory.systemTemp.createTempSync('series_grid');
    final services = (await tester.runAsync(() => _services(db, BookLookup(const []), tmp)))!;
    await tester.runAsync(() async {
      final id = await services.library.addManual(
        title: 'Children of Dune',
        authors: ['Frank Herbert'],
        format: OwnershipFormat.physical,
        series: const BookSeries('The Dune Chronicles of Arrakis', '3'),
      );
      await services.library.update(id, const BookChanges(status: ReadingStatus.reading));
      await services.library.addManual(title: 'Carrie', authors: ['Stephen King'], format: OwnershipFormat.kindle);
    });
    await tester.pumpWidget(TsundokuApp(services: services));
    await _settle(tester);
    expect(find.text('The Dune Chronicles of Arrakis · Book 3'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'no overflow');

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
    tmp.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('on a normal phone the status bubble keeps its full size on the cover (0.6.0 had shrunk it)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1236, 2676); // A phone 412 wide at 3x.
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final tmp = Directory.systemTemp.createTempSync('bubble_size');
    final services = (await tester.runAsync(() => _services(db, BookLookup(const []), tmp)))!;
    await tester.runAsync(() async {
      final id = await services.library.addManual(title: 'Carrie', authors: ['Stephen King'], format: OwnershipFormat.physical);
      await services.library.update(id, const BookChanges(status: ReadingStatus.tbr));
    });
    await tester.pumpWidget(TsundokuApp(services: services));
    await _settle(tester);
    final onCover = tester.getSize(find.byType(StatusBubble));

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: StatusBubble(status: ReadingStatus.tbr)))));
    expect(onCover, tester.getSize(find.byType(StatusBubble)), reason: 'the same size as one drawn on its own');

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
    tmp.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a search result shows its series in the sheet and the book is saved with it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final tmp = Directory.systemTemp.createTempSync('series_sheet');
    final lookup = BookLookup([OpenLibrarySource(client: _client([]))]);
    final services = (await tester.runAsync(() => _services(db, lookup, tmp)))!;
    const result = Candidate(
      sourceId: 'openlibrary',
      title: 'Children of Dune',
      authors: ['Frank Herbert'],
      identifiers: [Identifier(Schemes.openLibraryWork, 'OL893516W')],
    );
    await tester.pumpWidget(AppScope(
      services: services,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(body: TextButton(onPressed: () => showCandidateSheet(context, result), child: const Text('Result stand-in'))),
        ),
      ),
    ));
    await tester.tap(find.text('Result stand-in'));
    await _settle(tester);
    expect(find.text('Dune · Book 3'), findsOneWidget);
    await tester.tap(find.text('Add to library'));
    await _settle(tester);
    final book = (await tester.runAsync(() => services.library.allBooks()))!.single;
    expect(book.series, const BookSeries('Dune', '3'));

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
    tmp.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
