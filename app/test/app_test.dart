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
    account: AccountService(secrets: MemorySecretStore()),
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
    expect(find.text('Read'), findsOneWidget, reason: 'only the Read filter chip: no status bubble until a status is set');

    final id = (await tester.runAsync(() => services.library.watchAll().first))!.single.id;
    await tester.runAsync(() => services.library.update(id, const BookChanges(status: ReadingStatus.read)));
    await _settle(tester);
    expect(find.text('Read'), findsNWidgets(2), reason: 'the filter chip and the status bubble on the cover');

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
