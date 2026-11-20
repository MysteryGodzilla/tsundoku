/// Fills in the series of books added before the app knew about series, or added before the
/// lookup answered (her request, 2026-11-21). Quiet: no messages, and offline it just tries again
/// next time the app opens.
library;

import '../sources/book_source.dart';
import 'library_repository.dart';
import 'models.dart';

class SeriesFiller {
  SeriesFiller({required this.library, required this.lookup});
  final LibraryRepository library;
  final BookLookup lookup;

  bool _running = false;

  /// Marks a book as looked at, so it's never asked about again (even if it has no series, or she
  /// clears the one it found).
  static String checkedKey(String bookId) => 'seriesChecked:$bookId';

  Future<void> markChecked(String bookId) => library.setMeta(checkedKey(bookId), '1');

  /// Looks up each book that has a source identifier, no series and hasn't been looked at.
  /// Returns how many got a series. Stops at the first lookup that can't reach the source.
  Future<int> run() async {
    if (_running) return 0;
    _running = true;
    var filled = 0;
    try {
      for (final b in await library.allBooks()) {
        if (b.series != null || !b.identifiers.any((i) => i.scheme == Schemes.openLibraryWork)) continue;
        if (await library.getMeta(checkedKey(b.id)) != null) continue;
        final BookSeries? found;
        try {
          found = await lookup.seriesFor(b.identifiers);
        } catch (_) {
          break; // Offline or the source is down: try again another time.
        }
        // She may have typed a series meanwhile; never overwrite hers.
        final now = await library.getBook(b.id);
        if (found != null && now != null && now.series == null) {
          await library.update(b.id, BookChanges(series: found.name, seriesPosition: found.position));
          filled++;
        }
        await markChecked(b.id);
      }
    } finally {
      _running = false;
    }
    return filled;
  }
}
