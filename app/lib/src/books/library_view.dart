/// Sorting and filtering the library (Phase 2). Searching ignores these on purpose: the owned
/// check must always look at the whole library.
library;

import 'isbn.dart';
import 'library_repository.dart';
import 'models.dart';

enum SortOrder {
  recent('Recently added'),
  title('Title'),
  author('Author'),
  rating('Rating');

  const SortOrder(this.label);
  final String label;

  static SortOrder parse(String? s) => SortOrder.values.firstWhere((o) => o.name == s, orElse: () => SortOrder.recent);
}

/// Rating filter: any, at least N stars, or not rated.
sealed class RatingFilter {
  const RatingFilter();
  bool matches(int? rating);
  String get label;
}

class AnyRating extends RatingFilter {
  const AnyRating();
  @override
  bool matches(int? rating) => true;
  @override
  String get label => 'Any';
  @override
  bool operator ==(Object other) => other is AnyRating;
  @override
  int get hashCode => 0;
}

class AtLeast extends RatingFilter {
  const AtLeast(this.stars);
  final int stars;
  @override
  bool matches(int? rating) => rating != null && rating >= stars;
  @override
  String get label => stars == 5 ? '5 stars' : '$stars+ stars';
  @override
  bool operator ==(Object other) => other is AtLeast && other.stars == stars;
  @override
  int get hashCode => stars;
}

class NotRated extends RatingFilter {
  const NotRated();
  @override
  bool matches(int? rating) => rating == null;
  @override
  String get label => 'Not rated';
  @override
  bool operator ==(Object other) => other is NotRated;
  @override
  int get hashCode => -1;
}

/// What she has chosen to see. Within a group any choice matches (Kindle or Physical); across
/// groups all must match (Kindle and Reading).
class LibraryFilter {
  const LibraryFilter({
    this.formats = const {},
    this.statuses = const {},
    this.authors = const {},
    this.genres = const {},
    this.rating = const AnyRating(),
  });

  final Set<OwnershipFormat> formats;
  final Set<ReadingStatus> statuses;
  final Set<String> authors;
  final Set<String> genres;
  final RatingFilter rating;

  static const none = LibraryFilter();

  bool get isEmpty => formats.isEmpty && statuses.isEmpty && authors.isEmpty && genres.isEmpty && rating is AnyRating;

  /// How many choices are made in the Filters sheet (every filter lives there), for its button's badge.
  int get sheetCount => formats.length + statuses.length + authors.length + genres.length + (rating is AnyRating ? 0 : 1);

  LibraryFilter copyWith({
    Set<OwnershipFormat>? formats,
    Set<ReadingStatus>? statuses,
    Set<String>? authors,
    Set<String>? genres,
    RatingFilter? rating,
  }) =>
      LibraryFilter(
        formats: formats ?? this.formats,
        statuses: statuses ?? this.statuses,
        authors: authors ?? this.authors,
        genres: genres ?? this.genres,
        rating: rating ?? this.rating,
      );

  bool matches(LibraryBook b) =>
      (formats.isEmpty || formats.contains(b.format)) &&
      (statuses.isEmpty || (b.status != null && statuses.contains(b.status))) &&
      (authors.isEmpty || b.authors.any(authors.contains)) &&
      (genres.isEmpty || b.genres.any(genres.contains)) &&
      rating.matches(b.row.rating);
}

/// "Stephen King" sorts under K, like a bookshop: surname first, then the rest.
String authorSortKey(LibraryBook b) {
  if (b.authors.isEmpty) return '\u{10FFFF}'; // No author: last.
  final parts = normaliseForMatch(b.authors.first).split(' ');
  return parts.length == 1 ? parts.first : '${parts.last} ${parts.sublist(0, parts.length - 1).join(' ')}';
}

String titleSortKey(LibraryBook b) => normaliseForMatch(b.title);

/// Filter, then sort. In "Recently added" the books she's Reading come first (her rule); in the
/// other orders Reading is the tie-breaker: among the same author, title or rating, Reading first.
List<LibraryBook> applyView(List<LibraryBook> books, SortOrder order, LibraryFilter filter) {
  final shown = filter.isEmpty ? List.of(books) : books.where(filter.matches).toList();
  if (order == SortOrder.recent) return LibraryRepository.pinReading(shown);

  int readingFirst(LibraryBook a, LibraryBook b) =>
      (b.status == ReadingStatus.reading ? 1 : 0) - (a.status == ReadingStatus.reading ? 1 : 0);
  int byTitle(LibraryBook a, LibraryBook b) => titleSortKey(a).compareTo(titleSortKey(b));

  final int Function(LibraryBook, LibraryBook) primary = switch (order) {
    SortOrder.title => byTitle,
    SortOrder.author => (a, b) => authorSortKey(a).compareTo(authorSortKey(b)),
    SortOrder.rating => (a, b) => (b.row.rating ?? -1).compareTo(a.row.rating ?? -1),
    SortOrder.recent => (a, b) => 0,
  };
  shown.sort((a, b) {
    final p = primary(a, b);
    if (p != 0) return p;
    final r = readingFirst(a, b);
    if (r != 0) return r;
    return order == SortOrder.title ? b.row.addedAt.compareTo(a.row.addedAt) : byTitle(a, b);
  });
  return shown;
}
