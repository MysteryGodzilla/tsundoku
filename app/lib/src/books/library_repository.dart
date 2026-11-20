/// The one place that reads and writes the library. Every write also lands in the change log,
/// ready for sync in Phase 3.
library;

import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../backup/backup_format.dart';
import '../sync/hlc.dart';

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
  BookSeries? get series => (row.series ?? '').trim().isEmpty ? null : BookSeries(row.series!.trim(), row.seriesPosition);
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
    this.series,
    this.seriesPosition,
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
  final String? series;
  final String? seriesPosition;

  /// Field names to set back to empty: `isbn13`, `publisher`, `publishedDate`, `purchasedOn`, `finishedOn`,
  /// `rating`, `notes`, `status`, `coverRef`, `series`, `seriesPosition`.
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

  /// One read, not a live query (safe inside transactions and widget tests).
  Future<LibraryBook?> getBook(String id) async {
    final r = await (db.select(db.books)..where((b) => b.id.equals(id))).getSingleOrNull();
    return r == null ? null : (await _withDetails([r])).single;
  }

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
      final hay = normaliseForMatch('${b.title} ${b.authors.join(' ')} ${b.row.series ?? ''}');
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

  // ---------- Sync hooks (step 3b) ----------

  Future<Hlc>? _hlcFuture;

  /// This device's clock. Its id is made once and kept in the database.
  Future<Hlc> hlc() => _hlcFuture ??= () async {
        var id = await getMeta('device');
        if (id == null) {
          id = base64Url.encode(List<int>.generate(12, (_) => _rng.nextInt(256))).replaceAll('=', '');
          await setMeta('device', id);
        }
        return Hlc(id, clock: _clock);
      }();

  static final _rng = Random.secure();

  Future<String?> getMeta(String key) async =>
      (await (db.select(db.syncMeta)..where((m) => m.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setMeta(String key, String value) =>
      db.into(db.syncMeta).insertOnConflictUpdate(SyncMetaCompanion.insert(key: key, value: value));

  /// Fields whose newest change is tracked; `created` and `deleted` count as the whole book (`*`).
  static String clockKey(String field) => field == 'created' || field == 'deleted' ? '*' : field;

  Future<void> setFieldClock(String bookId, String field, String hlc) =>
      db.into(db.fieldClocks).insertOnConflictUpdate(FieldClocksCompanion.insert(bookId: bookId, field: clockKey(field), hlc: hlc));

  Future<String?> fieldClock(String bookId, String field) async => (await (db.select(db.fieldClocks)
            ..where((c) => c.bookId.equals(bookId) & c.field.equals(clockKey(field))))
          .getSingleOrNull())
      ?.hlc;

  Future<void> _log(String bookId, String field, Object? value) async {
    final clock = await hlc();
    final stamp = clock.next();
    await db.into(db.changeLog).insert(ChangeLogCompanion.insert(
          bookId: bookId,
          field: field,
          value: Value(value == null ? null : jsonEncode(value)),
          at: _clock(),
          hlc: Value(stamp),
          device: Value(clock.device),
        ));
    if (bookId != '*') await setFieldClock(bookId, field, stamp);
  }

  Future<Map<String, Object?>?> _snapshot(String id) async {
    final b = await getBook(id);
    return b == null ? null : bookToJson(b);
  }

  /// Log the whole book as it is now (first upload, or "keep it" after a deletion elsewhere).
  Future<void> logSnapshot(String id) async {
    final s = await _snapshot(id);
    if (s != null) await _log(id, 'created', s);
  }

  /// Announce her own photo again under a fresh id (the first upload of a library).
  Future<void> logPhoto(String id) => _log(id, 'photo', _uuid.v4());

  /// Applying changes from another device: plain writes, nothing logged.
  Future<void> insertSnapshot(LibraryBook b) => db.transaction(() async {
        await db.into(db.books).insertOnConflictUpdate(b.row);
        await (db.delete(db.bookIdentifiers)..where((i) => i.bookId.equals(b.id))).go();
        await (db.delete(db.bookGenres)..where((g) => g.bookId.equals(b.id))).go();
        for (final i in b.identifiers.toSet()) {
          await db.into(db.bookIdentifiers).insert(BookIdentifiersCompanion.insert(bookId: b.id, scheme: i.scheme, value: i.value),
              mode: InsertMode.insertOrIgnore);
        }
        for (final g in b.genres.toSet()) {
          await db.into(db.bookGenres).insert(BookGenresCompanion.insert(bookId: b.id, name: g), mode: InsertMode.insertOrIgnore);
        }
      });

  Future<void> deleteQuietly(String id) => (db.delete(db.books)..where((b) => b.id.equals(id))).go();

  /// One field from another device (names as in the change log; `photo` sets [BookRow.ownCover]).
  Future<void> applyField(String id, String field, Object? v) => db.transaction(() async {
        DateTime? d(Object? o) => o == null ? null : DateTime.parse(o as String);
        final c = switch (field) {
          'title' => v == null ? null : BooksCompanion(title: Value(v as String)),
          'authors' => BooksCompanion(authors: Value(((v as List?) ?? const []).cast<String>())),
          'isbn13' => BooksCompanion(isbn13: Value(v as String?)),
          'publisher' => BooksCompanion(publisher: Value(v as String?)),
          'publishedDate' => BooksCompanion(publishedDate: Value(v as String?)),
          'format' => v == null ? null : BooksCompanion(format: Value(v as String)),
          'purchasedOn' => BooksCompanion(purchasedOn: Value(d(v))),
          'finishedOn' => BooksCompanion(finishedOn: Value(d(v))),
          'rating' => BooksCompanion(rating: Value(v as int?)),
          'notes' => BooksCompanion(notes: Value(v as String?)),
          'status' => BooksCompanion(status: Value(v as String?)),
          'coverRef' => BooksCompanion(coverRef: Value(v as String?)),
          'series' => BooksCompanion(series: Value(v as String?)),
          'seriesPosition' => BooksCompanion(seriesPosition: Value(v as String?)),
          'photo' => BooksCompanion(ownCover: Value(v != null)),
          _ => null,
        };
        if (c != null) {
          await (db.update(db.books)..where((b) => b.id.equals(id))).write(c.copyWith(updatedAt: Value(_clock())));
        }
        if (field == 'isbn13') {
          await (db.delete(db.bookIdentifiers)..where((i) => i.bookId.equals(id) & i.scheme.equals(Schemes.isbn13))).go();
          if (v != null) {
            await db.into(db.bookIdentifiers).insert(BookIdentifiersCompanion.insert(bookId: id, scheme: Schemes.isbn13, value: v as String),
                mode: InsertMode.insertOrIgnore);
          }
        }
        if (field == 'genres') {
          await (db.delete(db.bookGenres)..where((g) => g.bookId.equals(id))).go();
          for (final g in ((v as List?) ?? const []).cast<String>().toSet()) {
            await db.into(db.bookGenres).insert(BookGenresCompanion.insert(bookId: id, name: g), mode: InsertMode.insertOrIgnore);
          }
        }
      });

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
        series: c.series,
      );

  /// Add a book typed in by hand.
  Future<String> addManual({
    required String title,
    List<String> authors = const [],
    String? isbn13,
    String? publisher,
    String? publishedDate,
    required OwnershipFormat format,
    BookSeries? series,
  }) =>
      _insert(
        title: title,
        authors: authors,
        isbn13: isbn13,
        publisher: publisher,
        publishedDate: publishedDate,
        format: format,
        identifiers: [if (isbn13 != null) Identifier(Schemes.isbn13, isbn13)],
        series: series,
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
    BookSeries? series,
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
            series: Value(series?.name.trim()),
            seriesPosition: Value(series?.position?.trim()),
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
      // Inside the transaction, so nothing else can queue between the insert and its log entry.
      await logSnapshot(id);
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
      if (c.series != null) 'series': c.series!.trim(),
      if (c.seriesPosition != null) 'seriesPosition': c.seriesPosition!.trim(),
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
            series: v('series', (o) => o as String?),
            seriesPosition: v('seriesPosition', (o) => o as String?),
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
        if (e.key == 'ownCover') {
          // Her own photo travels as an attachment named by a fresh id.
          await _log(id, 'photo', e.value == true ? _uuid.v4() : null);
        } else {
          await _log(id, e.key, e.value);
        }
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

  /// Every book, for backups and export.
  Future<List<LibraryBook>> allBooks() => watchAll().first;

  /// When the library last changed (anything in the change log), or null if never.
  Future<DateTime?> lastChangeAt() async {
    final q = db.selectOnly(db.changeLog)..addColumns([db.changeLog.at.max()]);
    return (await q.getSingle()).read(db.changeLog.at.max());
  }

  /// Replace the whole library with [books] (restoring a backup). Ids and dates are kept.
  Future<void> replaceAll(List<LibraryBook> books) => db.transaction(() async {
        final before = await db.select(db.books).get();
        await db.delete(db.bookGenres).go();
        await db.delete(db.bookIdentifiers).go();
        await db.delete(db.books).go();
        for (final b in books) {
          await db.into(db.books).insert(b.row);
          for (final i in b.identifiers.toSet()) {
            await db.into(db.bookIdentifiers).insert(
                  BookIdentifiersCompanion.insert(bookId: b.id, scheme: i.scheme, value: i.value),
                  mode: InsertMode.insertOrIgnore,
                );
          }
          for (final g in b.genres.toSet()) {
            await db.into(db.bookGenres).insert(BookGenresCompanion.insert(bookId: b.id, name: g), mode: InsertMode.insertOrIgnore);
          }
        }
        await _log('*', 'restored', {'books': books.length});
        // Other devices hear of a restore as ordinary changes.
        final kept = {for (final b in books) b.id};
        for (final row in before.where((row) => !kept.contains(row.id))) {
          await _log(row.id, 'deleted', null);
        }
        for (final b in books) {
          await _log(b.id, 'created', bookToJson(b));
        }
      });

  /// Permanently remove a book (no recycle bin, a product rule).
  /// The book's last state is kept in the change log, so a sync conflict can bring it back.
  Future<void> delete(String id) async {
    final snapshot = await _snapshot(id);
    await db.transaction(() async {
        await (db.delete(db.books)..where((b) => b.id.equals(id))).go();
        await _log(id, 'deleted', snapshot);
      });
  }
}
