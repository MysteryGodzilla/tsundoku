/// Covers kept on the device so the library looks right offline.
///
/// - Downloaded covers (`<bookId>.jpg`) can be cleared to save space and come back when online.
/// - Her own photos (`<bookId>-own.jpg`) are never cleared: they can't be downloaded again.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../books/library_repository.dart';
import '../sources/book_source.dart';

class CoverStore extends ChangeNotifier {
  CoverStore(this.lookup, {http.Client? client, Future<Directory> Function()? baseDir})
      : _client = client ?? http.Client(),
        _baseDir = baseDir ?? getApplicationSupportDirectory;

  final BookLookup lookup;
  final http.Client _client;
  final Future<Directory> Function() _baseDir;
  final _inFlight = <String, Future<File?>>{};
  Directory? _dir;

  /// Bumped whenever a cover file appears or goes, so images rebuild.
  int version = 0;

  bool get supported => !kIsWeb;

  Future<Directory> _covers() async {
    if (_dir != null) return _dir!;
    final d = Directory(p.join((await _baseDir()).path, 'covers'));
    await d.create(recursive: true);
    return _dir = d;
  }

  Future<File> _downloaded(String bookId) async => File(p.join((await _covers()).path, '$bookId.jpg'));
  Future<File> _own(String bookId) async => File(p.join((await _covers()).path, '$bookId-own.jpg'));

  void _changed() {
    version++;
    notifyListeners();
  }

  /// The cover file to show for [book] if one is on the device.
  Future<File?> localFile(LibraryBook book) async {
    if (!supported) return null;
    if (book.hasOwnCover) {
      final own = await _own(book.id);
      if (await own.exists()) return own;
    }
    final f = await _downloaded(book.id);
    return await f.exists() ? f : null;
  }

  /// Make sure [book]'s downloadable cover is on the device; downloads it once if needed.
  Future<File?> ensure(LibraryBook book) async {
    if (!supported || book.row.coverRef == null) return null;
    final existing = await _downloaded(book.id);
    if (await existing.exists()) return existing;
    // The block body matters: returning the removed future would make it wait on itself.
    return _inFlight[book.id] ??= _download(book).whenComplete(() {
      _inFlight.remove(book.id);
    });
  }

  Future<File?> _download(LibraryBook book) async {
    final uri = lookup.coverUri(book.row.coverRef!, CoverSize.large);
    if (uri == null) return null;
    try {
      final r = await _client.get(uri).timeout(const Duration(seconds: 30));
      if (r.statusCode != 200 || r.bodyBytes.length < 200) return null;
      final f = await _downloaded(book.id);
      await f.writeAsBytes(r.bodyBytes, flush: true);
      _changed();
      return f;
    } catch (_) {
      return null; // Offline or failed: try again next time it's shown.
    }
  }

  Future<void> saveOwnPhoto(String bookId, Uint8List bytes) async {
    await (await _own(bookId)).writeAsBytes(bytes, flush: true);
    _changed();
  }

  Future<void> removeOwnPhoto(String bookId) async {
    final f = await _own(bookId);
    if (await f.exists()) await f.delete();
    _changed();
  }

  /// Remove every cover file for a book that has been deleted.
  Future<void> deleteFor(String bookId) async {
    for (final f in [await _downloaded(bookId), await _own(bookId)]) {
      if (await f.exists()) await f.delete();
    }
    _changed();
  }

  /// Space used by downloaded covers (her own photos aren't counted: they can't be cleared).
  Future<int> downloadedBytes() async {
    if (!supported) return 0;
    var total = 0;
    await for (final e in (await _covers()).list()) {
      if (e is File && !e.path.endsWith('-own.jpg')) total += await e.length();
    }
    return total;
  }

  /// Clear downloaded covers. Books stay; covers download again when they're shown online.
  Future<void> clearDownloaded() async {
    if (!supported) return;
    await for (final e in (await _covers()).list()) {
      if (e is File && !e.path.endsWith('-own.jpg')) await e.delete();
    }
    _changed();
  }
}
