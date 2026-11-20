/// Export the whole library to a spreadsheet (a product rule: everything in it, export only).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../books/library_repository.dart';
import '../books/models.dart';
import 'xlsx.dart';

String _date(DateTime? d) =>
    d == null ? '' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const exportHeaders = [
  'Title', 'Authors', 'Series', 'Number in series', 'Format', 'Status', 'Rating', 'Date purchased', 'Date finished', 'Genres', 'Notes',
  'ISBN', 'Publisher', 'Published', 'Edition', 'Date added', 'Open Library work',
];

List<List<Object?>> exportRows(List<LibraryBook> books) => [
      for (final b in books)
        [
          b.title,
          b.authors.join(', '),
          b.row.series ?? '',
          b.row.seriesPosition ?? '',
          b.format.label,
          b.status?.longLabel ?? '',
          b.row.rating,
          _date(b.row.purchasedOn),
          _date(b.row.finishedOn),
          b.genres.join(', '),
          b.row.notes ?? '',
          b.row.isbn13 ?? '',
          b.row.publisher ?? '',
          b.row.publishedDate ?? '',
          b.row.edition ?? '',
          _date(b.row.addedAt),
          b.identifiers.where((i) => i.scheme == Schemes.openLibraryWork).map((i) => i.value).firstOrNull ?? '',
        ],
    ];

Uint8List buildLibraryXlsx(List<LibraryBook> books) {
  final sorted = [...books]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return buildXlsx(
    sheetName: 'Library',
    headers: exportHeaders,
    rows: exportRows(sorted),
    widths: const [36, 24, 10, 16, 8, 14, 14, 24, 40, 16, 22, 12, 14, 12, 16],
  );
}

const xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

String spreadsheetFileName(DateTime now) => 'Tsundoku library ${_date(now)}.xlsx';

/// Android's save dialog (Downloads, Google Drive and so on). Returns false if she backed out.
Future<bool> saveLibrarySpreadsheet(List<LibraryBook> books) async {
  final uri = await FilePicker.saveFile(
    fileName: spreadsheetFileName(DateTime.now()),
    bytes: buildLibraryXlsx(books),
    mimeType: xlsxMime,
  );
  return uri != null;
}

/// Writes the spreadsheet and opens Android's share sheet (email it, and so on).
Future<void> shareLibrarySpreadsheet(List<LibraryBook> books) async {
  final now = DateTime.now();
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, spreadsheetFileName(now)));
  await file.writeAsBytes(buildLibraryXlsx(books), flush: true);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: xlsxMime)],
    subject: 'My Tsundoku library',
  ));
}
