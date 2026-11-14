import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tsundoku/src/books/genres.dart';
import 'package:tsundoku/src/books/isbn.dart';
import 'package:tsundoku/src/books/library_repository.dart';
import 'package:tsundoku/src/books/models.dart';
import 'package:tsundoku/src/covers/cover_store.dart';
import 'package:tsundoku/src/db/database.dart';
import 'package:tsundoku/src/sources/book_source.dart';
import 'package:tsundoku/src/sources/open_library_source.dart';

const paperback = Candidate(
  sourceId: 'openlibrary',
  title: 'The Salt Orchard',
  authors: ['Mira Hale'],
  isbn13: '9780000000017',
  subjects: ['Fiction', 'Fantasy fiction', 'New York Times bestseller'],
  coverRef: '123',
  identifiers: [Identifier(Schemes.openLibraryWork, 'OL1W'), Identifier(Schemes.openLibraryEdition, 'OL1M')],
);

void main() {
  group('ISBN', () {
    test('converts ISBN-10 to ISBN-13 and checks digits', () {
      expect(toIsbn13('0-307-74443-4'), '9780307744432');
      expect(toIsbn13('978-0-307-74443-2'), '9780307744432');
      expect(toIsbn13('9780307744433'), isNull);
      expect(toIsbn13('12345'), isNull);
      expect(isBookBarcode('9780307744432'), isTrue);
      expect(isBookBarcode('5012345678900'), isFalse);
    });
    test('normalises for matching', () {
      expect(normaliseForMatch('The Salt Orchard!'), 'salt orchard');
      expect(normaliseForMatch('  Anaïs  Laurent '), 'anaïs laurent');
    });
  });

  group('genres from subjects', () {
    test('keeps known genres and drops tags', () {
      expect(genresFromSubjects(['Fiction', 'Fantasy fiction', 'New York Times bestseller', 'Magicians']), ['Fantasy']);
      expect(genresFromSubjects(['Fiction', 'Circus']), ['Fiction']);
      expect(genresFromSubjects(['Science fiction', 'Space', 'Fiction']), ['Science fiction']);
      expect(genresFromSubjects(['Australia', 'History', 'Gold rushes']), ['History']);
      expect(genresFromSubjects(const []), isEmpty);
    });
  });

  group('library', () {
    late AppDatabase db;
    late LibraryRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = LibraryRepository(db);
    });
    tearDown(() => db.close());

    test('owned check: same work in another format, same ISBN, or same title and author', () async {
      final id = await repo.addFromCandidate(paperback, OwnershipFormat.physical);
      final book = await repo.getBook(id);
      expect(book!.genres, ['Fantasy']);
      expect(book.row.coverRef, 'openlibrary:123');

      // A Kindle copy found by title search: no ISBN, same Open Library work.
      const kindle = Candidate(sourceId: 'openlibrary', title: 'The Salt Orchard', identifiers: [Identifier(Schemes.openLibraryWork, 'OL1W')]);
      expect((await repo.findOwned(kindle))?.id, id);
      // Same ISBN from another source.
      expect((await repo.findOwned(const Candidate(sourceId: 'x', title: 'Other', isbn13: '9780000000017')))?.id, id);
      // Typed by hand: same title and author, different case and article.
      expect((await repo.findOwned(const Candidate(sourceId: 'manual', title: 'salt orchard', authors: ['MIRA HALE'])))?.id, id);
      // Similar title, different author: not owned.
      expect(await repo.findOwned(const Candidate(sourceId: 'manual', title: 'The Salt Orchard', authors: ['Jonah Reyes'])), isNull);
      expect(await repo.findOwned(const Candidate(sourceId: 'manual', title: 'Salt and Stone', authors: ['Mira Hale'])), isNull);
    });

    test('local search by title words, author and ISBN', () async {
      await repo.addFromCandidate(paperback, OwnershipFormat.physical);
      await repo.addManual(title: 'Quiet Hours', authors: ['Anaïs Laurent'], format: OwnershipFormat.kindle);
      final all = await repo.watchAll().first;
      expect(all.first.title, 'Quiet Hours', reason: 'newest first');
      expect(LibraryRepository.filter(all, 'orchard salt').single.title, 'The Salt Orchard');
      expect(LibraryRepository.filter(all, 'laurent').single.title, 'Quiet Hours');
      expect(LibraryRepository.filter(all, 'anais').length, 0, reason: 'accents are kept as typed for now');
      expect(LibraryRepository.filter(all, '978-0000').single.title, 'The Salt Orchard');
      expect(LibraryRepository.filter(all, 'circus'), isEmpty);
      expect(LibraryRepository.filter(all, '').length, 2);
    });

    test('edits, clearing, genres, delete and the change log', () async {
      final id = await repo.addFromCandidate(paperback, OwnershipFormat.physical);
      await repo.update(id, BookChanges(rating: 4, status: ReadingStatus.read, notes: 'Loved it', purchasedOn: DateTime(2026, 3, 1)));
      var b = (await repo.getBook(id))!;
      expect((b.row.rating, b.status, b.row.notes, b.row.purchasedOn), (4, ReadingStatus.read, 'Loved it', DateTime(2026, 3, 1)));

      await repo.update(id, const BookChanges(clear: {'rating', 'status'}, isbn13: '9780307744432'));
      b = (await repo.getBook(id))!;
      expect(b.row.rating, isNull);
      expect(b.status, isNull);
      expect(b.identifiers.where((i) => i.scheme == Schemes.isbn13).map((i) => i.value), ['9780307744432']);

      await repo.setGenres(id, ['Romance', ' Fantasy ', 'Romance']);
      expect((await repo.getBook(id))!.genres, ['Fantasy', 'Romance']);

      await repo.delete(id);
      expect(await repo.getBook(id), isNull);
      expect(await db.select(db.bookIdentifiers).get(), isEmpty);
      expect(await db.select(db.bookGenres).get(), isEmpty);
      final log = await db.select(db.changeLog).get();
      expect(log.first.field, 'created');
      expect(log.last.field, 'deleted');
    });
  });

  group('her feedback, 2026-11-14', () {
    test('Reading books are pinned to the top, most recently touched first', () async {
      var t = DateTime(2026, 1, 1);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = LibraryRepository(db, clock: () => t = t.add(const Duration(minutes: 1)));
      final a = await repo.addManual(title: 'A', format: OwnershipFormat.physical);
      final b = await repo.addManual(title: 'B', format: OwnershipFormat.physical);
      await repo.addManual(title: 'C', format: OwnershipFormat.kindle);
      expect(LibraryRepository.pinReading(await repo.watchAll().first).map((x) => x.title), ['C', 'B', 'A'], reason: 'nothing reading: newest first');
      await repo.update(a, const BookChanges(status: ReadingStatus.reading));
      expect(LibraryRepository.pinReading(await repo.watchAll().first).map((x) => x.title), ['A', 'C', 'B']);
      await repo.update(b, const BookChanges(status: ReadingStatus.reading));
      expect(LibraryRepository.pinReading(await repo.watchAll().first).map((x) => x.title), ['B', 'A', 'C']);
    });

    test('finished date can be set and cleared', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = LibraryRepository(db);
      final id = await repo.addManual(title: 'A', format: OwnershipFormat.physical);
      await repo.update(id, BookChanges(finishedOn: DateTime(2026, 11, 2)));
      expect((await repo.getBook(id))!.row.finishedOn, DateTime(2026, 11, 2));
      await repo.update(id, const BookChanges(clear: {'finishedOn'}));
      expect((await repo.getBook(id))!.row.finishedOn, isNull);
    });

    test('a library from the first version (schema 1) upgrades and keeps its books', () async {
      final dir = await Directory.systemTemp.createTemp('upgrade');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/library.sqlite');

      // Make a schema 1 library: today's tables without the finished date, marked as version 1.
      var db = AppDatabase(NativeDatabase(file));
      await LibraryRepository(db).addManual(title: 'Carrie', authors: ['Stephen King'], format: OwnershipFormat.physical);
      await db.customStatement('ALTER TABLE books DROP COLUMN finished_on');
      await db.customStatement('PRAGMA user_version = 1');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      final repo = LibraryRepository(db);
      final books = await repo.watchAll().first;
      expect(books.single.title, 'Carrie');
      await repo.update(books.single.id, BookChanges(finishedOn: DateTime(2026, 11, 14)));
      expect((await repo.getBook(books.single.id))!.row.finishedOn, DateTime(2026, 11, 14));
      await db.close();
    });
  });

  group('Open Library source', () {
    test('ISBN lookup builds a candidate with work, edition, author and cover', () async {
      final client = MockClient((req) async {
        final path = req.url.path;
        expect(req.headers['User-Agent'], startsWith('Tsundoku/'));
        final body = switch (path) {
          '/isbn/9780307744432.json' => {
              'key': '/books/OL25000000M',
              'title': 'The Night Circus',
              'works': [{'key': '/works/OL16086747W'}],
              'publishers': ['Anchor Books'],
              'publish_date': '2012',
              'physical_format': 'Paperback',
              'covers': [-1, 8750523],
            },
          '/works/OL16086747W.json' => {
              'authors': [{'author': {'key': '/authors/OL6915296A'}}],
              'subjects': ['Fiction', 'Magicians', 'Fantasy fiction'],
            },
          '/authors/OL6915296A.json' => {'name': 'Erin Morgenstern'},
          _ => null,
        };
        return body == null ? http.Response('', 404) : http.Response(jsonEncode(body), 200);
      });
      final ol = OpenLibrarySource(client: client);
      final c = (await ol.lookupIsbn('9780307744432'))!;
      expect(c.title, 'The Night Circus');
      expect(c.authors, ['Erin Morgenstern']);
      expect(c.coverRef, '8750523');
      expect(c.allIdentifiers, containsAll(const [
        Identifier(Schemes.openLibraryWork, 'OL16086747W'),
        Identifier(Schemes.openLibraryEdition, 'OL25000000M'),
        Identifier(Schemes.isbn13, '9780307744432'),
      ]));
      expect(genresFromSubjects(c.subjects), ['Fantasy']);
      expect(await ol.lookupIsbn('9780000000002'), isNull);
      expect(ol.coverUri('8750523', CoverSize.large).toString(), 'https://covers.openlibrary.org/b/id/8750523-L.jpg?default=false');
    });
  });

  group('covers', () {
    test('downloads once, and clearing keeps her own photos', () async {
      final tmp = await Directory.systemTemp.createTemp('covers');
      addTearDown(() => tmp.delete(recursive: true));
      var downloads = 0;
      final client = MockClient((req) async {
        downloads++;
        return http.Response.bytes(List.filled(500, 7), 200);
      });
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = LibraryRepository(db);
      final store = CoverStore(BookLookup([OpenLibrarySource()]), client: client, baseDir: () async => tmp);

      final a = (await repo.getBook(await repo.addFromCandidate(paperback, OwnershipFormat.physical)))!;
      expect(await store.ensure(a), isNotNull);
      expect(await store.ensure(a), isNotNull);
      expect(downloads, 1);

      await store.saveOwnPhoto(a.id, Uint8List.fromList(List.filled(300, 1)));
      expect(await store.downloadedBytes(), 500);
      await store.clearDownloaded();
      expect(await store.downloadedBytes(), 0);
      await repo.update(a.id, const BookChanges(ownCover: true));
      final withOwn = (await repo.getBook(a.id))!;
      expect((await store.localFile(withOwn))?.path, endsWith('-own.jpg'), reason: 'her photo survives clearing');
    });
  });
}
