/// Small shared pieces: covers, the ALREADY OWNED badge, stars.
library;

import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import '../books/library_repository.dart';
import '../books/models.dart';
import '../sources/book_source.dart';
import '../theme/palette.dart';

/// A drawn cover for books with no image, in the mock-ups' muted colours.
class PlaceholderCover extends StatelessWidget {
  const PlaceholderCover({super.key, required this.title, required this.author, this.compact = false});
  final String title;
  final String author;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = placeholderCovers[title.hashCode.abs() % placeholderCovers.length];
    return Container(
      color: bg,
      // Room at the bottom for the status and format bubbles laid over grid covers.
      padding: compact ? const EdgeInsets.all(6) : const EdgeInsets.fromLTRB(10, 10, 10, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        // Flexible: with large text, a long title is cut off at the bottom instead of overflowing.
        Flexible(
          child: Text(title,
              maxLines: compact ? 4 : 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontFamily: 'serif', fontWeight: FontWeight.w600, fontSize: compact ? 10 : 14, height: 1.25)),
        ),
        if (!compact && author.isNotEmpty)
          Text(author.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 9.5, letterSpacing: 0.5)),
      ]),
    );
  }
}

/// A library book's cover: her photo or the saved cover, else downloaded (and saved), else drawn.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.width, this.radius = 6, this.compact = false});
  final LibraryBook book;
  final double? width;
  final double radius;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final covers = AppScope.of(context).covers;
    final placeholder = PlaceholderCover(title: book.title, author: book.authorLine, compact: compact);
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: const [
            BoxShadow(color: Color(0x1F000000), blurRadius: 2, offset: Offset(0, 1)),
            BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
          ]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: ListenableBuilder(
              listenable: covers,
              builder: (context, _) => FutureBuilder<File?>(
                key: ValueKey('${book.id}-${covers.version}-${book.hasOwnCover}-${book.row.coverRef}'),
                future: covers.localFile(book).then((f) => f ?? covers.ensure(book)),
                builder: (context, snap) {
                  final f = snap.data;
                  if (f != null) {
                    return Image.file(f, fit: BoxFit.cover, semanticLabel: 'Cover of ${book.title}', errorBuilder: (_, _, _) => placeholder);
                  }
                  if (!covers.supported && book.row.coverRef != null) {
                    final uri = AppScope.of(context).lookup.coverUri(book.row.coverRef!, CoverSize.medium);
                    if (uri != null) return Image.network('$uri', fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder);
                  }
                  return placeholder;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A lookup result's cover, straight from the source (not saved until the book is added).
class CandidateCover extends StatelessWidget {
  const CandidateCover({super.key, required this.candidate, this.width = 56});
  final Candidate candidate;
  final double width;

  @override
  Widget build(BuildContext context) {
    final lookup = AppScope.of(context).lookup;
    final placeholder = PlaceholderCover(title: candidate.title, author: candidate.authorLine, compact: true);
    final uri = candidate.coverRef == null ? null : lookup.coverUri('${candidate.sourceId}:${candidate.coverRef}', CoverSize.medium);
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: uri == null
              ? placeholder
              : Image.network('$uri', fit: BoxFit.cover, semanticLabel: 'Cover of ${candidate.title}', errorBuilder: (_, _, _) => placeholder),
        ),
      ),
    );
  }
}

IconData formatIcon(OwnershipFormat f) => f == OwnershipFormat.kindle ? Icons.tablet_android_outlined : Icons.menu_book_outlined;

/// Each reading status's own icon, beside its word in the cover bubble (her request, 2026-11-21).
IconData statusIcon(ReadingStatus s) => switch (s) {
      ReadingStatus.tbr => Icons.bookmark_border,
      ReadingStatus.reading => Icons.auto_stories_outlined,
      ReadingStatus.read => Icons.check_rounded,
      ReadingStatus.dnf => Icons.block,
    };

/// A reading status on a cover: its own colour and icon, with the word, so TBR, Reading, Read and
/// DNF are told apart at a glance.
class StatusBubble extends StatelessWidget {
  const StatusBubble({super.key, required this.status});
  final ReadingStatus status;

  @override
  Widget build(BuildContext context) {
    final c = statusColours(status, Theme.of(context).brightness);
    return Semantics(
      label: status.longLabel,
      // No alignment here: with one, the pill would stretch to fill all the room it's given.
      child: Container(
        height: 24,
        padding: const EdgeInsets.only(left: 6, right: 9),
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: ExcludeSemantics(
          // On a narrow cover, or with large text, it shrinks to fit rather than spilling over.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon(status), size: 14, color: c.on),
              const SizedBox(width: 3),
              Text(status.label, style: TextStyle(color: c.on, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The series a book belongs to and its place in it ("Dune · Book 3"), under the author.
class SeriesLine extends StatelessWidget {
  const SeriesLine({super.key, required this.series, this.small = false});
  final BookSeries series;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = (small ? Theme.of(context).textTheme.bodyMedium : Theme.of(context).textTheme.bodyLarge)?.copyWith(color: muted);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Icon(Icons.collections_bookmark_outlined, size: small ? 16 : 18, color: muted),
        const SizedBox(width: 6),
        Expanded(child: Text(series.label, style: style, maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

/// A small pill laid over a cover: the Kindle/Physical icon (statuses use [StatusBubble]).
class CoverBubble extends StatelessWidget {
  const CoverBubble({super.key, this.label, this.icon, this.semanticLabel});
  final String? label;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel ?? label,
      child: Container(
        height: 24,
        constraints: const BoxConstraints(minWidth: 24),
        padding: EdgeInsets.symmetric(horizontal: label != null ? 9 : 0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: ExcludeSemantics(
          child: label != null
              ? Text(label!, style: TextStyle(color: cs.onPrimaryContainer, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.3))
              : Icon(icon, size: 14, color: cs.onPrimaryContainer),
        ),
      ),
    );
  }
}

class OwnedBadge extends StatelessWidget {
  const OwnedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 26,
      padding: const EdgeInsets.only(left: 8, right: 10),
      decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(13)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_rounded, size: 15, color: cs.onPrimary),
        const SizedBox(width: 4),
        Text('ALREADY OWNED', style: TextStyle(color: cs.onPrimary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.7)),
      ]),
    );
  }
}

/// 0 to 5 stars. Tapping the current rating again clears it.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.rating, this.onChanged, this.size = 32});
  final int? rating;
  final ValueChanged<int?>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: rating == null ? 'Not rated' : '$rating out of 5 stars',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          onChanged == null
              ? Icon((rating ?? 0) >= i ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: cs.tertiary)
              : IconButton(
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  visualDensity: VisualDensity.compact,
                  icon: Icon((rating ?? 0) >= i ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: cs.tertiary),
                  onPressed: () => onChanged!(rating == i ? null : i),
                ),
      ]),
    );
  }
}

String formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
