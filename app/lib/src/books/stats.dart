/// The numbers on the stats page (her request, 2026-11-21): how many books, how many in each
/// reading status, how many bought and finished lately, and the fun ones (pace, best month, oldest
/// unread, ratings, authors, genres). Only her own library, never shared.
///
/// Anything built on a field someone doesn't fill in comes back null or empty, so the page can hide
/// it: no dates bought, no Bought card; no ratings, no ratings card (her feedback on 0.7.0).
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
  const PeriodCounts(this.counts, {required this.dated, required this.undated});

  /// Books whose date falls in each period (a book counts in every period it falls in).
  final Map<StatsPeriod, int> counts;

  /// Books that have the date set. When none do, the page leaves the card out.
  final int dated;

  /// Books that could count but have no date set, so they're in no period.
  final int undated;

  int operator [](StatsPeriod p) => counts[p] ?? 0;
}

/// The author (or authors, when tied) with the most books.
class TopAuthor {
  const TopAuthor(this.names, this.count);
  final List<String> names;
  final int count;
}

class RatingStats {
  const RatingStats({required this.rated, required this.average, required this.byStars});
  final int rated;
  final double average;

  /// 1 to 5 stars, how many books have each.
  final Map<int, int> byStars;
}

/// The average gap between finished books, from the first finished date to the last.
class Pace {
  const Pace({required this.books, required this.averageDays, required this.first, required this.last});
  final int books;
  final double averageDays;
  final DateTime first;
  final DateTime last;
}

class BestMonth {
  const BestMonth(this.month, this.count);

  /// The first day of that month.
  final DateTime month;
  final int count;
}

class LibraryStats {
  const LibraryStats({
    required this.total,
    required this.byStatus,
    required this.noStatus,
    required this.bought,
    required this.finished,
    this.pace,
    this.bestMonth,
    this.oldestUnread,
    this.ratings,
    this.mostRead,
    this.mostOwned,
    this.topGenres = const [],
  });
  final int total;
  final Map<ReadingStatus, int> byStatus;

  /// Books with no reading status set.
  final int noStatus;

  /// By the date bought.
  final PeriodCounts bought;

  /// Books marked Read, by the date finished (a DNF's "stopped" date doesn't count).
  final PeriodCounts finished;

  /// Needs at least two books marked Read with a date finished.
  final Pace? pace;

  /// The month with the most books finished; only when that's two or more.
  final BestMonth? bestMonth;

  /// The TBR book bought longest ago. Read and DNF books are done with, a Reading book is under way,
  /// and a book with no status might have been read long ago, so only TBR counts as unread.
  final LibraryBook? oldestUnread;

  final RatingStats? ratings;

  /// Most books marked Read; only when that's two or more (one each says nothing).
  final TopAuthor? mostRead;

  /// Most books owned; only when that's two or more.
  final TopAuthor? mostOwned;

  /// Up to three, the commonest first.
  final List<(String, int)> topGenres;

  bool get anyStatus => noStatus < total;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole days from [a] to [b], counted on the calendar (so a clock change can't shorten a day).
int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Counts names, grouping them whatever their capitals and spaces, and shows each the way it's
/// written most often (on a tie, the one with more capitals: "Alice Example" over "alice example").
/// Sorted by count, most first, then by name.
List<(String, int)> _ranked(Iterable<String> names) {
  final spellings = <String, Map<String, int>>{};
  for (final raw in names) {
    final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) continue;
    final forms = spellings.putIfAbsent(name.toLowerCase(), () => {});
    forms[name] = (forms[name] ?? 0) + 1;
  }
  int capitals(String s) => s.runes.where((r) => String.fromCharCode(r) != String.fromCharCode(r).toLowerCase()).length;
  final list = [
    for (final forms in spellings.values)
      (
        (forms.entries.toList()..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : capitals(b.key).compareTo(capitals(a.key)))).first.key,
        forms.values.reduce((a, b) => a + b),
      ),
  ];
  list.sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.toLowerCase().compareTo(b.$1.toLowerCase()));
  return list;
}

TopAuthor? _top(Iterable<LibraryBook> books) {
  // A book with two authors counts for each; the same name twice on one book counts once.
  final ranked = _ranked(books.expand((b) => {for (final a in b.authors) a.trim().toLowerCase(): a}.values));
  if (ranked.isEmpty || ranked.first.$2 < 2) return null;
  final best = ranked.first.$2;
  return TopAuthor([for (final r in ranked) if (r.$2 == best) r.$1], best);
}

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
    var dated = 0, undated = 0;
    for (final b in candidates) {
      final d = date(b);
      if (d == null) {
        undated++;
        continue;
      }
      dated++;
      for (final p in StatsPeriod.values) {
        if (inPeriod(d, p)) counts[p] = counts[p]! + 1;
      }
    }
    return PeriodCounts(counts, dated: dated, undated: undated);
  }

  final read = books.where((b) => b.status == ReadingStatus.read).toList();

  // Finished dates up to today (a date in the future can only be a mistake).
  final finishedDays = [
    for (final b in read)
      if (b.row.finishedOn case final d? when !_day(d).isAfter(today)) _day(d),
  ]..sort();

  Pace? pace;
  if (finishedDays.length >= 2) {
    final span = _daysBetween(finishedDays.first, finishedDays.last);
    pace = Pace(books: finishedDays.length, averageDays: span / (finishedDays.length - 1), first: finishedDays.first, last: finishedDays.last);
  }

  BestMonth? bestMonth;
  final perMonth = <DateTime, int>{};
  for (final d in finishedDays) {
    final m = DateTime(d.year, d.month);
    perMonth[m] = (perMonth[m] ?? 0) + 1;
  }
  for (final e in perMonth.entries) {
    // On a tie, the more recent month.
    if (e.value >= 2 && (bestMonth == null || e.value > bestMonth.count || (e.value == bestMonth.count && e.key.isAfter(bestMonth.month)))) {
      bestMonth = BestMonth(e.key, e.value);
    }
  }

  LibraryBook? oldestUnread;
  for (final b in books) {
    final d = b.row.purchasedOn;
    if (b.status != ReadingStatus.tbr || d == null) continue;
    final o = oldestUnread?.row.purchasedOn;
    if (o == null || _day(d).isBefore(_day(o)) || (_day(d) == _day(o) && b.title.toLowerCase().compareTo(oldestUnread!.title.toLowerCase()) < 0)) {
      oldestUnread = b;
    }
  }

  RatingStats? ratings;
  final stars = [for (final b in books) if (b.row.rating case final r? when r >= 1 && r <= 5) r];
  if (stars.isNotEmpty) {
    ratings = RatingStats(
      rated: stars.length,
      average: stars.reduce((a, b) => a + b) / stars.length,
      byStars: {for (var i = 5; i >= 1; i--) i: stars.where((r) => r == i).length},
    );
  }

  return LibraryStats(
    total: books.length,
    byStatus: {for (final s in ReadingStatus.values) s: books.where((b) => b.status == s).length},
    noStatus: books.where((b) => b.status == null).length,
    bought: count(books, (b) => b.row.purchasedOn),
    finished: count(read, (b) => b.row.finishedOn),
    pace: pace,
    bestMonth: bestMonth,
    oldestUnread: oldestUnread,
    ratings: ratings,
    mostRead: _top(read),
    mostOwned: _top(books),
    topGenres: _ranked(books.expand((b) => b.genres.toSet())).take(3).toList(),
  );
}

/// "today", "5 days ago", "3 months ago", "2 years ago": how long ago [d] was.
String howLongAgo(DateTime d, DateTime now) {
  final days = _daysBetween(d, now);
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 31) return '$days days ago';
  var months = (now.year - d.year) * 12 + now.month - d.month;
  if (now.day < d.day) months--;
  if (months < 1) months = 1;
  if (months < 12) return months == 1 ? 'a month ago' : '$months months ago';
  final years = months ~/ 12;
  return years == 1 ? 'a year ago' : '$years years ago';
}
