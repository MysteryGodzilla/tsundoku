/// Turning a source's long, messy subject lists into a few tidy genres. Open Library's subjects
/// mix genres with tags like "New York Times bestseller", so only known genres are kept.
library;

const _rules = <(String genre, List<String> keywords)>[
  ('Science fiction', ['science fiction', 'sci-fi']),
  ('Fantasy', ['fantasy']),
  ('Mystery', ['mystery', 'detective']),
  ('Crime', ['crime']),
  ('Thriller', ['thriller', 'suspense']),
  ('Horror', ['horror']),
  ('Romance', ['romance', 'love stories']),
  ('Historical fiction', ['historical fiction']),
  ('Young adult', ['young adult']),
  ('Children', ['juvenile', "children's"]),
  ('Graphic novels', ['graphic novel', 'comic']),
  ('Poetry', ['poetry']),
  ('Short stories', ['short stories']),
  ('Classics', ['classic']),
  ('Biography', ['biography', 'autobiography']),
  ('Memoir', ['memoir']),
  ('History', ['history']),
  ('Cooking', ['cooking', 'cookbook', 'recipes']),
  ('Travel', ['travel']),
  ('Self-help', ['self-help', 'self help']),
  ('Science', ['science']),
  ('Humour', ['humor', 'humour']),
  ('Art', ['art']),
];

/// Up to [max] genres suggested from [subjects], in the order the subjects give them.
List<String> genresFromSubjects(List<String> subjects, {int max = 3}) {
  final found = <String>[];
  final hasFiction = subjects.any((s) => RegExp(r'\bfiction\b', caseSensitive: false).hasMatch(s));
  for (final s in subjects) {
    final lower = s.toLowerCase();
    for (final (genre, keywords) in _rules) {
      if (found.contains(genre)) continue;
      // "History" for a novel is usually "Historical fiction", already handled.
      if (genre == 'History' && hasFiction) continue;
      if (genre == 'Science' && lower.contains('science fiction')) continue;
      if (keywords.any((k) => RegExp('\\b${RegExp.escape(k)}', caseSensitive: false).hasMatch(lower))) {
        found.add(genre);
      }
    }
    if (found.length >= max) break;
  }
  if (found.isEmpty && hasFiction) found.add('Fiction');
  return found.take(max).toList();
}
