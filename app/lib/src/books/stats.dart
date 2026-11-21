/// The numbers on the stats page (her request, 2026-11-21): how many books, how many in each
/// reading status, and how many bought and finished lately. Only her own library, never shared.
library;

import 'library_repository.dart';
import 'models.dart';

/// The periods shown, each ending today: the last 30 days, 90 days and 12 months.
enum StatsPeriod {
  days30('Last 30 days', 30),
  days90('Last 90 days', 90),
  year('Last 12 months', 365);

  const StatsPeriod(this.label, this.days);
  final String label;
  final int days;
}

class PeriodCounts {
  const PeriodCounts(this.counts, {required this.undated});

  /// Books whose date falls in each period (a book counts in every period it falls in).
  final Map<StatsPeriod, int> counts;

  /// Books that could count but have no date set, so they're in no period.
  final int undated;

  int operator [](StatsPeriod p) => counts[p] ?? 0;
}

class LibraryStats {
  const LibraryStats({required this.total, required this.byStatus, required this.noStatus, required this.bought, required this.finished});
  final int total;
  final Map<ReadingStatus, int> byStatus;

  /// Books with no reading status set.
  final int noStatus;

  /// By the date bought.
  final PeriodCounts bought;

  /// Books marked Read, by the date finished (a DNF's "stopped" date doesn't count).
  final PeriodCounts finished;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// [format] null means every book; otherwise only Physical or only Kindle.
LibraryStats libraryStats(List<LibraryBook> all, {OwnershipFormat? format, required DateTime now}) {
  final books = format == null ? all : all.where((b) => b.format == format).toList();
  final today = _day(now);

  // A date is in a period of N days when it falls on today or one of the N - 1 days before.
  bool inPeriod(DateTime d, StatsPeriod p) {
    final day = _day(d);
    final first = DateTime(today.year, today.month, today.day - (p.days - 1));
    return !day.isBefore(first) && !day.isAfter(today);
  }

  PeriodCounts count(Iterable<LibraryBook> candidates, DateTime? Function(LibraryBook) date) {
    final counts = {for (final p in StatsPeriod.values) p: 0};
    var undated = 0;
    for (final b in candidates) {
      final d = date(b);
      if (d == null) {
        undated++;
        continue;
      }
      for (final p in StatsPeriod.values) {
        if (inPeriod(d, p)) counts[p] = counts[p]! + 1;
      }
    }
    return PeriodCounts(counts, undated: undated);
  }

  return LibraryStats(
    total: books.length,
    byStatus: {for (final s in ReadingStatus.values) s: books.where((b) => b.status == s).length},
    noStatus: books.where((b) => b.status == null).length,
    bought: count(books, (b) => b.row.purchasedOn),
    finished: count(books.where((b) => b.status == ReadingStatus.read), (b) => b.row.finishedOn),
  );
}
