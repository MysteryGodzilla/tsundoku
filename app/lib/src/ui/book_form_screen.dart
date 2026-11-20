import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_scope.dart';
import '../books/isbn.dart';
import '../books/library_repository.dart';
import '../books/models.dart';
import 'widgets.dart';

/// Enter a book by hand, or edit a book's details and cover. A book saves with only a title:
/// no ISBN (common for Kindle), cover or other details needed (a product rule).
class BookFormScreen extends StatefulWidget {
  const BookFormScreen.create({super.key, this.isbn13, this.title}) : book = null;
  const BookFormScreen.edit({super.key, required LibraryBook this.book})
      : isbn13 = null,
        title = null;

  final LibraryBook? book;
  final String? isbn13;
  final String? title;

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.book?.title ?? widget.title ?? '');
  late final _authors = TextEditingController(text: widget.book?.authorLine ?? '');
  late final _isbn = TextEditingController(text: widget.book?.row.isbn13 ?? widget.isbn13 ?? '');
  late final _publisher = TextEditingController(text: widget.book?.row.publisher ?? '');
  late final _published = TextEditingController(text: widget.book?.row.publishedDate ?? '');
  late final _series = TextEditingController(text: widget.book?.row.series ?? '');
  late final _seriesNumber = TextEditingController(text: widget.book?.row.seriesPosition ?? '');
  late OwnershipFormat _format = widget.book?.format ?? OwnershipFormat.physical;

  /// A new photo to save, or [_removePhoto] to go back to the downloaded cover.
  Uint8List? _photo;
  bool _removePhoto = false;
  bool _saving = false;

  bool get _editing => widget.book != null;

  @override
  void dispose() {
    for (final c in [_title, _authors, _isbn, _publisher, _published, _series, _seriesNumber]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    // The app declares camera permission (for scanning), so Android needs it granted before the
    // camera app can be opened for a photo.
    if (source == ImageSource.camera && !(await Permission.camera.request()).isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tsundoku needs the camera to take a cover photo.')));
      }
      return;
    }
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 1200, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() {
        _photo = bytes;
        _removePhoto = false;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn\'t open the camera or photos.')));
      }
    }
  }

  String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
  List<String> get _authorList => _authors.text.split(RegExp(r'[,;]')).map((a) => a.trim()).where((a) => a.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final services = AppScope.of(context);
    final nav = Navigator.of(context);
    final isbn = _isbn.text.trim().isEmpty ? null : toIsbn13(_isbn.text);
    String id;
    if (_editing) {
      id = widget.book!.id;
      final b = widget.book!;
      await services.library.update(
        id,
        BookChanges(
          title: _title.text.trim(),
          authors: _authorList,
          isbn13: isbn,
          publisher: _opt(_publisher),
          publishedDate: _opt(_published),
          format: _format,
          series: _opt(_series),
          seriesPosition: _opt(_series) == null ? null : _opt(_seriesNumber),
          clear: {
            if (isbn == null && b.row.isbn13 != null) 'isbn13',
            if (_opt(_publisher) == null && b.row.publisher != null) 'publisher',
            if (_opt(_published) == null && b.row.publishedDate != null) 'publishedDate',
            if (_opt(_series) == null && b.row.series != null) 'series',
            if ((_opt(_series) == null || _opt(_seriesNumber) == null) && b.row.seriesPosition != null) 'seriesPosition',
          },
        ),
      );
    } else {
      final dup = await services.library.findOwned(Candidate(
        sourceId: 'manual',
        title: _title.text.trim(),
        authors: _authorList,
        isbn13: isbn,
      ));
      if (dup != null && mounted) {
        final go = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Already owned?'),
            content: Text('You already have "${dup.title}"${dup.authorLine.isEmpty ? '' : ' by ${dup.authorLine}'} (${dup.format.label}). Add this one anyway?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add anyway')),
            ],
          ),
        );
        if (go != true) {
          setState(() => _saving = false);
          return;
        }
      }
      id = await services.library.addManual(
        title: _title.text.trim(),
        authors: _authorList,
        isbn13: isbn,
        publisher: _opt(_publisher),
        publishedDate: _opt(_published),
        format: _format,
        series: _opt(_series) == null ? null : BookSeries(_opt(_series)!, _opt(_seriesNumber)),
      );
    }
    if (_photo != null) {
      await services.covers.saveOwnPhoto(id, _photo!);
      await services.library.update(id, const BookChanges(ownCover: true));
    } else if (_removePhoto) {
      await services.covers.removeOwnPhoto(id);
      await services.library.update(id, const BookChanges(ownCover: false));
    }
    nav.pop(_editing ? null : id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasOwn = (widget.book?.hasOwnCover ?? false) && !_removePhoto;
    Widget cover;
    if (_photo != null) {
      cover = ClipRRect(borderRadius: BorderRadius.circular(6), child: AspectRatio(aspectRatio: 2 / 3, child: Image.memory(_photo!, fit: BoxFit.cover)));
    } else if (widget.book != null && !_removePhoto) {
      cover = BookCover(book: widget.book!);
    } else {
      cover = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: AspectRatio(aspectRatio: 2 / 3, child: PlaceholderCover(title: _title.text.isEmpty ? 'New book' : _title.text, author: _authors.text)),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit details' : 'Enter a book'),
        actions: [Padding(padding: const EdgeInsets.only(right: 8), child: TextButton(onPressed: _saving ? null : _save, child: const Text('Save')))],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: EdgeInsets.fromLTRB(20, 8, 20, 48 + MediaQuery.paddingOf(context).bottom), children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: cover),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                OutlinedButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Take photo')),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Choose photo')),
                if (_photo != null || hasOwn)
                  TextButton(
                    onPressed: () => setState(() {
                      _photo = null;
                      _removePhoto = hasOwn;
                    }),
                    child: const Text('Remove my photo'),
                  ),
              ]),
            ),
          ]),
          const SizedBox(height: 24),
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'A title is needed' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _authors,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Author', helperText: 'Separate several authors with commas'),
          ),
          const SizedBox(height: 14),
          Text('Format', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
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
          TextFormField(
            controller: _isbn,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'ISBN (optional)', helperText: 'Kindle books often don\'t have one'),
            validator: (v) => (v ?? '').trim().isEmpty || toIsbn13(v!) != null ? null : 'That doesn\'t look like an ISBN',
          ),
          const SizedBox(height: 14),
          TextFormField(controller: _publisher, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Publisher (optional)')),
          const SizedBox(height: 14),
          TextFormField(controller: _published, decoration: const InputDecoration(labelText: 'Published (optional)', hintText: 'e.g. 2021')),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _series,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Series (optional)', hintText: 'e.g. Dune'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(controller: _seriesNumber, decoration: const InputDecoration(labelText: 'Book number', hintText: 'e.g. 3')),
            ),
          ]),
          const SizedBox(height: 28),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_editing ? 'Save changes' : 'Add to library')),
        ]),
      ),
    );
  }
}
