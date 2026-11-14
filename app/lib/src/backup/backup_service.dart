/// Automatic backups (Phase 2): daily by default, kept 7 days by default, both changeable; restore.
///
/// Backups run when the app opens or comes back to the front and one is due. If nothing has
/// changed since the last backup, there's nothing new to save, so none is made. Old backups expire
/// after the retention period, but the newest is always kept.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_info.dart';
import '../books/library_repository.dart';
import '../covers/cover_store.dart';
import 'backup_format.dart';
import 'backup_store.dart';

class BackupService extends ChangeNotifier {
  BackupService({
    required this.library,
    required this.covers,
    required this.prefs,
    Future<Directory> Function()? localDir,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        local = LocalBackupStore(localDir ?? () async => Directory(p.join((await getApplicationSupportDirectory()).path, 'backups')));

  final LibraryRepository library;
  final CoverStore covers;
  final SharedPreferences prefs;
  final DateTime Function() _clock;

  /// Backups on this phone: the place used until she picks a folder, and where the safety copy
  /// made before a restore goes.
  final LocalBackupStore local;

  static const frequencyChoices = [1, 7];
  static const retentionChoices = [7, 14, 30, 90];

  static const _kUri = 'backup.folderUri';
  static const _kName = 'backup.folderName';
  static const _kFreq = 'backup.frequencyDays';
  static const _kKeep = 'backup.retentionDays';
  static const _kLast = 'backup.lastAt';

  bool _busy = false;
  String? lastError;

  String? get folderUri => prefs.getString(_kUri);
  String? get folderName => prefs.getString(_kName);
  int get frequencyDays => prefs.getInt(_kFreq) ?? 1;
  int get retentionDays => prefs.getInt(_kKeep) ?? 7;
  DateTime? get lastBackupAt => prefs.getString(_kLast) == null ? null : DateTime.parse(prefs.getString(_kLast)!);

  BackupStore get store =>
      folderUri == null ? local : FolderBackupStore(treeUri: folderUri!, folderName: folderName ?? 'the folder you chose');

  Future<void> setFrequencyDays(int d) async {
    await prefs.setInt(_kFreq, d);
    notifyListeners();
  }

  Future<void> setRetentionDays(int d) async {
    await prefs.setInt(_kKeep, d);
    notifyListeners();
    await _prune(store);
  }

  /// Android's folder picker. Returns false if she backed out.
  Future<bool> chooseFolder() async {
    final dir = await pickBackupFolder();
    if (dir == null) return false;
    await prefs.setString(_kUri, dir.uri);
    await prefs.setString(_kName, dir.name);
    notifyListeners();
    return true;
  }

  Future<void> useThisPhone() async {
    await prefs.remove(_kUri);
    await prefs.remove(_kName);
    notifyListeners();
  }

  /// Run a backup if one is due and something has changed since the last.
  Future<void> runIfDue() async {
    final last = lastBackupAt;
    final now = _clock();
    if (last != null && now.difference(last) < Duration(days: frequencyDays)) return;
    final changed = await library.lastChangeAt();
    if (last != null && (changed == null || !changed.isAfter(last))) return;
    if (changed == null && (await library.count()) == 0) return; // An empty, untouched library.
    await backupNow();
  }

  /// The whole library as a backup file, for "Save a copy to…".
  Future<Uint8List> backupBytes() => _encodeLibrary();

  String newBackupName() => backupFileName(_clock());

  Future<Uint8List> _encodeLibrary() async {
    final books = await library.allBooks();
    final photos = <String, Uint8List>{};
    for (final b in books.where((b) => b.hasOwnCover)) {
      final bytes = await covers.ownPhotoBytes(b.id);
      if (bytes != null) photos[b.id] = bytes;
    }
    return encodeBackup(books, photos, createdAt: _clock(), appVersion: appVersion);
  }

  /// Back up now. Returns true on success; on failure [lastError] says why.
  Future<bool> backupNow() async {
    if (_busy) return false;
    _busy = true;
    try {
      final s = store;
      if (s is FolderBackupStore && !await s.stillAllowed()) {
        throw const _BackupProblem('Tsundoku can no longer save to the backup folder. Choose it again in Settings.');
      }
      final now = _clock();
      await s.write(backupFileName(now), await _encodeLibrary());
      await prefs.setString(_kLast, now.toIso8601String());
      lastError = null;
      await _prune(s);
      return true;
    } on _BackupProblem catch (e) {
      lastError = e.message;
      return false;
    } catch (_) {
      lastError = 'The last backup didn\'t work. It will try again next time you open Tsundoku.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Delete backups older than the retention period, always keeping the newest.
  Future<void> _prune(BackupStore s) async {
    try {
      final entries = await s.list();
      final cutoff = _clock().subtract(Duration(days: retentionDays));
      for (final e in entries.skip(1)) {
        if (e.createdAt.isBefore(cutoff)) await s.delete(e);
      }
    } catch (_) {
      // Tidying up can wait until next time.
    }
  }

  Future<BackupContents> peek(BackupEntry e, {BackupStore? from}) async => decodeBackup(await (from ?? store).read(e));

  /// Replace the library with a backup. A safety copy of what's here now is saved on this phone
  /// first, so a restore can be undone.
  Future<void> restore(BackupContents b) async {
    if ((await library.count()) > 0) {
      await local.write(backupFileName(_clock()), await _encodeLibrary());
    }
    await library.replaceAll(b.books);
    await covers.deleteAll();
    for (final e in b.ownPhotos.entries) {
      await covers.saveOwnPhoto(e.key, e.value);
    }
    await _prune(local);
    notifyListeners();
  }
}

class _BackupProblem implements Exception {
  const _BackupProblem(this.message);
  final String message;
}
