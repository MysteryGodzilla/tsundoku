import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku/src/account/account_service.dart';
import 'package:tsundoku/src/app_scope.dart';
import 'package:tsundoku/src/backup/backup_service.dart';
import 'package:tsundoku/src/books/library_repository.dart';
import 'package:tsundoku/src/books/models.dart';
import 'package:tsundoku/src/covers/cover_store.dart';
import 'package:tsundoku/src/db/database.dart';
import 'package:tsundoku/src/settings/appearance.dart';
import 'package:tsundoku/src/settings/view_settings.dart';
import 'package:tsundoku/src/sources/book_source.dart';
import 'package:tsundoku/src/sync/sync_service.dart';
import 'package:tsundoku/src/ui/add_flow.dart';

/// Knows no ISBN at all, but finds another edition of the book by title.
class _OtherEditionSource implements BookSource {
  @override
  String get id => 'fake';
  @override
  String get name => 'Fake';
  @override
  Future<Candidate?> lookupIsbn(String isbn13) async => null;
  @override
  Future<List<Candidate>> search(String query) async => query.toLowerCase().contains('orchard')
      ? const [
          Candidate(
            sourceId: 'fake',
            title: 'The Salt Orchard',
            authors: ['Mira Hale'],
            isbn13: '9781234567897',
            publisher: 'Example Press',
            identifiers: [Identifier(Schemes.openLibraryWork, 'OL1W')],
          ),
        ]
      : const [];
  @override
  Uri? coverUri(String ref, CoverSize size) => null;
}

/// Lets real async work (the database) finish between frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  const scanned = '9780306406157';

  testWidgets('a scan Open Library doesn\'t know steers to search; another edition is saved with the scanned ISBN', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final tmp = Directory.systemTemp.createTempSync('scan_not_found');
    final lookup = BookLookup([_OtherEditionSource()]);
    final services = (await tester.runAsync(() async {
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
    }))!;
    await tester.pumpWidget(AppScope(
      services: services,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () => lookupIsbnAndShow(context, scanned), child: const Text('Scan stand-in')),
          ),
        ),
      ),
    ));

    // The scan: not found, and the way on is a search, not entering it by hand.
    await tester.tap(find.text('Scan stand-in'));
    await _settle(tester);
    expect(find.text('Not found'), findsOneWidget);
    expect(find.textContaining('search for it by title or author'), findsOneWidget);
    expect(find.text('Enter by hand'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await _settle(tester);
    expect(find.text('Find a book'), findsOneWidget);
    expect(find.textContaining(scanned), findsOneWidget, reason: 'it says her ISBN will be kept');
    expect(find.textContaining('Enter it by hand'), findsNothing, reason: 'nothing to steer to before a search');

    // A search with no results: now entering it by hand is the way on.
    await tester.enterText(find.byType(TextField), 'no such book');
    await tester.pump(const Duration(milliseconds: 500));
    await _settle(tester);
    expect(find.textContaining('Nothing found'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Enter it by hand'), findsOneWidget);

    // Another edition is there: add it.
    await tester.enterText(find.byType(TextField), 'salt orchard');
    await tester.pump(const Duration(milliseconds: 500));
    await _settle(tester);
    expect(find.widgetWithText(FilledButton, 'Enter it by hand'), findsNothing);
    expect(find.text('Can\'t find it? Enter it by hand'), findsOneWidget, reason: 'still there, quietly, after the results');
    await tester.tap(find.text('The Salt Orchard').last);
    await _settle(tester);
    expect(find.text('ISBN $scanned'), findsOneWidget, reason: 'the sheet shows her copy\'s ISBN');
    await tester.tap(find.text('Add to library'));
    await _settle(tester);

    final book = (await tester.runAsync(() => services.library.allBooks()))!.single;
    expect(book.title, 'The Salt Orchard');
    expect(book.row.isbn13, scanned);
    expect(book.identifiers, containsAll(const [
      Identifier(Schemes.isbn13, scanned),
      Identifier(Schemes.isbn13, '9781234567897'),
      Identifier(Schemes.openLibraryWork, 'OL1W'),
    ]));

    // Scanning the same copy again finds it owned, without asking Open Library.
    final owned = await tester.runAsync(() => services.library.findOwned(const Candidate(sourceId: 'scan', title: '', isbn13: scanned)));
    expect(owned?.id, book.id);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
    tmp.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
