/// Adding a book: scan, type an ISBN, search by title or author, or enter it by hand.
/// Every match is shown for her to confirm before it's added (a product rule).
library;

import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../books/isbn.dart';
import '../books/library_repository.dart';
import '../books/models.dart';
import 'book_detail_screen.dart';
import 'book_form_screen.dart';
import 'find_screen.dart';
import 'scan_screen.dart';
import 'widgets.dart';

Future<void> showAddBookSheet(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Add a book', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ListTile(leading: const Icon(Icons.qr_code_scanner), title: const Text('Scan the barcode'), onTap: () => Navigator.pop(c, 'scan')),
          ListTile(leading: const Icon(Icons.dialpad), title: const Text('Type the ISBN'), onTap: () => Navigator.pop(c, 'isbn')),
          ListTile(leading: const Icon(Icons.search), title: const Text('Search by title or author'), onTap: () => Navigator.pop(c, 'find')),
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Enter it by hand'), onTap: () => Navigator.pop(c, 'manual')),
        ]),
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case 'scan':
      await scanAndShow(context);
    case 'isbn':
      final isbn = await askForIsbn(context);
      if (isbn != null && context.mounted) await lookupIsbnAndShow(context, isbn);
    case 'find':
      await openFind(context);
    case 'manual':
      await openManualEntry(context);
  }
}

Future<void> scanAndShow(BuildContext context) async {
  final result = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanScreen()));
  if (!context.mounted || result == null) return;
  if (result == ScanScreen.typeInstead) {
    final isbn = await askForIsbn(context);
    if (isbn != null && context.mounted) await lookupIsbnAndShow(context, isbn);
  } else {
    await lookupIsbnAndShow(context, result);
  }
}

/// [scannedIsbn]: she scanned a book Open Library doesn't know and is searching for it instead.
Future<void> openFind(BuildContext context, {String initial = '', String? scannedIsbn}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => FindScreen(initialQuery: initial, scannedIsbn: scannedIsbn)));

Future<void> openManualEntry(BuildContext context, {String? isbn13, String? title}) async {
  final id = await Navigator.of(context)
      .push<String>(MaterialPageRoute(builder: (_) => BookFormScreen.create(isbn13: isbn13, title: title)));
  if (id != null && context.mounted) _showAdded(context, id, 'Book added');
}

/// A dialog for typing an ISBN (10 or 13 digits, with or without dashes).
Future<String?> askForIsbn(BuildContext context) => showDialog<String>(context: context, builder: (_) => const _IsbnDialog());

class _IsbnDialog extends StatefulWidget {
  const _IsbnDialog();
  @override
  State<_IsbnDialog> createState() => _IsbnDialogState();
}

class _IsbnDialogState extends State<_IsbnDialog> {
  final _ctl = TextEditingController();
  String? _error;

  void _submit() {
    final isbn = toIsbn13(_ctl.text);
    if (isbn == null) {
      setState(() => _error = 'That doesn\'t look like an ISBN. Check the digits under the barcode.');
      return;
    }
    Navigator.pop(context, isbn);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Type the ISBN'),
        content: TextField(
          controller: _ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '978…', errorText: _error, errorMaxLines: 3),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Look up')),
        ],
      );
}

/// Owned already (checked on the phone, so it works offline)? Show it. Otherwise ask the sources.
Future<void> lookupIsbnAndShow(BuildContext context, String isbn13) async {
  final services = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final probe = Candidate(sourceId: 'scan', title: '', isbn13: isbn13);
  final ownedNow = await services.library.findOwned(probe);
  if (!context.mounted) return;
  if (ownedNow != null) {
    await showOwnedSheet(context, ownedNow);
    return;
  }
  messenger.showSnackBar(const SnackBar(content: Text('Looking it up…'), duration: Duration(seconds: 2)));
  Candidate? found;
  try {
    found = await services.lookup.lookupIsbn(isbn13);
  } catch (_) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Open Library can\'t be reached.')));
    return;
  }
  messenger.hideCurrentSnackBar();
  if (!context.mounted) return;
  if (found == null) {
    // Often it's only this edition that's missing: search first (her choice, 2026-11-21). The
    // search offers entering it by hand when it finds nothing.
    final search = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Not found'),
        content: Text('Open Library doesn\'t know ISBN $isbn13. It may have another edition of the same book: '
            'search for it by title or author.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Search')),
        ],
      ),
    );
    if (search == true && context.mounted) await openFind(context, scannedIsbn: isbn13);
    return;
  }
  final owned = await services.library.findOwned(found);
  if (context.mounted) await showCandidateSheet(context, found, owned: owned);
}

void _showAdded(BuildContext context, String id, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    // A SnackBar with an action stays until dismissed unless told otherwise.
    persist: false,
    duration: const Duration(seconds: 5),
    action: SnackBarAction(
      label: 'Details',
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: id))),
    ),
  ));
}

/// A book she owns: the ALREADY OWNED answer, with its cover and details.
Future<void> showOwnedSheet(BuildContext context, LibraryBook book) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BookCover(book: book, width: 80, radius: 4),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const OwnedBadge(),
                  const SizedBox(height: 8),
                  Text(book.title, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  if (book.authorLine.isNotEmpty) Text(book.authorLine, style: Theme.of(c).textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text('You own it: ${book.format.label}${book.status == null ? '' : ' · ${book.status!.label}'}',
                      style: Theme.of(c).textTheme.bodyMedium?.copyWith(color: Theme.of(c).colorScheme.onSurfaceVariant)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(c);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)));
                  },
                  child: const Text('Open'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))),
            ]),
          ]),
        ),
      ),
    );

/// A match from a source, to confirm and add as Physical or Kindle. If she owns it already
/// (any edition or format), it says so instead. With [scannedIsbn] (searching after a scan Open
/// Library didn't know) the book is saved with the ISBN she scanned.
Future<void> showCandidateSheet(BuildContext context, Candidate c, {LibraryBook? owned, String? scannedIsbn}) async {
  if (owned != null) return showOwnedSheet(context, owned);
  if (scannedIsbn != null) c = c.forScannedCopy(scannedIsbn);
  final result = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CandidateSheet(candidate: c),
  );
  if (!context.mounted) return;
  if (result is OwnershipFormat) {
    final id = await AppScope.of(context).library.addFromCandidate(c, result);
    if (context.mounted) _showAdded(context, id, 'Added ${c.title}');
  } else if (result == 'manual') {
    await openManualEntry(context, isbn13: c.isbn13, title: c.title);
  }
}

class _CandidateSheet extends StatefulWidget {
  const _CandidateSheet({required this.candidate});
  final Candidate candidate;
  @override
  State<_CandidateSheet> createState() => _CandidateSheetState();
}

class _CandidateSheetState extends State<_CandidateSheet> {
  OwnershipFormat _format = OwnershipFormat.physical;

  @override
  Widget build(BuildContext context) {
    final c = widget.candidate;
    final tt = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final details = [c.publisher, c.publishedDate, c.edition].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CandidateCover(candidate: c, width: 80),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.title, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                if (c.authorLine.isNotEmpty) Text(c.authorLine, style: tt.bodyLarge),
                if (details.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(details, style: tt.bodyMedium?.copyWith(color: muted))),
                if (c.isbn13 != null) Text('ISBN ${c.isbn13}', style: tt.bodySmall?.copyWith(color: muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          Text('Is this the right book? Add it as:', style: tt.bodyLarge),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<OwnershipFormat>(
              showSelectedIcon: false,
              segments: [for (final f in OwnershipFormat.values) ButtonSegment(value: f, label: Text(f.label))],
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.first),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, _format), child: const Text('Add to library'))),
          Center(child: TextButton(onPressed: () => Navigator.pop(context, 'manual'), child: const Text('Not quite right? Enter it by hand'))),
        ]),
      ),
    );
  }
}
