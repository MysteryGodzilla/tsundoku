import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../books/library_repository.dart';
import '../books/models.dart';
import '../books/stats.dart';
import 'book_detail_screen.dart';
import 'widgets.dart';

/// Her library in numbers (her request, 2026-11-21): all books, or only Physical or only Kindle.
///
/// Order (her feedback on 0.7.0): total, reading status, finished, bought, then the fun ones. A card
/// only shows when the books have what it needs: no dates bought, no Bought card; no ratings, no
/// ratings card; fewer than two finished dates, no pace.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, this.now});

  /// Today, for tests; the real clock otherwise.
  final DateTime Function()? now;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

String _nBooks(int n) => n == 1 ? '1 book' : '$n books';

/// "Alice", "Alice and Bob", "Alice, Bob and Carol", "Alice, Bob, Carol and 2 more".
String _names(List<String> names) {
  if (names.length == 1) return names.first;
  if (names.length <= 3) return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  return '${names.take(3).join(', ')} and ${names.length - 3} more';
}

class _StatsScreenState extends State<StatsScreen> {
  /// Null for every book.
  OwnershipFormat? _format;
  late final Stream<List<LibraryBook>> _books = AppScope.of(context).library.watchAll();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = cs.onSurfaceVariant;
    Widget heading(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
          child: Text(s.toUpperCase(), style: tt.labelMedium?.copyWith(color: muted, letterSpacing: 1, fontWeight: FontWeight.w600)),
        );
    Widget number(String n, {bool dim = false}) => Text(n, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: dim ? muted : null));
    Widget row(Widget label, int n, {bool dim = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [Expanded(child: label), const SizedBox(width: 12), number('$n', dim: dim)]),
        );
    // A number with a line under its label saying what it means.
    Widget detailRow(String label, String detail, String n) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: tt.bodyLarge),
                Text(detail, style: tt.bodySmall?.copyWith(color: muted)),
              ]),
            ),
            const SizedBox(width: 12),
            number(n),
          ]),
        );
    Widget note(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(s, style: tt.bodySmall?.copyWith(color: muted)),
        );
    String notCounted(int n) => '${_nBooks(n)} ${n == 1 ? 'isn\'t' : 'aren\'t'} counted here';

    return Scaffold(
      appBar: AppBar(title: const Text('Library stats')),
      body: StreamBuilder<List<LibraryBook>>(
        stream: _books,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final now = (widget.now ?? DateTime.now)();
          final s = libraryStats(snap.data!, format: _format, now: now);
          final which = switch (_format) { null => '', OwnershipFormat.physical => ' physical', OwnershipFormat.kindle => ' Kindle' };
          final pace = s.pace, best = s.bestMonth, unread = s.oldestUnread, ratings = s.ratings;
          return ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.paddingOf(context).bottom), children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<OwnershipFormat?>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: null, label: Text('All')),
                  ButtonSegment(value: OwnershipFormat.physical, label: Text('Physical')),
                  ButtonSegment(value: OwnershipFormat.kindle, label: Text('Kindle')),
                ],
                selected: {_format},
                onSelectionChanged: (v) => setState(() => _format = v.first),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(children: [
                  Text('${s.total}', style: tt.displayMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.primary)),
                  Text(s.total == 1 ? '$which book'.trim() : '$which books'.trim(), style: tt.titleMedium?.copyWith(color: muted)),
                ]),
              ),
            ),
            if (s.anyStatus) ...[
              heading('Reading status'),
              Card(
                child: Column(children: [
                  for (final st in ReadingStatus.values) row(Align(alignment: Alignment.centerLeft, child: StatusBubble(status: st)), s.byStatus[st] ?? 0),
                  row(Text('No status', style: tt.bodyLarge?.copyWith(color: muted)), s.noStatus, dim: true),
                ]),
              ),
            ],
            if (s.finished.dated > 0) ...[
              heading('Finished reading'),
              Card(
                child: Column(children: [
                  for (final p in StatsPeriod.values) row(Text(p.label, style: tt.bodyLarge), s.finished[p]),
                  note(s.finished.undated > 0
                      ? 'Books marked Read, by the date finished. ${notCounted(s.finished.undated)}: they\'re marked Read with no date finished.'
                      : 'Books marked Read, by the date finished.'),
                  if (pace != null || best != null) const Divider(height: 1),
                  if (pace != null) ...[
                    detailRow('Pace', 'Days between finished books, on average', pace.averageDays < 1 ? 'Under 1' : '${pace.averageDays.round()}'),
                    note('From ${_nBooks(pace.books)} finished between ${formatDate(pace.first)} and ${formatDate(pace.last)}.'),
                  ],
                  if (best != null) detailRow('Best month', '${_monthNames[best.month.month - 1]} ${best.month.year}: the most books finished in a month', '${best.count}'),
                  if (best != null) const SizedBox(height: 6),
                ]),
              ),
            ],
            if (s.bought.dated > 0) ...[
              heading('Bought'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (final p in StatsPeriod.values) row(Text(p.label, style: tt.bodyLarge), s.bought[p]),
                  if (s.bought.undated > 0) note('${notCounted(s.bought.undated)}: they have no date bought.'),
                  if (unread != null) ...[
                    const Divider(height: 1),
                    InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: unread.id))),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        child: Row(children: [
                          BookCover(book: unread, width: 44, radius: 4, compact: true),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Oldest unread', style: tt.labelMedium?.copyWith(color: muted)),
                              Text(unread.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleMedium),
                              Text('Bought ${howLongAgo(unread.row.purchasedOn!, now)}, ${formatDate(unread.row.purchasedOn!)}', style: tt.bodySmall?.copyWith(color: muted)),
                            ]),
                          ),
                          Icon(Icons.chevron_right, color: muted),
                        ]),
                      ),
                    ),
                  ],
                ]),
              ),
            ],
            if (ratings != null) ...[
              heading('Your ratings'),
              Card(
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Row(children: [
                      Text(ratings.average.toStringAsFixed(1), style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: cs.primary)),
                      const SizedBox(width: 6),
                      Icon(Icons.star_rounded, size: 32, color: cs.tertiary),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Average, from ${_nBooks(ratings.rated)} rated', style: tt.bodyMedium?.copyWith(color: muted))),
                    ]),
                  ),
                  for (var i = 5; i >= 1; i--) row(Align(alignment: Alignment.centerLeft, child: StarRating(rating: i, size: 20)), ratings.byStars[i] ?? 0),
                  const SizedBox(height: 4),
                ]),
              ),
            ],
            if (s.mostRead != null || s.mostOwned != null) ...[
              heading('Authors'),
              Card(
                child: Column(children: [
                  if (s.mostRead case final a?)
                    ListTile(
                      leading: const Icon(Icons.auto_stories_outlined),
                      title: Text(_names(a.names)),
                      subtitle: Text('Most read: ${_nBooks(a.count)}${a.names.length > 1 ? ' each' : ''}'),
                    ),
                  if (s.mostOwned case final a?)
                    ListTile(
                      leading: const Icon(Icons.collections_bookmark_outlined),
                      title: Text(_names(a.names)),
                      subtitle: Text('Most owned: ${_nBooks(a.count)}${a.names.length > 1 ? ' each' : ''}'),
                    ),
                ]),
              ),
            ],
            if (s.topGenres.isNotEmpty) ...[
              heading('Top genres'),
              Card(
                child: Column(children: [
                  for (final (g, n) in s.topGenres) row(Text(g, style: tt.bodyLarge), n),
                ]),
              ),
            ],
          ]);
        },
      ),
    );
  }
}
