import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../books/isbn.dart';
import '../books/library_repository.dart';
import 'add_flow.dart';
import 'book_detail_screen.dart';
import 'settings_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<LibraryBook>>(
          stream: _books,
          builder: (context, snap) {
            final all = LibraryRepository.pinReading(snap.data ?? const <LibraryBook>[]);
            final results = LibraryRepository.filter(all, _query);
            final searching = _query.trim().isNotEmpty;
            return CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Library', style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                        Text(snap.hasData ? '${all.length} book${all.length == 1 ? '' : 's'}' : '', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
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
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 140,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.52,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      childCount: all.length,
                      (context, i) => _GridBook(book: all[i], onTap: () => _open(all[i])),
                    ),
                  ),
                ),
            ]);
          },
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
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
          // Her request (2026-11-14): status in a little bubble when set, and Kindle/Physical.
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Row(children: [
              if (book.status != null) CoverBubble(label: book.status!.label),
              const Spacer(),
              CoverBubble(icon: formatIcon(book.format), semanticLabel: book.format.label),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(book.authorLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: muted)),
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
