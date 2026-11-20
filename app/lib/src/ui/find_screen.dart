import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../books/library_repository.dart';
import '../books/models.dart';
import 'add_flow.dart';
import 'widgets.dart';

/// Search Open Library by title and/or author, with ALREADY OWNED on books she has.
class FindScreen extends StatefulWidget {
  const FindScreen({super.key, this.initialQuery = '', this.scannedIsbn});
  final String initialQuery;

  /// Searching after a scan Open Library didn't know: whatever she adds keeps this ISBN.
  final String? scannedIsbn;

  @override
  State<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
  late final _ctl = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  int _seq = 0;
  List<(Candidate, LibraryBook?)> _results = const [];
  String? _message;
  bool _loading = false;

  /// A search ran and found nothing: entering it by hand becomes the way on.
  bool _nothing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().length >= 3) WidgetsBinding.instance.addPostFrameCallback((_) => _run(widget.initialQuery));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _changed(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _run(q));
  }

  Future<void> _run(String q) async {
    final mine = ++_seq;
    if (q.trim().length < 3) {
      setState(() {
        _results = const [];
        _message = null;
        _nothing = false;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final services = AppScope.of(context);
    try {
      final found = await services.lookup.search(q);
      final withOwned = <(Candidate, LibraryBook?)>[];
      for (final c in found) {
        withOwned.add((c, await services.library.findOwned(c)));
      }
      if (mine != _seq || !mounted) return;
      setState(() {
        _results = withOwned;
        _message = found.isEmpty ? 'Nothing found on Open Library. Try fewer words, or just the title.' : null;
        _nothing = found.isEmpty;
        _loading = false;
      });
    } catch (_) {
      if (mine != _seq || !mounted) return;
      setState(() {
        _results = const [];
        _message = 'Open Library can\'t be reached.';
        _nothing = false;
        _loading = false;
      });
    }
  }

  /// After she adds a book, mark it (and other editions of it) ALREADY OWNED straight away.
  Future<void> _refreshOwned() async {
    if (!mounted) return;
    final library = AppScope.of(context).library;
    final updated = <(Candidate, LibraryBook?)>[for (final (c, _) in _results) (c, await library.findOwned(c))];
    if (mounted) setState(() => _results = updated);
  }

  void _enterByHand() => openManualEntry(
        context,
        isbn13: widget.scannedIsbn,
        title: _ctl.text.trim().isEmpty ? null : _ctl.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final searched = _results.isNotEmpty || _nothing;
    return Scaffold(
      appBar: AppBar(title: const Text('Find a book')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SearchBar(
            controller: _ctl,
            autoFocus: widget.initialQuery.isEmpty,
            hintText: 'Title and/or author',
            leading: const Icon(Icons.search),
            onChanged: _changed,
            onSubmitted: _run,
          ),
        ),
        if (widget.scannedIsbn != null && !searched)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Search for the book you scanned. Whichever edition you add, it\'s saved with your copy\'s ISBN '
              '(${widget.scannedIsbn}), so scanning it next time shows you own it.',
              style: TextStyle(color: muted),
            ),
          ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_message != null) Padding(padding: const EdgeInsets.all(16), child: Text(_message!, style: TextStyle(color: muted))),
        if (_nothing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(width: double.infinity, child: FilledButton(onPressed: _enterByHand, child: const Text('Enter it by hand'))),
          ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(bottom: 16 + MediaQuery.paddingOf(context).bottom),
            // After the results, a quieter way to enter it by hand (none before she has searched).
            itemCount: _results.length + (_results.isEmpty ? 0 : 1),
            separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
            itemBuilder: (context, i) {
              if (i == _results.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: TextButton(onPressed: _enterByHand, child: const Text('Can\'t find it? Enter it by hand')),
                  ),
                );
              }
              final (c, owned) = _results[i];
              final meta = [c.authorLine, c.publishedDate].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
              return InkWell(
                onTap: () async {
                  await showCandidateSheet(context, c, owned: owned, scannedIsbn: widget.scannedIsbn);
                  await _refreshOwned();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CandidateCover(candidate: c, width: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (owned != null) const Padding(padding: EdgeInsets.only(bottom: 6), child: OwnedBadge()),
                        Text(c.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        if (meta.isNotEmpty) Text(meta, style: TextStyle(color: muted, fontSize: 14)),
                        if (owned != null) Text('You own it: ${owned.format.label}', style: TextStyle(color: muted, fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
