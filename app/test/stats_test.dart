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
import 'package:tsundoku/src/books/stats.dart';
import 'package:tsundoku/src/covers/cover_store.dart';
import 'package:tsundoku/src/db/database.dart';
import 'package:tsundoku/src/settings/appearance.dart';
import 'package:tsundoku/src/settings/view_settings.dart';
import 'package:tsundoku/src/sources/book_source.dart';
import 'package:tsundoku/src/sync/sync_service.dart';
import 'package:tsundoku/src/ui/settings_screen.dart';
import 'package:tsundoku/src/ui/stats_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late AppDatabase db;
  late LibraryRepository repo;
  final now = DateTime(2026, 11, 21, 15);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LibraryRepository(db);
  });
  tearDown(() => db.close());

  Future<void> book(String title, OwnershipFormat f, {ReadingStatus? status, DateTime? bought, DateTime? finished}) async {
    final id = await repo.addManual(title: title, format: f);
    await repo.update(id, BookChanges(status: status, purchasedOn: bought, finishedOn: finished));
  }

  test('totals, each status, and books bought and finished in the last 30 days, 90 days and 12 months', () async {
    await book('A', OwnershipFormat.kindle, status: ReadingStatus.read, bought: DateTime(2026, 10, 23), finished: DateTime(2026, 11, 21));
    await book('B', OwnershipFormat.physical, status: ReadingStatus.read, bought: DateTime(2026, 8, 24), finished: DateTime(2026, 10, 22));
    await book('C', OwnershipFormat.physical, status: ReadingStatus.dnf, bought: DateTime(2025, 11, 22), finished: DateTime(2026, 11, 20));
    await book('D', OwnershipFormat.physical, status: ReadingStatus.reading, bought: DateTime(2025, 11, 21));
    await book('E', OwnershipFormat.kindle, status: ReadingStatus.tbr);
    await book('F', OwnershipFormat.physical, status: ReadingStatus.read);
    await book('G', OwnershipFormat.physical, bought: DateTime(2026, 12, 1));
    final books = await repo.allBooks();

    final s = libraryStats(books, now: now);
    expect(s.total, 7);
    expect(s.byStatus, {ReadingStatus.tbr: 1, ReadingStatus.reading: 1, ReadingStatus.read: 3, ReadingStatus.dnf: 1});
    expect(s.noStatus, 1);

    // Bought: A 29 days ago, B 89 days ago, C 364 days ago; D 365 days ago is just outside the
    // 12 months; G's date is in the future; E and F have none.
    expect([for (final p in StatsPeriod.values) s.bought[p]], [1, 2, 3]);
    expect(s.bought.undated, 2);

    // Finished: only books marked Read (C's date is when she stopped, as DNF). A today, B 30 days
    // ago (so not in the last 30), F has no date.
    expect([for (final p in StatsPeriod.values) s.finished[p]], [1, 2, 2]);
    expect(s.finished.undated, 1);

    final physical = libraryStats(books, format: OwnershipFormat.physical, now: now);
    expect(physical.total, 5);
    expect(physical.byStatus[ReadingStatus.read], 2);
    expect(physical.byStatus[ReadingStatus.tbr], 0);
    expect([for (final p in StatsPeriod.values) physical.finished[p]], [0, 1, 1]);

    final kindle = libraryStats(books, format: OwnershipFormat.kindle, now: now);
    expect(kindle.total, 2);
    expect([for (final p in StatsPeriod.values) kindle.bought[p]], [1, 1, 1]);
    expect(kindle.bought.undated, 1);
  });

  test('an empty library is all zeros', () {
    final s = libraryStats(const [], now: now);
    expect((s.total, s.noStatus, s.bought[StatsPeriod.year], s.finished.undated), (0, 0, 0, 0));
    expect(s.byStatus.values.every((n) => n == 0), isTrue);
  });

  testWidgets('from Settings: the numbers, and Kindle only; it fits a narrow phone with large text', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340); // 360 wide at 3x.
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final wdb = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    final tmp = Directory.systemTemp.createTempSync('stats_screen');
    final services = (await tester.runAsync(() async {
      final library = LibraryRepository(wdb);
      final covers = CoverStore(BookLookup(const []), baseDir: () async => tmp);
      final account = AccountService(secrets: MemorySecretStore());
      final a = await library.addManual(title: 'A', format: OwnershipFormat.kindle);
      await library.update(a, BookChanges(status: ReadingStatus.read, purchasedOn: DateTime(2026, 11, 1), finishedOn: DateTime(2026, 11, 20)));
      final b = await library.addManual(title: 'B', format: OwnershipFormat.physical);
      await library.update(b, const BookChanges(status: ReadingStatus.tbr));
      await library.addManual(title: 'C', format: OwnershipFormat.physical);
      return AppServices(
        library: library,
        lookup: BookLookup(const []),
        covers: covers,
        appearance: await AppearanceSettings.load(),
        view: await ViewSettings.load(),
        backups: BackupService(library: library, covers: covers, prefs: await SharedPreferences.getInstance(), localDir: () async => tmp),
        account: account,
        sync: SyncService(library: library, covers: covers, account: account),
      );
    }))!;
    await tester.pumpWidget(AppScope(services: services, child: const MaterialApp(home: SettingsScreen())));
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('Library stats'), 200);
    await tester.tap(find.text('Library stats'));
    await _settle(tester);

    expect(find.byType(StatsScreen), findsOneWidget);
    expect(find.text('3'), findsOneWidget, reason: 'three books in all');
    expect(find.text('books'), findsOneWidget);
    expect(find.textContaining('with no date bought'), findsOneWidget, reason: 'B and C have no date bought');
    expect(tester.takeException(), isNull, reason: 'nothing overflows');

    await tester.tap(find.text('Kindle'));
    await _settle(tester);
    expect(find.text('Kindle book'), findsOneWidget);
    expect(find.textContaining('with no date bought'), findsNothing, reason: 'the Kindle book has its date');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(wdb.close);
    tmp.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
