/// Where backup files live: a folder she picked (Google Drive, Downloads...) through Android's
/// folder picker, or the app's own storage on this phone.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

// The folder store uses Android-only native code; the browser build gets a stand-in.
export 'folder_store_stub.dart' if (dart.library.io) 'folder_store_android.dart';

class BackupEntry {
  BackupEntry({required this.id, required this.name, required this.createdAt, required this.size});

  /// A file path or a content URI, depending on the store.
  final String id;
  final String name;
  final DateTime createdAt;
  final int size;
}

const _prefix = 'tsundoku-backup-';

String two(int n) => n.toString().padLeft(2, '0');

/// `tsundoku-backup-2026-11-14-1830.zip`
String backupFileName(DateTime t) =>
    '$_prefix${t.year}-${two(t.month)}-${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}.zip';

/// The time in a backup's file name (not the file's modified time, which cloud folders can change).
DateTime? backupTimeFromName(String name) {
  final m = RegExp(r'^tsundoku-backup-(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})(\d{2})?\.zip$').firstMatch(name);
  if (m == null) return null;
  int g(int i) => int.parse(m.group(i) ?? '0');
  return DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
}

abstract interface class BackupStore {
  /// Where it is, in words ("Google Drive › Books", "this phone").
  String get description;

  /// Backups found here, newest first.
  Future<List<BackupEntry>> list();
  Future<void> write(String name, Uint8List bytes);
  Future<Uint8List> read(BackupEntry e);
  Future<void> delete(BackupEntry e);
}

List<BackupEntry> sortedNewestFirst(Iterable<BackupEntry> e) => e.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

/// The app's own storage. Survives mistakes, not losing the phone or uninstalling the app.
class LocalBackupStore implements BackupStore {
  LocalBackupStore(this.dir);
  final Future<Directory> Function() dir;

  @override
  String get description => 'this phone';

  Future<Directory> _d() async {
    final d = await dir();
    await d.create(recursive: true);
    return d;
  }

  @override
  Future<List<BackupEntry>> list() async {
    final out = <BackupEntry>[];
    await for (final e in (await _d()).list()) {
      if (e is! File) continue;
      final name = p.basename(e.path);
      final t = backupTimeFromName(name);
      if (t != null) out.add(BackupEntry(id: e.path, name: name, createdAt: t, size: await e.length()));
    }
    return sortedNewestFirst(out);
  }

  @override
  Future<void> write(String name, Uint8List bytes) async => File(p.join((await _d()).path, name)).writeAsBytes(bytes, flush: true);

  @override
  Future<Uint8List> read(BackupEntry e) => File(e.id).readAsBytes();

  @override
  Future<void> delete(BackupEntry e) async {
    final f = File(e.id);
    if (await f.exists()) await f.delete();
  }
}
