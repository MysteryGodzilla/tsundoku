import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../books/library_repository.dart';
import '../books/models.dart';
import 'book_form_screen.dart';
import 'widgets.dart';

class BookDetailScreen extends StatefulWidget {
  const BookDetailScreen({super.key, required this.bookId});
  final String bookId;

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  Stream<LibraryBook?>? _book;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _book ??= AppScope.of(context).library.watchBook(widget.bookId);
  }

  LibraryRepository get _repo => AppScope.of(context).library;

  Future<void> _delete(LibraryBook b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this book?'),
        content: Text('"${b.title}" will be removed from your library for good. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error, foregroundColor: Theme.of(c).colorScheme.onError),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final services = AppScope.of(context);
    final nav = Navigator.of(context);
    await services.library.delete(b.id);
    await services.covers.deleteFor(b.id);
    nav.pop();
  }

  Future<void> _pickPurchased(LibraryBook b) async {
    final d = await _pickDate(b.row.purchasedOn, 'Date purchased');
    if (d != null) await _repo.update(b.id, BookChanges(purchasedOn: d));
  }

  Future<void> _pickFinished(LibraryBook b) async {
    final d = await _pickDate(b.row.finishedOn, b.status == ReadingStatus.dnf ? 'Date you stopped' : 'Date you finished it');
    if (d != null) await _repo.update(b.id, BookChanges(finishedOn: d));
  }

  Future<DateTime?> _pickDate(DateTime? current, String help) {
    final now = DateTime.now();
    return showDatePicker(context: context, initialDate: current ?? now, firstDate: DateTime(1900), lastDate: now, helpText: help);
  }

  /// An optional date with a button to set it and a cross to clear it.
  Widget _dateRow(DateTime? value, String empty, VoidCallback onPick, VoidCallback onClear, String clearTip) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, side: BorderSide(color: cs.outlineVariant), foregroundColor: cs.onSurface),
          onPressed: onPick,
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(value == null ? empty : formatDate(value)),
        ),
      ),
      if (value != null) IconButton(tooltip: clearTip, icon: const Icon(Icons.close), onPressed: onClear),
    ]);
  }

  Future<void> _editNotes(LibraryBook b) async {
    final ctl = TextEditingController(text: b.row.notes ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Notes'),
        content: SizedBox(
          width: 400,
          child: TextField(controller: ctl, autofocus: true, minLines: 4, maxLines: 10, textCapitalization: TextCapitalization.sentences),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('Save')),
        ],
      ),
    );
    if (text == null) return;
    final t = text.trim();
    await _repo.update(b.id, t.isEmpty ? const BookChanges(clear: {'notes'}) : BookChanges(notes: t));
  }

  Future<void> _addGenre(LibraryBook b) async {
    final known = await _repo.allGenres();
    if (!mounted) return;
    final suggestions = {
      ...known,
      'Fiction', 'Non-fiction', 'Fantasy', 'Science fiction', 'Mystery', 'Crime', 'Thriller', 'Romance', 'Historical fiction',
      'Horror', 'Biography', 'Memoir', 'History', 'Poetry', 'Young adult', 'Children', 'Classics', 'Cooking', 'Self-help',
    }.where((g) => !b.genres.contains(g)).toList()
      ..sort();
    final ctl = TextEditingController();
    final g = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add a genre'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: ctl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Type a genre'),
                onSubmitted: (v) => Navigator.pop(c, v),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in suggestions) ActionChip(label: Text(s), onPressed: () => Navigator.pop(c, s)),
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('Add')),
        ],
      ),
    );
    if (g != null && g.trim().isNotEmpty) await _repo.setGenres(b.id, [...b.genres, g.trim()]);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LibraryBook?>(
      stream: _book,
      builder: (context, snap) {
        final b = snap.data;
        if (b == null) {
          return Scaffold(appBar: AppBar(), body: snap.connectionState == ConnectionState.waiting ? const Center(child: CircularProgressIndicator()) : null);
        }
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final muted = cs.onSurfaceVariant;
        Widget heading(String s) => Padding(
              padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
              child: Text(s.toUpperCase(), style: tt.labelMedium?.copyWith(color: muted, letterSpacing: 1, fontWeight: FontWeight.w600)),
            );
        final details = <(String, String)>[
          if (b.row.isbn13 != null) ('ISBN', b.row.isbn13!),
          if (b.row.publisher != null) ('Publisher', b.row.publisher!),
          if (b.row.publishedDate != null) ('Published', b.row.publishedDate!),
          if (b.row.edition != null) ('Edition', b.row.edition!),
          ('Added', formatDate(b.row.addedAt)),
        ];
        return Scaffold(
          appBar: AppBar(actions: [
            IconButton(
              tooltip: 'Edit details',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookFormScreen.edit(book: b))),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) => v == 'delete' ? _delete(b) : null,
              itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete book'))],
            ),
          ]),
          body: ListView(padding: EdgeInsets.fromLTRB(20, 0, 20, 48 + MediaQuery.paddingOf(context).bottom), children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BookCover(book: b, width: 120),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.title, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  if (b.authorLine.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(b.authorLine, style: tt.titleMedium?.copyWith(color: muted))),
                  const SizedBox(height: 12),
                  Chip(
                    avatar: Icon(formatIcon(b.format), size: 18),
                    label: Text(b.format.label),
                  ),
                ]),
              ),
            ]),
            heading('Reading status'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in ReadingStatus.values)
                ChoiceChip(
                  label: Text(s.label),
                  tooltip: s.longLabel,
                  selected: b.status == s,
                  onSelected: (on) => _repo.update(b.id, on ? BookChanges(status: s) : const BookChanges(clear: {'status'})),
                ),
            ]),
            heading('Your rating'),
            StarRating(
              rating: b.row.rating,
              onChanged: (r) => _repo.update(b.id, r == null ? const BookChanges(clear: {'rating'}) : BookChanges(rating: r)),
            ),
            // Her choice (2026-11-14): the date only shows once a book is Read or DNF. If the status
            // changes back, the date is kept (hidden) and returns when it's Read or DNF again.
            if (b.status == ReadingStatus.read || b.status == ReadingStatus.dnf) ...[
              heading(b.status == ReadingStatus.read ? 'Finished reading' : 'Stopped reading'),
              _dateRow(
                b.row.finishedOn,
                b.status == ReadingStatus.read ? 'Add the date you finished it' : 'Add the date you stopped',
                () => _pickFinished(b),
                () => _repo.update(b.id, const BookChanges(clear: {'finishedOn'})),
                'Clear date',
              ),
            ],
            heading('Purchased'),
            _dateRow(b.row.purchasedOn, 'Add the date you bought it', () => _pickPurchased(b),
                () => _repo.update(b.id, const BookChanges(clear: {'purchasedOn'})), 'Clear purchase date'),
            heading('Genres'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in b.genres)
                InputChip(label: Text(g), onDeleted: () => _repo.setGenres(b.id, b.genres.where((x) => x != g).toList()), deleteButtonTooltipMessage: 'Remove $g'),
              ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Add genre'), onPressed: () => _addGenre(b)),
            ]),
            heading('Notes'),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _editNotes(b),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                      child: Text(b.row.notes ?? 'Add a note', style: TextStyle(color: b.row.notes == null ? muted : cs.onSurface, fontSize: 15, height: 1.4)),
                    ),
                    Icon(Icons.edit_outlined, size: 18, color: muted),
                  ]),
                ),
              ),
            ),
            heading('Details'),
            for (final (k, v) in details)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 100, child: Text(k, style: TextStyle(color: muted))),
                  Expanded(child: SelectableText(v)),
                ]),
              ),
          ]),
        );
      },
    );
  }
}
