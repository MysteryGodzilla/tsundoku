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
import 'package:tsundoku/src/ui/book_detail_screen.dart';
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

  Future<String> book(String title, OwnershipFormat f,
      {ReadingStatus? status, DateTime? bought, DateTime? finished, int? rating, List<String> authors = const [], List<String> genres = const []}) async {
    final id = await repo.addManual(title: title, format: f, authors: authors);
    await repo.update(id, BookChanges(status: status, purchasedOn: bought, finishedOn: finished, rating: rating));
    if (genres.isNotEmpty) await repo.setGenres(id, genres);
    return id;
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
    expect(s.anyStatus, isTrue);

    // Bought: A 29 days ago, B 89 days ago, C 364 days ago; D 365 days ago is just outside the
    // 12 months; G's date is in the future; E and F have none.
    expect([for (final p in StatsPeriod.values) s.bought[p]], [1, 2, 3]);
    expect((s.bought.dated, s.bought.undated), (5, 2));

    // Finished: only books marked Read (C's date is when she stopped, as DNF). A today, B 30 days
    // ago (so not in the last 30), F has no date.
    expect([for (final p in StatsPeriod.values) s.finished[p]], [1, 2, 2]);
    expect((s.finished.dated, s.finished.undated), (2, 1));

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

  test('pace, best month, oldest unread, ratings, authors and genres', () async {
    await book('Read 1', OwnershipFormat.physical, status: ReadingStatus.read, finished: DateTime(2026, 9, 1), rating: 5, authors: ['Alice Example'], genres: ['Fantasy']);
    await book('Read 2', OwnershipFormat.physical, status: ReadingStatus.read, finished: DateTime(2026, 9, 20), rating: 4, authors: ['alice  example', 'Bob Example'], genres: ['Fantasy', 'Mystery']);
    await book('Read 3', OwnershipFormat.kindle, status: ReadingStatus.read, finished: DateTime(2026, 10, 31), rating: 4, authors: ['Bob Example'], genres: ['Mystery']);
    await book('Read 4', OwnershipFormat.kindle, status: ReadingStatus.read, finished: DateTime(2026, 10, 1), authors: ['Carol Example'], genres: ['Romance']);
    await book('Future', OwnershipFormat.kindle, status: ReadingStatus.read, finished: DateTime(2026, 12, 25));
    await book('Gave up', OwnershipFormat.physical, status: ReadingStatus.dnf, bought: DateTime(2019, 1, 1), finished: DateTime(2026, 9, 2), authors: ['Alice Example'], genres: ['Fantasy']);
    await book('No status', OwnershipFormat.physical, bought: DateTime(2018, 5, 5));
    await book('Reading', OwnershipFormat.physical, status: ReadingStatus.reading, bought: DateTime(2020, 2, 2));
    await book('Pile B', OwnershipFormat.physical, status: ReadingStatus.tbr, bought: DateTime(2023, 3, 14), rating: 2);
    await book('Pile A', OwnershipFormat.kindle, status: ReadingStatus.tbr, bought: DateTime(2023, 3, 14));
    await book('Pile C', OwnershipFormat.physical, status: ReadingStatus.tbr, bought: DateTime(2024, 6, 1));
    final books = await repo.allBooks();
    final s = libraryStats(books, now: now);

    // Four finished dates up to today (the one in the future is left out): 1 Sep to 31 Oct is 60
    // days over three gaps.
    final pace = s.pace!;
    expect((pace.books, pace.averageDays, pace.first, pace.last), (4, 20.0, DateTime(2026, 9, 1), DateTime(2026, 10, 31)));
    // September and October both have two; the later month wins the tie.
    expect((s.bestMonth!.month, s.bestMonth!.count), (DateTime(2026, 10), 2));

    // Only TBR counts as unread (not DNF, Reading or no status). Same day: the title decides.
    expect(s.oldestUnread!.title, 'Pile A');
    expect(libraryStats(books, format: OwnershipFormat.physical, now: now).oldestUnread!.title, 'Pile B');

    final r = s.ratings!;
    expect((r.rated, r.average), (4, 15 / 4));
    expect(r.byStars, {5: 1, 4: 2, 3: 0, 2: 1, 1: 0});

    // Alice and Bob have read two each (Alice's DNF doesn't count; capitals and spaces don't
    // split a name); Alice owns three.
    // (Lists inside a record compare by identity, so each part on its own.)
    expect(s.mostRead!.names, ['Alice Example', 'Bob Example']);
    expect(s.mostRead!.count, 2);
    expect(s.mostOwned!.names, ['Alice Example']);
    expect(s.mostOwned!.count, 3);
    expect(s.topGenres, [('Fantasy', 3), ('Mystery', 2), ('Romance', 1)]);

    // Kindle only: one rated book, nobody with two, two finished dates.
    final kindle = libraryStats(books, format: OwnershipFormat.kindle, now: now);
    expect((kindle.ratings!.rated, kindle.ratings!.average), (1, 4.0));
    expect((kindle.mostRead, kindle.mostOwned), (null, null));
    expect((kindle.pace!.books, kindle.pace!.averageDays), (2, 30.0));
    expect((kindle.bestMonth!.month, kindle.bestMonth!.count), (DateTime(2026, 10), 2));
  });

  test('what isn\'t filled in comes back empty, so the page can hide it', () async {
    await book('A', OwnershipFormat.physical, authors: ['Alice Example']);
    await book('B', OwnershipFormat.physical, status: ReadingStatus.read, finished: DateTime(2026, 11, 1), authors: ['Bob Example']);
    final s = libraryStats(await repo.allBooks(), now: now);
    expect(s.bought.dated, 0, reason: 'no dates bought: no Bought card');
    expect(s.finished.dated, 1);
    expect(s.pace, isNull, reason: 'pace needs two finished dates');
    expect((s.bestMonth, s.oldestUnread, s.ratings, s.mostRead, s.mostOwned), (null, null, null, null, null));
    expect(s.topGenres, isEmpty);

    final empty = libraryStats(const [], now: now);
    expect((empty.total, empty.noStatus, empty.anyStatus, empty.bought.dated, empty.finished.dated), (0, 0, false, 0, 0));
    expect(empty.byStatus.values.every((n) => n == 0), isTrue);
    expect(libraryStats([for (final b in await repo.allBooks()) if (b.status == null) b], now: now).anyStatus, isFalse, reason: 'no statuses set: no status card');
  });

  test('how long ago', () {
    expect(howLongAgo(DateTime(2026, 11, 21, 9), now), 'today');
    expect(howLongAgo(DateTime(2026, 11, 20), now), 'yesterday');
    expect(howLongAgo(DateTime(2026, 10, 22), now), '30 days ago');
    expect(howLongAgo(DateTime(2026, 10, 21), now), 'a month ago');
    expect(howLongAgo(DateTime(2026, 5, 22), now), '5 months ago');
    expect(howLongAgo(DateTime(2025, 11, 22), now), '11 months ago');
    expect(howLongAgo(DateTime(2025, 11, 21), now), 'a year ago');
    expect(howLongAgo(DateTime(2023, 3, 14), now), '3 years ago');
  });

  testWidgets('from Settings: finished above bought, empty cards hidden, each format; fits a narrow phone with large text', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // 360 wide at 3x, and tall enough that every card is built (the order is checked by position).
    tester.view.physicalSize = const Size(1080, 12000);
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
      Future<void> add(String title, OwnershipFormat f, BookChanges c, {List<String> genres = const []}) async {
        final id = await library.addManual(title: title, format: f, authors: ['Alice Example']);
        await library.update(id, c);
        if (genres.isNotEmpty) await library.setGenres(id, genres);
      }

      await add('A', OwnershipFormat.kindle,
          BookChanges(status: ReadingStatus.read, purchasedOn: DateTime(2026, 11, 1), finishedOn: DateTime(2026, 11, 20), rating: 5),
          genres: ['Fantasy']);
      await add('The Long Wait', OwnershipFormat.physical, BookChanges(status: ReadingStatus.tbr, purchasedOn: DateTime(2024, 3, 14)));
      await add('C', OwnershipFormat.physical, const BookChanges());
      await add('D', OwnershipFormat.kindle, BookChanges(status: ReadingStatus.read, finishedOn: DateTime(2026, 10, 21), rating: 4),
          genres: ['Fantasy', 'Science fiction']);
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

    double top(String text) => tester.getTopLeft(find.text(text)).dy;

    expect(find.byType(StatsScreen), findsOneWidget);
    expect(find.text('4'), findsWidgets, reason: 'four books in all');
    expect(find.text('books'), findsOneWidget);
    for (final h in ['READING STATUS', 'FINISHED READING', 'BOUGHT', 'YOUR RATINGS', 'AUTHORS', 'TOP GENRES']) {
      expect(find.text(h), findsOneWidget, reason: h);
    }
    expect(top('READING STATUS') < top('FINISHED READING') && top('FINISHED READING') < top('BOUGHT'), isTrue,
        reason: 'finished reading comes before bought (her feedback on 0.7.0)');
    expect(find.text('Pace'), findsOneWidget);
    expect(find.text('30'), findsOneWidget, reason: '21 Oct to 20 Nov');
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('Most owned: 4 books'), findsOneWidget);
    expect(find.text('Most read: 2 books'), findsOneWidget);
    expect(find.text('Oldest unread'), findsOneWidget);
    expect(find.textContaining('14 Mar 2024'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'nothing overflows');

    // Physical: nothing finished, rated or with a genre, so only the total, status and Bought.
    await tester.tap(find.text('Physical'));
    await _settle(tester);
    expect(find.text('physical books'), findsOneWidget);
    for (final h in ['FINISHED READING', 'YOUR RATINGS', 'TOP GENRES']) {
      expect(find.text(h), findsNothing, reason: h);
    }
    expect(find.text('BOUGHT'), findsOneWidget);
    expect(find.text('Most owned: 2 books'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Kindle: A has a date bought but neither is TBR, so Bought shows with no oldest unread.
    await tester.tap(find.text('Kindle'));
    await _settle(tester);
    expect(find.text('Kindle books'), findsOneWidget);
    expect(find.text('BOUGHT'), findsOneWidget);
    expect(find.text('Oldest unread'), findsNothing);
    expect(find.text('Science fiction'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The oldest unread book opens its page.
    await tester.tap(find.text('Physical'));
    await _settle(tester);
    await tester.tap(find.text('Oldest unread'));
    await _settle(tester);
    expect(find.byType(BookDetailScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(wdb.close);
    tmp.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
