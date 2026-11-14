import 'package:material_ui/material_ui.dart';

import '../books/library_repository.dart';
import '../books/library_view.dart';

/// Author, genre and rating filters. Returns the new filter, or null if dismissed.
Future<LibraryFilter?> showFiltersSheet(BuildContext context, List<LibraryBook> books, LibraryFilter current) =>
    showModalBottomSheet<LibraryFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, scroll) => _FiltersSheet(books: books, initial: current, scroll: scroll),
      ),
    );

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.books, required this.initial, required this.scroll});
  final List<LibraryBook> books;
  final LibraryFilter initial;
  final ScrollController scroll;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late LibraryFilter _f = widget.initial;

  late final List<String> _authors = () {
    final byKey = <String, String>{};
    for (final b in widget.books) {
      for (final a in b.authors) {
        final parts = a.trim().split(RegExp(r'\s+'));
        byKey.putIfAbsent(a, () => '${parts.last} ${parts.join(' ')}'.toLowerCase());
      }
    }
    return byKey.keys.toList()..sort((a, b) => byKey[a]!.compareTo(byKey[b]!));
  }();

  late final List<String> _genres = {for (final b in widget.books) ...b.genres}.toList()..sort();

  static const _ratings = <RatingFilter>[AnyRating(), AtLeast(5), AtLeast(4), AtLeast(3), AtLeast(2), AtLeast(1), NotRated()];

  Set<String> _toggle(Set<String> s, String v) => s.contains(v) ? ({...s}..remove(v)) : {...s, v};

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget heading(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
          child: Text(s.toUpperCase(), style: tt.labelMedium?.copyWith(color: muted, letterSpacing: 1, fontWeight: FontWeight.w600)),
        );
    final matching = widget.books.where(_f.matches).length;
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 12, 0),
          child: Row(children: [
            Expanded(child: Text('Filters', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
            TextButton(onPressed: () => setState(() => _f = LibraryFilter.none), child: const Text('Clear all')),
          ]),
        ),
        Expanded(
          child: ListView(controller: widget.scroll, padding: const EdgeInsets.fromLTRB(24, 0, 24, 16), children: [
            heading('Rating'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in _ratings)
                ChoiceChip(label: Text(r.label), selected: _f.rating == r, showCheckmark: false, onSelected: (_) => setState(() => _f = _f.copyWith(rating: r))),
            ]),
            if (_genres.isNotEmpty) ...[
              heading('Genre'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final g in _genres)
                  FilterChip(label: Text(g), selected: _f.genres.contains(g), onSelected: (_) => setState(() => _f = _f.copyWith(genres: _toggle(_f.genres, g)))),
              ]),
            ],
            if (_authors.isNotEmpty) ...[
              heading('Author'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in _authors)
                  FilterChip(label: Text(a), selected: _f.authors.contains(a), onSelected: (_) => setState(() => _f = _f.copyWith(authors: _toggle(_f.authors, a)))),
              ]),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _f),
              child: Text(matching == 1 ? 'Show 1 book' : 'Show $matching books'),
            ),
          ),
        ),
      ]),
    );
  }
}
