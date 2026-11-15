/// Daily copies of the server's database (docs/sync-server.md). A copy holds exactly what the
/// server does: accounts and locked boxes, nothing readable.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'store.dart';

class BackupFile {
  BackupFile(this.path, this.at);
  final String path;
  final DateTime at;
}

class Backups {
  Backups(this.store, this.dir, {this.keepDays = 14, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Store store;
  final String dir;

  /// Copies older than this are deleted (the newest is always kept).
  final int keepDays;
  final DateTime Function() _clock;

  static final _name = RegExp(r'^tsundoku-(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})\.db$');

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// The copies made so far, newest first.
  List<BackupFile> list() {
    final d = Directory(dir);
    if (!d.existsSync()) return [];
    final out = <BackupFile>[];
    for (final f in d.listSync().whereType<File>()) {
      final m = _name.firstMatch(p.basename(f.path));
      if (m == null) continue;
      final g = [for (var i = 1; i <= 5; i++) int.parse(m.group(i)!)];
      out.add(BackupFile(f.path, DateTime(g[0], g[1], g[2], g[3], g[4])));
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  BackupFile? latest() => list().firstOrNull;

  /// A copy now, whatever the time. Returns its path.
  String backupNow() {
    Directory(dir).createSync(recursive: true);
    final now = _clock();
    final name = 'tsundoku-${now.year}-${_two(now.month)}-${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}.db';
    final path = p.join(dir, name);
    final part = '$path.part';
    for (final f in [File(part), File(path)]) {
      if (f.existsSync()) f.deleteSync();
    }
    store.backupTo(part);
    File(part).renameSync(path);
    prune();
    return path;
  }

  /// Makes the day's copy if the last one is about a day old (or there's none). Returns its path.
  String? runIfDue() {
    final last = latest();
    if (last != null && _clock().difference(last.at) < const Duration(hours: 23)) return null;
    return backupNow();
  }

  /// Deletes copies older than [keepDays], always keeping the newest.
  void prune() {
    final all = list();
    final cutoff = _clock().subtract(Duration(days: keepDays));
    for (final b in all.skip(1)) {
      if (b.at.isBefore(cutoff)) File(b.path).deleteSync();
    }
  }
}
