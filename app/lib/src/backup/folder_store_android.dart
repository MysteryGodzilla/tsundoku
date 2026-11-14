/// The folder store on Android (and other platforms with files).
library;

import 'dart:typed_data';

import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import 'backup_store.dart';

/// Android's folder picker; the app keeps permission to write there. Null if she backs out.
Future<({String uri, String name})?> pickBackupFolder() async {
  final dir = await SafUtil().pickDirectory(writePermission: true, persistablePermission: true);
  return dir == null ? null : (uri: dir.uri, name: dir.name);
}

/// A folder she picked with Android's folder picker; the app keeps permission to write there.
class FolderBackupStore implements BackupStore {
  FolderBackupStore({required this.treeUri, required this.folderName});
  final String treeUri;
  final String folderName;
  final _util = SafUtil();
  final _stream = SafStream();

  @override
  String get description => folderName;

  /// False if Android no longer lets the app write there (the folder was removed, say).
  Future<bool> stillAllowed() => _util.hasPersistedPermission(treeUri, checkRead: true, checkWrite: true);

  @override
  Future<List<BackupEntry>> list() async {
    final files = await _util.list(treeUri);
    return sortedNewestFirst([
      for (final f in files)
        if (!f.isDir && backupTimeFromName(f.name) != null)
          BackupEntry(id: f.uri, name: f.name, createdAt: backupTimeFromName(f.name)!, size: f.length),
    ]);
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    await _stream.writeFileBytes(treeUri, name, 'application/zip', bytes, overwrite: true);
  }

  @override
  Future<Uint8List> read(BackupEntry e) => _stream.readFileBytes(e.id);

  @override
  Future<void> delete(BackupEntry e) => _util.delete(e.id, false);
}
