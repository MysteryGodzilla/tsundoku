import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../books/library_repository.dart';
import '../books/models.dart';
import '../books/stats.dart';
import 'widgets.dart';

/// Her library in numbers (her request, 2026-11-21): all books, or only Physical or only Kindle.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, this.now});

  /// Today, for tests; the real clock otherwise.
  final DateTime Function()? now;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /// Null for every book.
  OwnershipFormat? _format;
  late final Stream<List<LibraryBook>> _books = AppScope.of(context).library.watchAll();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget heading(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
          child: Text(s.toUpperCase(), style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1, fontWeight: FontWeight.w600)),
        );
    Widget row(Widget label, int n, {bool muted = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(child: label),
            Text('$n', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: muted ? cs.onSurfaceVariant : null)),
          ]),
        );
    Widget note(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(s, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        );
    String books(int n) => n == 1 ? '1 book' : '$n books';

    return Scaffold(
      appBar: AppBar(title: const Text('Library stats')),
      body: StreamBuilder<List<LibraryBook>>(
        stream: _books,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final s = libraryStats(snap.data!, format: _format, now: (widget.now ?? DateTime.now)());
          final which = switch (_format) { null => '', OwnershipFormat.physical => ' physical', OwnershipFormat.kindle => ' Kindle' };
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
                  Text(s.total == 1 ? '$which book'.trim() : '$which books'.trim(), style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
            ),
            heading('Reading status'),
            Card(
              child: Column(children: [
                for (final st in ReadingStatus.values) row(Align(alignment: Alignment.centerLeft, child: StatusBubble(status: st)), s.byStatus[st] ?? 0),
                row(Text('No status', style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)), s.noStatus, muted: true),
              ]),
            ),
            heading('Bought'),
            Card(
              child: Column(children: [
                for (final p in StatsPeriod.values) row(Text(p.label, style: tt.bodyLarge), s.bought[p]),
                if (s.bought.undated > 0) note('${books(s.bought.undated)} with no date bought ${s.bought.undated == 1 ? 'isn\'t' : 'aren\'t'} counted here.'),
              ]),
            ),
            heading('Finished reading'),
            Card(
              child: Column(children: [
                for (final p in StatsPeriod.values) row(Text(p.label, style: tt.bodyLarge), s.finished[p]),
                note(s.finished.undated > 0
                    ? 'Books marked Read, by the date finished. ${books(s.finished.undated)} marked Read with no date finished '
                        '${s.finished.undated == 1 ? 'isn\'t' : 'aren\'t'} counted here.'
                    : 'Books marked Read, by the date finished.'),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
