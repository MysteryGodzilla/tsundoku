import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku/main.dart';
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
import 'package:tsundoku/src/theme/palette.dart';
import 'package:tsundoku/src/ui/book_detail_screen.dart';

class _NoSource implements BookSource {
  @override
  String get id => 'none';
  @override
  String get name => 'None';
  @override
  Future<Candidate?> lookupIsbn(String isbn13) async => null;
  @override
  Future<List<Candidate>> search(String query) async => const [];
  @override
  Uri? coverUri(String ref, CoverSize size) => null;
}

/// Lets real async work (the database, files) finish between frames. pumpAndSettle can't, and
/// would wait forever on the loading spinner.
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
    backups: BackupService(
      library: library,
      covers: covers,
      prefs: await SharedPreferences.getInstance(),
      localDir: () async => Directory('${tmp.path}/backups'),
    ),
    account: account,
    sync: SyncService(library: library, covers: covers, account: account),
  );
}

void main() {
  testWidgets('empty library, then a book: grid, search with ALREADY OWNED, and the accent picker', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Streams must close at once, or the test's fake clock leaves them pending forever.
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final lookup = BookLookup([_NoSource()]);
    final tmp = Directory.systemTemp.createTempSync('app_test');
    final services = await _services(db, lookup, tmp);
    await tester.pumpWidget(TsundokuApp(services: services));
    await _settle(tester);
    expect(find.text('Your library is empty'), findsOneWidget);

    await tester.runAsync(() => services.library.addManual(title: 'The Salt Orchard', authors: ['Mira Hale'], format: OwnershipFormat.physical));
    await _settle(tester);
    expect(find.text('1 book'), findsOneWidget);
    expect(find.text('The Salt Orchard'), findsWidgets);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget, reason: 'Physical bubble on the cover');
    expect(find.text('Read'), findsNothing, reason: 'no status bubble until a status is set, and no filter chips');
    expect(find.byType(FilterChip), findsNothing, reason: 'every filter is in the Filters sheet (her choice)');

    final id = (await tester.runAsync(() => services.library.watchAll().first))!.single.id;
    await tester.runAsync(() => services.library.update(id, const BookChanges(status: ReadingStatus.read)));
    await _settle(tester);
    expect(find.text('Read'), findsOneWidget, reason: 'the status bubble on the cover');

    await tester.enterText(find.byType(TextField).first, 'orchard');
    await _settle(tester);
    expect(find.text('ALREADY OWNED'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'night circus');
    await _settle(tester);
    expect(find.text('Not in your library'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Heather'));
    await _settle(tester);
    expect(services.appearance.accent, Accent.heather);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
    tmp.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('every filter is in the Filters sheet: format, then status, then rating, genre and author', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final tmp = Directory.systemTemp.createTempSync('filters_test');
    final services = await _services(db, BookLookup([_NoSource()]), tmp);
    final repo = services.library;
    await tester.runAsync(() async {
      final a = await repo.addManual(title: 'Carrie', authors: ['Stephen King'], format: OwnershipFormat.kindle);
      await repo.update(a, const BookChanges(status: ReadingStatus.read));
      await repo.setGenres(a, ['Horror']);
      await repo.addManual(title: 'Misery', authors: ['Stephen King'], format: OwnershipFormat.physical);
      final c = await repo.addManual(title: 'The Salt Orchard', authors: ['Mira Hale'], format: OwnershipFormat.kindle);
      await repo.update(c, const BookChanges(status: ReadingStatus.tbr));
    });
    await tester.pumpWidget(TsundokuApp(services: services));
    await _settle(tester);
    expect(find.text('3 books'), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing, reason: 'no chips under the search bar');

    await tester.tap(find.text('Filters'));
    await _settle(tester);
    final headings = ['FORMAT', 'READING STATUS', 'RATING', 'GENRE', 'AUTHOR'];
    final ys = [for (final h in headings) tester.getTopLeft(find.text(h)).dy];
    expect(ys, [...ys]..sort(), reason: 'in the order she chose: $headings');

    await tester.tap(find.widgetWithText(FilterChip, 'Kindle'));
    await tester.pump();
    expect(find.text('Show 2 books'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'TBR'));
    await tester.pump();
    await tester.tap(find.text('Show 1 book'));
    await _settle(tester);
    expect(find.text('The Salt Orchard'), findsWidgets);
    expect(find.text('Carrie'), findsNothing);
    expect(find.text('2'), findsOneWidget, reason: 'the Filters badge counts both choices');

    await tester.tap(find.text('Filters'));
    await _settle(tester);
    await tester.tap(find.text('Clear all'));
    await tester.pump();
    await tester.tap(find.text('Show 3 books'));
    await _settle(tester);
    expect(find.text('Carrie'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
    tmp.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('the finished date shows only for Read ("Finished") or DNF ("Stopped"), and is kept', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final lookup = BookLookup([_NoSource()]);
    final tmp = Directory.systemTemp.createTempSync('detail_test');
    final services = await _services(db, lookup, tmp);
    final repo = services.library;
    final id = (await tester.runAsync(() => repo.addManual(title: 'Carrie', format: OwnershipFormat.physical)))!;
    await tester.runAsync(() => repo.update(id, const BookChanges(status: ReadingStatus.tbr)));
    await tester.pumpWidget(AppScope(services: services, child: MaterialApp(home: BookDetailScreen(bookId: id))));
    await _settle(tester);
    expect(find.text('FINISHED READING'), findsNothing);
    expect(find.text('STOPPED READING'), findsNothing);

    await tester.runAsync(() => repo.update(id, BookChanges(status: ReadingStatus.read, finishedOn: DateTime(2026, 11, 1))));
    await _settle(tester);
    expect(find.text('FINISHED READING'), findsOneWidget);
    expect(find.text('1 Nov 2026'), findsOneWidget);

    await tester.runAsync(() => repo.update(id, const BookChanges(status: ReadingStatus.reading)));
    await _settle(tester);
    expect(find.text('FINISHED READING'), findsNothing);
    expect((await tester.runAsync(() => repo.getBook(id)))!.row.finishedOn, DateTime(2026, 11, 1), reason: 'kept while hidden');

    await tester.runAsync(() => repo.update(id, const BookChanges(status: ReadingStatus.dnf)));
    await _settle(tester);
    expect(find.text('STOPPED READING'), findsOneWidget);
    expect(find.text('1 Nov 2026'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
    tmp.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
