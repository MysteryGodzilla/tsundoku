import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../books/isbn.dart';
import '../books/library_repository.dart';
import '../books/library_view.dart';
import 'add_flow.dart';
import 'filters_sheet.dart';
import 'book_detail_screen.dart';
import 'settings_screen.dart';
import 'sync_screens.dart';
import 'widgets.dart';

/// The library: search her own books as she types (offline), and the cover grid.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  String _query = '';
  Stream<List<LibraryBook>>? _books;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _books ??= AppScope.of(context).library.watchAll();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(LibraryBook b) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: b.id)));

  LibraryFilter _filter = LibraryFilter.none;

  /// The sort menu and the Filters button. Every filter is in the Filters sheet (her choice,
  /// 2026-11-15: no chips under the search bar).
  Widget _controls(BuildContext context, List<LibraryBook> books, SortOrder order) {
    final view = AppScope.of(context).view;
    final cs = Theme.of(context).colorScheme;
    final sync = AppScope.of(context).sync;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Only for people who sync, and only when something needs her (a product rule: no nagging).
      if (sync.decisions > 0 || sync.problemPersists)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Card(
            color: cs.primaryContainer,
            child: ListTile(
              leading: Icon(sync.decisions > 0 ? Icons.call_split : Icons.cloud_off_outlined, color: cs.onPrimaryContainer),
              title: Text(
                sync.decisions > 0
                    ? (sync.decisions == 1 ? '1 sync question needs you' : '${sync.decisions} sync questions need you')
                    : 'Sync hasn\'t worked for a while',
                style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
              ),
              trailing: Icon(Icons.chevron_right, color: cs.onPrimaryContainer),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => sync.decisions > 0 ? const DecisionsScreen() : const SettingsScreen(),
              )),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        // Sort on the left, Filters on the right.
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(
            child: PopupMenuButton<SortOrder>(
              tooltip: 'Sort',
              initialValue: order,
              onSelected: view.setSortOrder,
              itemBuilder: (_) => [for (final o in SortOrder.values) PopupMenuItem(value: o, child: Text(o.label))],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text(order.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                  ),
                  Icon(Icons.expand_more, size: 18, color: cs.onSurfaceVariant),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () async {
              final f = await showFiltersSheet(context, books, _filter);
              if (f != null) setState(() => _filter = f);
            },
            icon: Badge(
              isLabelVisible: _filter.sheetCount > 0,
              label: Text('${_filter.sheetCount}'),
              child: const Icon(Icons.tune),
            ),
            label: const Text('Filters'),
          ),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([AppScope.of(context).view, AppScope.of(context).sync]),
          builder: (context, _) => StreamBuilder<List<LibraryBook>>(
          stream: _books,
          builder: (context, snap) {
            final books = snap.data ?? const <LibraryBook>[];
            final all = LibraryRepository.pinReading(books);
            // Search always looks at the whole library: the owned check must never miss a book.
            final results = LibraryRepository.filter(all, _query);
            final searching = _query.trim().isNotEmpty;
            final order = AppScope.of(context).view.sortOrder;
            final shown = applyView(books, order, _filter);
            return CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Library', style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                        Text(
                          !snap.hasData
                              ? ''
                              : (_filter.isEmpty || searching)
                                  ? '${all.length} book${all.length == 1 ? '' : 's'}'
                                  : '${shown.length} of ${all.length} books',
                          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                    ),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: SearchBar(
                    controller: _search,
                    hintText: 'Title, author or ISBN',
                    leading: const Icon(Icons.search),
                    onChanged: (v) => setState(() => _query = v),
                    trailing: [
                      if (searching)
                        IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                        ),
                      IconButton.filled(
                        tooltip: 'Scan a barcode',
                        // SearchBar greys its trailing icons, so the colour must be set here.
                        icon: Icon(Icons.qr_code_scanner, color: cs.onPrimary),
                        onPressed: () => scanAndShow(context),
                      ),
                    ],
                  ),
                ),
              ),
              if (!snap.hasData)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (all.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _EmptyLibrary(onAdd: () => showAddBookSheet(context)))
              else if (searching)
                ..._searchResults(context, results)
              else ...[
                SliverToBoxAdapter(child: _controls(context, books, order)),
                if (shown.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                        const SizedBox(height: 24),
                        Text('No books match these filters', style: tt.titleMedium),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: () => setState(() => _filter = LibraryFilter.none), child: const Text('Show all books')),
                      ]),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 100 + MediaQuery.paddingOf(context).bottom),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        // Columns at most 140 wide, as before. Each card is the cover (2:3) plus
                        // three lines: title, author and series (her request, 2026-11-21), measured
                        // with the phone's own text size so large text never spills out.
                        const maxWidth = 140.0, spacing = 14.0;
                        final width = constraints.crossAxisExtent;
                        final columns = (width / (maxWidth + spacing)).ceil().clamp(1, 12);
                        final cell = (width - spacing * (columns - 1)) / columns;
                        final ts = MediaQuery.textScalerOf(context);
                        final lines = ts.scale(13) * 1.45 + 2 * ts.scale(12) * 1.45;
                        return SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: 18,
                            crossAxisSpacing: spacing,
                            mainAxisExtent: cell * 1.5 + 6 + lines,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            childCount: shown.length,
                            (context, i) => _GridBook(book: shown[i], onTap: () => _open(shown[i])),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ]);
          },
        ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddBookSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add book'),
      ),
    );
  }

  List<Widget> _searchResults(BuildContext context, List<LibraryBook> results) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final isbn = toIsbn13(_query);
    if (results.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 100 + MediaQuery.paddingOf(context).bottom),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Not in your library', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('You don\'t own anything matching "${_query.trim()}".', style: TextStyle(color: muted)),
                  const SizedBox(height: 16),
                  if (isbn != null)
                    FilledButton.icon(
                      onPressed: () => lookupIsbnAndShow(context, isbn),
                      icon: const Icon(Icons.search),
                      label: const Text('Look up this ISBN'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => openFind(context, initial: _query.trim()),
                      icon: const Icon(Icons.search),
                      label: const Text('Find it on Open Library'),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 100 + MediaQuery.paddingOf(context).bottom),
        sliver: SliverList.separated(
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
          itemBuilder: (context, i) {
            final b = results[i];
            return InkWell(
              onTap: () => _open(b),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BookCover(book: b, width: 56, radius: 4, compact: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(padding: EdgeInsets.only(bottom: 6), child: OwnedBadge()),
                      Text(b.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (b.authorLine.isNotEmpty) Text(b.authorLine, style: TextStyle(color: muted, fontSize: 14)),
                      Text([b.format.label, if (b.status != null) b.status!.label].join(' · '), style: TextStyle(color: muted, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ];
  }
}

class _GridBook extends StatelessWidget {
  const _GridBook({required this.book, required this.onTap});
  final LibraryBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          BookCover(book: book),
          // Her requests: status in a little bubble when set, and Kindle/Physical (2026-11-14);
          // each status its own colour and icon (2026-11-21).
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Row(children: [
              if (book.status != null) Flexible(child: StatusBubble(status: book.status!)),
              const Spacer(),
              CoverBubble(icon: formatIcon(book.format), semanticLabel: book.format.label),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(book.authorLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: muted)),
        if (book.series != null)
          Text(book.series!.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: muted, fontStyle: FontStyle.italic)),
      ]),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.auto_stories_outlined, size: 56, color: cs.tertiary),
        const SizedBox(height: 16),
        const Text('Your library is empty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Scan the barcode on a book you own to add it.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add your first book')),
      ]),
    );
  }
}
