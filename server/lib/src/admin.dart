/// Command-line admin for whoever runs the server (docs/sync-server.md). It shows accounts and
/// storage, never library data: the server has none it can read.
library;

import 'package:tsundoku_protocol/tsundoku_protocol.dart';

import 'api.dart' show serverVersion;
import 'backups.dart';
import 'store.dart';

class Admin {
  Admin(this.store, {this.backups, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Store store;
  final Backups? backups;
  final DateTime Function() _clock;

  static String size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  static String day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Account counts, storage and backups.
  List<String> stats() {
    final now = _clock();
    final accounts = store.allAccounts();
    var events = 0, eventBytes = 0, photos = 0, photoBytes = 0;
    for (final a in accounts) {
      final u = store.usage(a.id);
      events += u.events;
      eventBytes += u.eventBytes;
      photos += u.photos;
      photoBytes += u.photoBytes;
    }
    final last = backups?.latest();
    return [
      'Tsundoku server $serverVersion',
      'Accounts: ${accounts.length} '
          '(${accounts.where((a) => a.totpConfirmed).length} set up, '
          '${accounts.where((a) => now.difference(a.lastSeenAt) < const Duration(days: 30)).length} used in the last 30 days, '
          '${accounts.where((a) => a.suspended).length} suspended)',
      'Synced changes: $events (${size(eventBytes)}), photos: $photos (${size(photoBytes)})',
      'Database: ${size(store.sizeBytes)}',
      if (backups == null)
        'Backups: off'
      else
        'Backups: ${backups!.dir} (kept ${backups!.keepDays} days); '
            '${last == null ? 'none yet' : 'last ${day(last.at)}, ${backups!.list().length} kept'}',
    ];
  }

  /// One line per account: email, created, last seen, storage, status. No library data.
  List<String> list() {
    final accounts = store.allAccounts();
    if (accounts.isEmpty) return ['No accounts yet.'];
    final rows = [
      ['Email', 'Created', 'Last seen', 'Changes', 'Photos', 'Status'],
      for (final a in accounts)
        () {
          final u = store.usage(a.id);
          return [
            a.email,
            day(a.createdAt),
            day(a.lastSeenAt),
            '${u.events}',
            size(u.photoBytes),
            a.suspended ? 'suspended' : (a.totpConfirmed ? 'ok' : 'setup not finished'),
          ];
        }(),
    ];
    final widths = [for (var c = 0; c < rows.first.length; c++) rows.map((r) => r[c].length).reduce((a, b) => a > b ? a : b)];
    return [for (final r in rows) [for (var c = 0; c < r.length; c++) r[c].padRight(widths[c])].join('  ').trimRight()];
  }

  Account _find(String email) {
    final a = store.accountByEmail(normaliseEmail(email));
    if (a == null) throw AdminProblem('No account with the email $email.');
    return a;
  }

  /// A suspended account can't sign in or sync; its devices are signed out. Nothing is deleted.
  String suspend(String email, {bool suspended = true}) {
    final a = _find(email);
    store.setSuspended(a.id, suspended);
    return suspended
        ? 'Suspended ${a.email}. Its devices are signed out and can\'t sign in again until it\'s unsuspended.'
        : 'Unsuspended ${a.email}. It can sign in again.';
  }

  /// Deletes the account and everything it synced. Copies in older backups stay (still locked)
  /// until they age out.
  String delete(String email) {
    final a = _find(email);
    store.deleteAccount(a.id);
    final keep = backups?.keepDays;
    return 'Deleted ${a.email} and everything it synced.'
        '${keep == null ? '' : ' Older backups still hold its locked copy for up to $keep days.'}';
  }
}

class AdminProblem implements Exception {
  AdminProblem(this.message);
  final String message;
  @override
  String toString() => message;
}
