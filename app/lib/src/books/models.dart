/// Shared book types: what a lookup source returns, and the owner's own choices.
library;

/// Physical or Kindle: the owner's choice, never a source's free-text format.
enum OwnershipFormat {
  physical('Physical'),
  kindle('Kindle');

  const OwnershipFormat(this.label);
  final String label;

  static OwnershipFormat parse(String? s) =>
      OwnershipFormat.values.firstWhere((f) => f.name == s, orElse: () => OwnershipFormat.physical);
}

/// The only four reading statuses (a product rule). Blank by default; never set automatically.
enum ReadingStatus {
  tbr('TBR', 'To be read'),
  reading('Reading', 'Reading'),
  read('Read', 'Read'),
  dnf('DNF', 'Did not finish');

  const ReadingStatus(this.label, this.longLabel);
  final String label;
  final String longLabel;

  static ReadingStatus? parse(String? s) => ReadingStatus.values.where((v) => v.name == s).firstOrNull;
}

/// Identifier schemes a book can carry. More are added with new sources (e.g. `trove:work`).
abstract final class Schemes {
  static const isbn13 = 'isbn13';
  static const openLibraryWork = 'openlibrary:work';
  static const openLibraryEdition = 'openlibrary:edition';
}

class Identifier {
  const Identifier(this.scheme, this.value);
  final String scheme;
  final String value;

  @override
  bool operator ==(Object other) => other is Identifier && other.scheme == scheme && other.value == value;
  @override
  int get hashCode => Object.hash(scheme, value);
  @override
  String toString() => '$scheme:$value';
}

/// A book as a lookup source describes it, before it's in the library.
class Candidate {
  const Candidate({
    required this.sourceId,
    required this.title,
    this.authors = const [],
    this.isbn13,
    this.publisher,
    this.publishedDate,
    this.edition,
    this.subjects = const [],
    this.coverRef,
    this.identifiers = const [],
  });

  /// Which [BookSource] it came from (e.g. `openlibrary`).
  final String sourceId;
  final String title;
  final List<String> authors;
  final String? isbn13;
  final String? publisher;
  final String? publishedDate;

  /// Edition or format text from the source ("Paperback", "Kindle Edition"); informational only.
  final String? edition;
  final List<String> subjects;

  /// A source-specific cover reference, resolved by that source (e.g. an Open Library cover ID).
  final String? coverRef;
  final List<Identifier> identifiers;

  String get authorLine => authors.join(', ');

  /// Identifiers including the ISBN, for the owned check.
  List<Identifier> get allIdentifiers => [
        ...identifiers,
        if (isbn13 != null && !identifiers.any((i) => i.scheme == Schemes.isbn13)) Identifier(Schemes.isbn13, isbn13!),
      ];

  /// The same book, for her copy with ISBN [scanned]: another edition found by searching after a
  /// scan Open Library didn't know. Her ISBN becomes the book's ISBN and is kept with the others,
  /// so scanning that copy again finds it ALREADY OWNED.
  Candidate forScannedCopy(String scanned) => Candidate(
        sourceId: sourceId,
        title: title,
        authors: authors,
        isbn13: scanned,
        publisher: publisher,
        publishedDate: publishedDate,
        edition: edition,
        subjects: subjects,
        coverRef: coverRef,
        identifiers: [...allIdentifiers, Identifier(Schemes.isbn13, scanned)],
      );
}
