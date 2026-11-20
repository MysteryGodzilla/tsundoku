/// The local library (SQLite through drift). The phone is the library; sync (Phase 3) will replay
/// the change log, so every write goes through [LibraryRepository], never straight to these tables.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();
  @override
  List<String> fromSql(String fromDb) => fromDb.isEmpty ? const [] : (jsonDecode(fromDb) as List).cast<String>();
  @override
  String toSql(List<String> value) => jsonEncode(value);
}

@DataClassName('BookRow')
class Books extends Table {
  /// UUID, so books made on different devices never clash.
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get authors => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get isbn13 => text().nullable()();
  TextColumn get publisher => text().nullable()();
  TextColumn get publishedDate => text().nullable()();
  TextColumn get edition => text().nullable()();

  /// The series it belongs to and its place in it ("Dune", "3"), from Open Library or typed in
  /// (added in schema 4). Books aren't grouped by series: it's shown with each book.
  TextColumn get series => text().nullable()();
  TextColumn get seriesPosition => text().nullable()();

  /// `physical` or `kindle` ([OwnershipFormat]).
  TextColumn get format => text()();
  DateTimeColumn get purchasedOn => dateTime().nullable()();

  /// When she finished reading it (optional; added in schema 2).
  DateTimeColumn get finishedOn => dateTime().nullable()();

  /// 0 to 5 stars, or null for not rated.
  IntColumn get rating => integer().nullable()();
  TextColumn get notes => text().nullable()();

  /// `tbr`, `reading`, `read`, `dnf` ([ReadingStatus]), or null (the default).
  TextColumn get status => text().nullable()();

  /// Where the downloadable cover comes from: `<sourceId>:<ref>` (e.g. `openlibrary:8750523`).
  TextColumn get coverRef => text().nullable()();

  /// True when she has taken or chosen her own cover photo (it wins over [coverRef]).
  BoolColumn get ownCover => boolean().withDefault(const Constant(false))();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Every identifier a book carries (ISBNs, Open Library work and edition, later Trove...).
class BookIdentifiers extends Table {
  TextColumn get bookId => text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get scheme => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {bookId, scheme, value};
}

class BookGenres extends Table {
  TextColumn get bookId => text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {bookId, name};
}

/// One row per change, for sync in Phase 3. Not read by the app yet.
class ChangeLog extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get bookId => text()();

  /// A field name, `genres`, `identifiers`, `created` or `deleted`.
  TextColumn get field => text()();

  /// The new value as JSON (null for a deletion).
  TextColumn get value => text().nullable()();
  DateTimeColumn get at => dateTime()();

  /// Sync (schema 3): the hybrid logical clock and device of a change; null for history from before.
  TextColumn get hlc => text().nullable()();
  TextColumn get device => text().nullable()();

  /// True once sent to the sync server (or when it never needs sending).
  BoolColumn get pushed => boolean().withDefault(const Constant(false))();
}

/// Small sync settings: this device's id, the server cursor per account, whether the library
/// was first uploaded for an account.
class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

/// The newest change applied to each field of each book, for "the later change wins".
class FieldClocks extends Table {
  TextColumn get bookId => text()();
  TextColumn get field => text()();
  TextColumn get hlc => text()();
  @override
  Set<Column> get primaryKey => {bookId, field};
}

/// Changes made on two devices that need her decision.
class SyncConflicts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();

  /// A field name, or `deletedThere` (deleted on another device, edited here) or `deletedHere`.
  TextColumn get field => text()();
  TextColumn get localValue => text().nullable()();
  TextColumn get remoteValue => text().nullable()();
  TextColumn get remoteHlc => text()();
}

@DriftDatabase(tables: [Books, BookIdentifiers, BookGenres, ChangeLog, SyncMeta, FieldClocks, SyncConflicts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'tsundoku',
              web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js')),
            ));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('CREATE INDEX IF NOT EXISTS idx_identifiers_value ON book_identifiers (scheme, value)');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(books, books.finishedOn);
          if (from < 3) {
            await m.addColumn(changeLog, changeLog.hlc);
            await m.addColumn(changeLog, changeLog.device);
            await m.addColumn(changeLog, changeLog.pushed);
            await m.createTable(syncMeta);
            await m.createTable(fieldClocks);
            await m.createTable(syncConflicts);
            // History from before sync never needs sending.
            await customStatement('UPDATE change_log SET pushed = 1');
          }
          if (from < 4) {
            await m.addColumn(books, books.series);
            await m.addColumn(books, books.seriesPosition);
          }
        },
        beforeOpen: (details) async => customStatement('PRAGMA foreign_keys = ON'),
      );
}
