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

  /// `physical` or `kindle` ([OwnershipFormat]).
  TextColumn get format => text()();
  DateTimeColumn get purchasedOn => dateTime().nullable()();

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
}

@DriftDatabase(tables: [Books, BookIdentifiers, BookGenres, ChangeLog])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'tsundoku',
              web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js')),
            ));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('CREATE INDEX IF NOT EXISTS idx_identifiers_value ON book_identifiers (scheme, value)');
        },
        beforeOpen: (details) async => customStatement('PRAGMA foreign_keys = ON'),
      );
}
