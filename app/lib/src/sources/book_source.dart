/// Lookup sources. Open Library is the only one for now; others (Trove, Inventaire) can be added
/// by implementing [BookSource] and adding it to [BookLookup]'s list. See docs/book-sources.md.
library;

import '../books/models.dart';

enum CoverSize { small, medium, large }

abstract interface class BookSource {
  /// Stable id, used in cover references (`<id>:<ref>`) and stored on books.
  String get id;

  /// Name shown to the user ("Open Library").
  String get name;

  /// The edition with this ISBN-13, or null if the source doesn't know it.
  Future<Candidate?> lookupIsbn(String isbn13);

  /// Works matching a title and/or author search, best first.
  Future<List<Candidate>> search(String query);

  /// Where to download a cover this source gave as [ref], or null.
  Uri? coverUri(String ref, CoverSize size);
}

/// Tries sources in order. Adding a source is a product decision (roadmap Q7).
class BookLookup {
  BookLookup(this.sources);
  final List<BookSource> sources;

  Future<Candidate?> lookupIsbn(String isbn13) async {
    for (final s in sources) {
      final c = await s.lookupIsbn(isbn13);
      if (c != null) return c;
    }
    return null;
  }

  /// Search the first source; more sources could be merged here later.
  Future<List<Candidate>> search(String query) async => sources.isEmpty ? const [] : sources.first.search(query);

  /// Resolve a stored `<sourceId>:<ref>` cover reference.
  Uri? coverUri(String coverRef, CoverSize size) {
    final i = coverRef.indexOf(':');
    if (i <= 0) return null;
    final id = coverRef.substring(0, i);
    final source = sources.where((s) => s.id == id).firstOrNull;
    return source?.coverUri(coverRef.substring(i + 1), size);
  }
}
