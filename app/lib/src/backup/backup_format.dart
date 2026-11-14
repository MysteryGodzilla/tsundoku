/// The backup file: a zip with `library.json` (every book, all fields) and `covers/<id>.jpg` for
/// her own cover photos. Downloaded covers aren't included; they download again.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../books/library_repository.dart';
import '../books/models.dart';
import '../db/database.dart';

const backupFormat = 'tsundoku-backup';
const backupVersion = 1;

class BackupContents {
  BackupContents({required this.createdAt, required this.books, required this.ownPhotos});
  final DateTime createdAt;
  final List<LibraryBook> books;

  /// Book id to her own cover photo.
  final Map<String, Uint8List> ownPhotos;
}

String? _iso(DateTime? d) => d?.toUtc().toIso8601String();
DateTime? _date(Object? s) => s is String ? DateTime.parse(s).toLocal() : null;

Map<String, Object?> bookToJson(LibraryBook b) => {
      'id': b.id,
      'title': b.title,
      'authors': b.authors,
      'isbn13': b.row.isbn13,
      'publisher': b.row.publisher,
      'publishedDate': b.row.publishedDate,
      'edition': b.row.edition,
      'format': b.row.format,
      'purchasedOn': _iso(b.row.purchasedOn),
      'finishedOn': _iso(b.row.finishedOn),
      'rating': b.row.rating,
      'notes': b.row.notes,
      'status': b.row.status,
      'coverRef': b.row.coverRef,
      'ownCover': b.row.ownCover,
      'addedAt': _iso(b.row.addedAt),
      'updatedAt': _iso(b.row.updatedAt),
      'genres': b.genres,
      'identifiers': [for (final i in b.identifiers) {'scheme': i.scheme, 'value': i.value}],
    };

LibraryBook bookFromJson(Map<String, Object?> j) => LibraryBook(
      BookRow(
        id: j['id']! as String,
        title: j['title']! as String,
        authors: ((j['authors'] as List?) ?? const []).cast<String>(),
        isbn13: j['isbn13'] as String?,
        publisher: j['publisher'] as String?,
        publishedDate: j['publishedDate'] as String?,
        edition: j['edition'] as String?,
        format: j['format'] as String? ?? OwnershipFormat.physical.name,
        purchasedOn: _date(j['purchasedOn']),
        finishedOn: _date(j['finishedOn']),
        rating: j['rating'] as int?,
        notes: j['notes'] as String?,
        status: j['status'] as String?,
        coverRef: j['coverRef'] as String?,
        ownCover: j['ownCover'] as bool? ?? false,
        addedAt: _date(j['addedAt']) ?? DateTime.now(),
        updatedAt: _date(j['updatedAt']) ?? DateTime.now(),
      ),
      genres: ((j['genres'] as List?) ?? const []).cast<String>(),
      identifiers: [
        for (final i in (j['identifiers'] as List?) ?? const [])
          Identifier((i as Map)['scheme'] as String, i['value'] as String),
      ],
    );

Uint8List encodeBackup(List<LibraryBook> books, Map<String, Uint8List> ownPhotos, {required DateTime createdAt, String appVersion = ''}) {
  final json = {
    'format': backupFormat,
    'version': backupVersion,
    'createdAt': _iso(createdAt),
    'app': appVersion,
    'books': [for (final b in books) bookToJson(b)],
  };
  final archive = Archive()
    ..addFile(ArchiveFile.bytes('library.json', utf8.encode(const JsonEncoder.withIndent(' ').convert(json))));
  ownPhotos.forEach((id, bytes) => archive.addFile(ArchiveFile.bytes('covers/$id.jpg', bytes)));
  return ZipEncoder().encodeBytes(archive);
}

/// Throws [FormatException] if [bytes] isn't a Tsundoku backup this version can read.
BackupContents decodeBackup(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('This isn\'t a Tsundoku backup.');
  }
  final libFile = archive.findFile('library.json');
  if (libFile == null) throw const FormatException('This isn\'t a Tsundoku backup.');
  final j = jsonDecode(utf8.decode(libFile.content)) as Map<String, Object?>;
  if (j['format'] != backupFormat) throw const FormatException('This isn\'t a Tsundoku backup.');
  if ((j['version'] as int? ?? 0) > backupVersion) {
    throw const FormatException('This backup was made by a newer version of Tsundoku. Update the app first.');
  }
  final photos = <String, Uint8List>{};
  for (final f in archive.files) {
    final m = RegExp(r'^covers/(.+)\.jpg$').firstMatch(f.name);
    if (m != null && f.isFile) photos[m.group(1)!] = Uint8List.fromList(f.content);
  }
  return BackupContents(
    createdAt: _date(j['createdAt']) ?? DateTime.now(),
    books: [for (final b in (j['books'] as List?) ?? const []) bookFromJson((b as Map).cast<String, Object?>())],
    ownPhotos: photos,
  );
}
