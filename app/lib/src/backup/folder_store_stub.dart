/// The browser has no folder picker: backups to a folder are Android-only for now.
library;

import 'dart:typed_data';

import 'backup_store.dart';

Future<({String uri, String name})?> pickBackupFolder() async => null;

class FolderBackupStore implements BackupStore {
  FolderBackupStore({required this.treeUri, required this.folderName});
  final String treeUri;
  final String folderName;

  @override
  String get description => folderName;

  Future<bool> stillAllowed() async => false;

  @override
  Future<List<BackupEntry>> list() async => const [];
  @override
  Future<void> write(String name, Uint8List bytes) => throw UnsupportedError('Backups to a folder work on Android.');
  @override
  Future<Uint8List> read(BackupEntry e) => throw UnsupportedError('Backups to a folder work on Android.');
  @override
  Future<void> delete(BackupEntry e) async {}
}
