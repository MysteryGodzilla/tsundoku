/// The one place that reads and writes the library. Every write also lands in the change log,
/// ready for sync in Phase 3.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import 'genres.dart';
import 'isbn.dart';
import 'models.dart';

/// A book in the library, with its genres and identifiers.
class LibraryBook {
  LibraryBook(this.row, {this.genres = const [], this.identifiers = const []});
  final BookRow row;
  final List<String> genres;
  final List<Identifier> identifiers;

  String get id => row.id;
  String get title => row.title;
  List<String> get authors => row.authors;
  String get authorLine => row.authors.join(', ');
  OwnershipFormat get format => OwnershipFormat.parse(row.format);
  ReadingStatus? get status => ReadingStatus.parse(row.status);
  bool get hasOwnCover => row.ownCover;
}

/// The fields a person can set on a book. Null means "leave as it is" unless listed in [clear].
class BookChanges {
  const BookChanges({
    this.title,
    this.authors,
    this.isbn13,
    this.publisher,
    this.publishedDate,
    this.format,
    this.purchasedOn,
    this.finishedOn,
    this.rating,
    this.notes,
    this.status,
    this.coverRef,
    this.ownCover,
    this.clear = const {},
  });
  final String? title;
  final List<String>? authors;
  final String? isbn13;
  final String? publisher;
  final String? publishedDate;
  final OwnershipFormat? format;
  final DateTime? purchasedOn;
  final DateTime? finishedOn;
  final int? rating;
  final String? notes;
  final ReadingStatus? status;
  final String? coverRef;
  final bool? ownCover;

  /// Field names to set back to empty: `isbn13`, `publisher`, `publishedDate`, `purchasedOn`, `finishedOn`,
  /// `rating`, `notes`, `status`, `coverRef`.
  final Set<String> clear;
}

class LibraryRepository {
  LibraryRepository(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  // ---------- Reading ----------

  /// The whole library, most recently added first.
  Stream<List<LibraryBook>> watchAll() {
    final q = db.select(db.books)
      ..orderBy([(b) => OrderingTerm.desc(b.addedAt), (b) => OrderingTerm.desc(b.rowId)]);
    return q.watch().asyncMap(_withDetails);
  }

  Stream<LibraryBook?> watchBook(String id) =>
      (db.select(db.books)..where((b) => b.id.equals(id))).watchSingleOrNull().asyncMap((r) async {
        if (r == null) return null;
        return (await _withDetails([r])).single;
      });

  Future<LibraryBook?> getBook(String id) => watchBook(id).first;

  Future<List<LibraryBook>> _withDetails(List<BookRow> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r.id).toList();
    final genres = await (db.select(db.bookGenres)..where((g) => g.bookId.isIn(ids))).get();
    final idents = await (db.select(db.bookIdentifiers)..where((i) => i.bookId.isIn(ids))).get();
    return [
      for (final r in rows)
        LibraryBook(
          r,
          genres: genres.where((g) => g.bookId == r.id).map((g) => g.name).toList()..sort(),
          identifiers: idents.where((i) => i.bookId == r.id).map((i) => Identifier(i.scheme, i.value)).toList(),
        ),
    ];
  }

  /// The default order until filters arrive (her request): books she's Reading first, most recently
  /// touched first, then everything else in the order given (newest added first).
  static List<LibraryBook> pinReading(List<LibraryBook> books) {
    final reading = books.where((b) => b.status == ReadingStatus.reading).toList()
      ..sort((a, b) => b.row.updatedAt.compareTo(a.row.updatedAt));
    return [...reading, ...books.where((b) => b.status != ReadingStatus.reading)];
  }

  /// Her library filtered by title, author or ISBN. Local only: never calls a lookup source.
  static List<LibraryBook> filter(List<LibraryBook> books, String query) {
    final q = normaliseForMatch(query);
    if (q.isEmpty) return books;
    final digits = cleanIsbn(query);
    final words = q.split(' ');
    return books.where((b) {
      if (digits.length >= 4 && digits.length == query.replaceAll(RegExp(r'[\s-]'), '').length) {
        if ((b.row.isbn13 ?? '').contains(digits)) return true;
        if (b.identifiers.any((i) => i.scheme == Schemes.isbn13 && i.value.contains(digits))) return true;
      }
      final hay = normaliseForMatch('${b.title} ${b.authors.join(' ')}');
      return words.every(hay.contains);
    }).toList();
  }

  /// The owned check: any shared identifier (ISBN, Open Library work...), then the same title and
  /// first author. Similar titles by different authors don't match.
  Future<LibraryBook?> findOwned(Candidate c) async {
    final ids = c.allIdentifiers;
    for (final i in ids) {
      final hit = await (db.select(db.bookIdentifiers)
            ..where((t) => t.scheme.equals(i.scheme) & t.value.equals(i.value))
            ..limit(1))
          .getSingleOrNull();
      if (hit != null) return getBook(hit.bookId);
    }
    final t = normaliseForMatch(c.title.split(':').first);
    final a = c.authors.isEmpty ? '' : normaliseForMatch(c.authors.first);
    if (t.isEmpty) return null;
    final rows = await db.select(db.books).get();
    for (final r in rows) {
      final rt = normaliseForMatch(r.title.split(':').first);
      final ra = r.authors.isEmpty ? '' : normaliseForMatch(r.authors.first);
      if (rt == t && (a.isEmpty || ra.isEmpty || ra == a)) return getBook(r.id);
    }
    return null;
  }

  Future<int> count() async => (await db.select(db.books).get()).length;

  // ---------- Writing ----------

  Future<void> _log(String bookId, String field, Object? value) =>
      db.into(db.changeLog).insert(ChangeLogCompanion.insert(
            bookId: bookId,
            field: field,
            value: Value(value == null ? null : jsonEncode(value)),
            at: _clock(),
          ));

  /// Add a book found by a source. Genres are suggested from its subjects.
  Future<String> addFromCandidate(Candidate c, OwnershipFormat format) => _insert(
        title: c.title,
        authors: c.authors,
        isbn13: c.isbn13,
        publisher: c.publisher,
        publishedDate: c.publishedDate,
        edition: c.edition,
        format: format,
        coverRef: c.coverRef == null ? null : '${c.sourceId}:${c.coverRef}',
        identifiers: c.allIdentifiers,
        genres: genresFromSubjects(c.subjects),
      );

  /// Add a book typed in by hand.
  Future<String> addManual({
    required String title,
    List<String> authors = const [],
    String? isbn13,
    String? publisher,
    String? publishedDate,
    required OwnershipFormat format,
  }) =>
      _insert(
        title: title,
        authors: authors,
        isbn13: isbn13,
        publisher: publisher,
        publishedDate: publishedDate,
        format: format,
        identifiers: [if (isbn13 != null) Identifier(Schemes.isbn13, isbn13)],
      );

  Future<String> _insert({
    required String title,
    required List<String> authors,
    String? isbn13,
    String? publisher,
    String? publishedDate,
    String? edition,
    required OwnershipFormat format,
    String? coverRef,
    List<Identifier> identifiers = const [],
    List<String> genres = const [],
  }) async {
    final id = _uuid.v4();
    final now = _clock();
    await db.transaction(() async {
      await db.into(db.books).insert(BooksCompanion.insert(
            id: id,
            title: title.trim(),
            authors: Value(authors.map((a) => a.trim()).where((a) => a.isNotEmpty).toList()),
            isbn13: Value(isbn13),
            publisher: Value(publisher),
            publishedDate: Value(publishedDate),
            edition: Value(edition),
            format: format.name,
            coverRef: Value(coverRef),
            addedAt: now,
            updatedAt: now,
          ));
      for (final i in identifiers.toSet()) {
        await db.into(db.bookIdentifiers).insert(
              BookIdentifiersCompanion.insert(bookId: id, scheme: i.scheme, value: i.value),
              mode: InsertMode.insertOrIgnore,
            );
      }
      for (final g in genres.toSet()) {
        await db.into(db.bookGenres).insert(BookGenresCompanion.insert(bookId: id, name: g), mode: InsertMode.insertOrIgnore);
      }
      await _log(id, 'created', {
        'title': title,
        'authors': authors,
        'isbn13': isbn13,
        'publisher': publisher,
        'publishedDate': publishedDate,
        'edition': edition,
        'format': format.name,
        'coverRef': coverRef,
        'identifiers': [for (final i in identifiers) '$i'],
        'genres': genres,
      });
    });
    return id;
  }

  Future<void> update(String id, BookChanges c) async {
    final values = <String, Object?>{
      if (c.title != null) 'title': c.title!.trim(),
      if (c.authors != null) 'authors': c.authors!.map((a) => a.trim()).where((a) => a.isNotEmpty).toList(),
      if (c.isbn13 != null) 'isbn13': c.isbn13,
      if (c.publisher != null) 'publisher': c.publisher,
      if (c.publishedDate != null) 'publishedDate': c.publishedDate,
      if (c.format != null) 'format': c.format!.name,
      if (c.purchasedOn != null) 'purchasedOn': c.purchasedOn!.toIso8601String(),
      if (c.finishedOn != null) 'finishedOn': c.finishedOn!.toIso8601String(),
      if (c.rating != null) 'rating': c.rating!.clamp(0, 5),
      if (c.notes != null) 'notes': c.notes,
      if (c.status != null) 'status': c.status!.name,
      if (c.coverRef != null) 'coverRef': c.coverRef,
      if (c.ownCover != null) 'ownCover': c.ownCover,
      for (final f in c.clear) f: null,
    };
    if (values.isEmpty) return;
    Value<T> v<T>(String key, T Function(Object?) conv) => values.containsKey(key) ? Value(conv(values[key])) : const Value.absent();
    await db.transaction(() async {
      await (db.update(db.books)..where((b) => b.id.equals(id))).write(BooksCompanion(
            title: values['title'] == null ? const Value.absent() : Value(values['title']! as String),
            authors: values['authors'] == null ? const Value.absent() : Value(values['authors']! as List<String>),
            isbn13: v('isbn13', (o) => o as String?),
            publisher: v('publisher', (o) => o as String?),
            publishedDate: v('publishedDate', (o) => o as String?),
            format: values['format'] == null ? const Value.absent() : Value(values['format']! as String),
            purchasedOn: v('purchasedOn', (o) => o == null ? null : DateTime.parse(o as String)),
            finishedOn: v('finishedOn', (o) => o == null ? null : DateTime.parse(o as String)),
            rating: v('rating', (o) => o as int?),
            notes: v('notes', (o) => o as String?),
            status: v('status', (o) => o as String?),
            coverRef: v('coverRef', (o) => o as String?),
            ownCover: values['ownCover'] == null ? const Value.absent() : Value(values['ownCover']! as bool),
            updatedAt: Value(_clock()),
          ));
      if (values.containsKey('isbn13')) {
        await (db.delete(db.bookIdentifiers)..where((i) => i.bookId.equals(id) & i.scheme.equals(Schemes.isbn13))).go();
        final isbn = values['isbn13'] as String?;
        if (isbn != null) {
          await db.into(db.bookIdentifiers).insert(BookIdentifiersCompanion.insert(bookId: id, scheme: Schemes.isbn13, value: isbn),
              mode: InsertMode.insertOrIgnore);
        }
      }
      for (final e in values.entries) {
        await _log(id, e.key, e.value);
      }
    });
  }

  Future<void> setGenres(String id, List<String> genres) async {
    final clean = genres.map((g) => g.trim()).where((g) => g.isNotEmpty).toSet().toList()..sort();
    await db.transaction(() async {
      await (db.delete(db.bookGenres)..where((g) => g.bookId.equals(id))).go();
      for (final g in clean) {
        await db.into(db.bookGenres).insert(BookGenresCompanion.insert(bookId: id, name: g));
      }
      await (db.update(db.books)..where((b) => b.id.equals(id))).write(BooksCompanion(updatedAt: Value(_clock())));
      await _log(id, 'genres', clean);
    });
  }

  /// Every genre used in the library, for suggestions.
  Future<List<String>> allGenres() async {
    final rows = await db.select(db.bookGenres).get();
    return rows.map((r) => r.name).toSet().toList()..sort();
  }

  /// Permanently remove a book (no recycle bin, a product rule).
  Future<void> delete(String id) => db.transaction(() async {
        await (db.delete(db.books)..where((b) => b.id.equals(id))).go();
        await _log(id, 'deleted', null);
      });
}
