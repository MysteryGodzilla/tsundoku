import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku/src/backup/backup_format.dart';
import 'package:tsundoku/src/backup/backup_service.dart';
import 'package:tsundoku/src/backup/backup_store.dart';
import 'package:tsundoku/src/books/library_repository.dart';
import 'package:tsundoku/src/books/library_view.dart';
import 'package:tsundoku/src/books/models.dart';
import 'package:tsundoku/src/covers/cover_store.dart';
import 'package:tsundoku/src/db/database.dart';
import 'package:tsundoku/src/export/library_export.dart';
import 'package:tsundoku/src/sources/book_source.dart';
import 'package:tsundoku/src/sources/open_library_source.dart';

void main() {
  late AppDatabase db;
  late LibraryRepository repo;
  late DateTime now;
  setUp(() {
    now = DateTime(2026, 11, 14, 9);
    db = AppDatabase(NativeDatabase.memory());
    repo = LibraryRepository(db, clock: () => now = now.add(const Duration(seconds: 1)));
  });
  tearDown(() => db.close());

  Future<String> add(String title, String author, {OwnershipFormat f = OwnershipFormat.physical, ReadingStatus? s, int? rating, List<String> genres = const []}) async {
    final id = await repo.addManual(title: title, authors: [author], format: f);
    await repo.update(id, BookChanges(status: s, rating: rating));
    if (genres.isNotEmpty) await repo.setGenres(id, genres);
    return id;
  }

  group('sort and filter', () {
    test('author order is by surname, and Reading comes first among the same author', () async {
      await add('Carrie', 'Stephen King', s: ReadingStatus.read);
      await add('Quiet Hours', 'Anaïs Laurent');
      await add('Pet Sematary', 'Stephen King', s: ReadingStatus.reading);
      await add('The Shining', 'Stephen King');
      await add('The End of Everything', 'Katie Mack');
      final books = await repo.allBooks();
      expect(applyView(books, SortOrder.author, LibraryFilter.none).map((b) => b.title),
          ['Pet Sematary', 'Carrie', 'The Shining', 'Quiet Hours', 'The End of Everything']);
    });

    test('title order ignores "The"; rating order puts unrated last; default pins Reading', () async {
      await add('The Shining', 'Stephen King', rating: 3);
      await add('Carrie', 'Stephen King', rating: 5);
      await add('Salt', 'Mira Hale', s: ReadingStatus.reading);
      final books = await repo.allBooks();
      expect(applyView(books, SortOrder.title, LibraryFilter.none).map((b) => b.title), ['Carrie', 'Salt', 'The Shining']);
      expect(applyView(books, SortOrder.rating, LibraryFilter.none).map((b) => b.title), ['Carrie', 'The Shining', 'Salt']);
      expect(applyView(books, SortOrder.recent, LibraryFilter.none).first.title, 'Salt');
    });

    test('filters: any within a group, all across groups', () async {
      await add('A', 'X Y', f: OwnershipFormat.kindle, s: ReadingStatus.reading, rating: 4, genres: ['Horror']);
      await add('B', 'X Y', f: OwnershipFormat.physical, s: ReadingStatus.reading, genres: ['Fantasy']);
      await add('C', 'Z W', f: OwnershipFormat.kindle, s: ReadingStatus.tbr, rating: 2);
      final books = await repo.allBooks();
      List<String> titles(LibraryFilter f) => applyView(books, SortOrder.title, f).map((b) => b.title).toList();
      expect(titles(const LibraryFilter(formats: {OwnershipFormat.kindle})), ['A', 'C']);
      expect(titles(const LibraryFilter(formats: {OwnershipFormat.kindle}, statuses: {ReadingStatus.reading})), ['A']);
      expect(titles(const LibraryFilter(statuses: {ReadingStatus.reading, ReadingStatus.tbr})), ['A', 'B', 'C']);
      expect(titles(const LibraryFilter(authors: {'X Y'})), ['A', 'B']);
      expect(titles(const LibraryFilter(genres: {'Fantasy', 'Horror'})), ['A', 'B']);
      expect(titles(const LibraryFilter(rating: AtLeast(3))), ['A']);
      expect(titles(const LibraryFilter(rating: NotRated())), ['B']);
      expect(const LibraryFilter(authors: {'X Y'}, rating: AtLeast(3)).sheetCount, 2);
    });
  });

  test('the spreadsheet is a valid xlsx with every book and escaped text', () async {
    final id = await add('Fish & Chips <deluxe>', 'Mira Hale', s: ReadingStatus.dnf, rating: 2, genres: ['Cooking']);
    await repo.update(id, BookChanges(notes: 'Line one\nline "two"', finishedOn: DateTime(2026, 11, 1)));
    final bytes = buildLibraryXlsx(await repo.allBooks());
    final zip = ZipDecoder().decodeBytes(bytes);
    for (final part in ['[Content_Types].xml', '_rels/.rels', 'xl/workbook.xml', 'xl/_rels/workbook.xml.rels', 'xl/styles.xml']) {
      expect(zip.findFile(part), isNotNull, reason: part);
    }
    final sheet = utf8.decode(zip.findFile('xl/worksheets/sheet1.xml')!.content);
    expect(sheet, contains('Fish &amp; Chips &lt;deluxe&gt;'));
    expect(sheet, contains('Did not finish'));
    expect(sheet, contains('2026-11-01'));
    expect(sheet, contains('<v>2</v>'));
    expect(sheet, contains('Date finished'));
  });

  group('backups', () {
    test('a backup round-trips every field and her photos; other files are refused', () async {
      final id = await add('Carrie', 'Stephen King', s: ReadingStatus.read, rating: 4, genres: ['Horror']);
      await repo.update(id, BookChanges(notes: 'Scary', purchasedOn: DateTime(2026, 9, 16), finishedOn: DateTime(2026, 10, 2), ownCover: true));
      final books = await repo.allBooks();
      final bytes = encodeBackup(books, {id: Uint8List.fromList([1, 2, 3])}, createdAt: DateTime(2026, 11, 14, 10));
      final back = decodeBackup(bytes);
      expect(back.createdAt, DateTime(2026, 11, 14, 10));
      expect(back.ownPhotos[id], [1, 2, 3]);
      expect(bookToJson(back.books.single), bookToJson(books.single));
      expect(() => decodeBackup(Uint8List.fromList(utf8.encode('not a zip'))), throwsFormatException);
      final newer = ZipEncoder().encodeBytes(Archive()
        ..addFile(ArchiveFile.bytes('library.json', utf8.encode(jsonEncode({'format': backupFormat, 'version': 99, 'books': []})))));
      expect(() => decodeBackup(newer), throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('newer version'))));
    });

    test('automatic: due once a day when something changed; keeps the newest; restore with a safety copy', () async {
      SharedPreferences.setMockInitialValues({});
      final tmp = await Directory.systemTemp.createTemp('backups');
      addTearDown(() => tmp.delete(recursive: true));
      var clock = DateTime(2026, 11, 14, 9);
      final covers = CoverStore(BookLookup([OpenLibrarySource()]), baseDir: () async => Directory('${tmp.path}/app'));
      final service = BackupService(
        library: repo,
        covers: covers,
        prefs: await SharedPreferences.getInstance(),
        localDir: () async => Directory('${tmp.path}/backups'),
        clock: () => clock,
      );
      Future<int> count() async => (await service.local.list()).length;

      await service.runIfDue();
      expect(await count(), 0, reason: 'empty library: nothing to back up');

      now = clock;
      final carrie = await add('Carrie', 'Stephen King');
      await covers.saveOwnPhoto(carrie, Uint8List.fromList(List.filled(10, 9)));
      await repo.update(carrie, const BookChanges(ownCover: true));
      clock = clock.add(const Duration(minutes: 5));
      await service.runIfDue();
      expect(await count(), 1);

      clock = clock.add(const Duration(hours: 3));
      now = clock;
      await add('Pet Sematary', 'Stephen King');
      await service.runIfDue();
      expect(await count(), 1, reason: 'not due yet: daily');

      clock = clock.add(const Duration(days: 1));
      await service.runIfDue();
      expect(await count(), 2, reason: 'due, and the library changed');

      clock = clock.add(const Duration(days: 1));
      await service.runIfDue();
      expect(await count(), 2, reason: 'due, but nothing changed');

      // Twenty days on: the old ones expire, the newest is always kept.
      clock = clock.add(const Duration(days: 20));
      await service.setRetentionDays(7);
      expect(await count(), 1);

      // Restore the newest into a changed library.
      final newest = (await service.local.list()).first;
      now = clock;
      await add('The Shining', 'Stephen King');
      clock = clock.add(const Duration(minutes: 1));
      final contents = await service.peek(newest);
      expect(contents.books.map((b) => b.title).toSet(), {'Carrie', 'Pet Sematary'});
      await service.restore(contents);
      expect((await repo.allBooks()).map((b) => b.title).toSet(), {'Carrie', 'Pet Sematary'});
      final restoredCarrie = (await repo.allBooks()).firstWhere((b) => b.title == 'Carrie');
      expect(restoredCarrie.id, carrie, reason: 'ids are kept');
      expect(await covers.ownPhotoBytes(carrie), List.filled(10, 9));
      // The backup restored from was 22 days old, past the 7 days kept, so tidying removed it;
      // the safety copy of the 3-book library made just before the restore is kept.
      final copies = await service.local.list();
      expect(copies.length, 1);
      expect((await service.peek(copies.single, from: service.local)).books.length, 3);
    });

    test('backup file names carry their time', () {
      final t = DateTime(2026, 11, 14, 18, 30, 5);
      expect(backupFileName(t), 'tsundoku-backup-2026-11-14-183005.zip');
      expect(backupTimeFromName(backupFileName(t)), t);
      expect(backupTimeFromName('holiday.jpg'), isNull);
    });
  });
}
