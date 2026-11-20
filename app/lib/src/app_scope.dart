/// Hands the app's services to every screen.
library;

import 'package:material_ui/material_ui.dart';

import 'account/account_service.dart';
import 'account/passkey_recovery.dart';
import 'backup/backup_service.dart';
import 'books/library_repository.dart';
import 'books/series_filler.dart';
import 'covers/cover_store.dart';
import 'settings/appearance.dart';
import 'settings/view_settings.dart';
import 'sources/book_source.dart';
import 'sync/sync_service.dart';

class AppServices {
  AppServices({
    required this.library,
    required this.lookup,
    required this.covers,
    required this.appearance,
    required this.view,
    required this.backups,
    required this.account,
    required this.sync,
    PasskeyRecovery? passkeys,
    SeriesFiller? seriesFiller,
  })  : passkeys = passkeys ?? DevicePasskeys(),
        seriesFiller = seriesFiller ?? SeriesFiller(library: library, lookup: lookup);
  final LibraryRepository library;
  final BookLookup lookup;
  final CoverStore covers;
  final AppearanceSettings appearance;
  final ViewSettings view;
  final BackupService backups;
  final AccountService account;
  final SyncService sync;

  /// Passkey recovery (step 3c); tests use a stand-in.
  final PasskeyRecovery passkeys;

  /// Fills in series for books that don't have one yet (runs quietly on opening the app).
  final SeriesFiller seriesFiller;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});
  final AppServices services;

  static AppServices of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope old) => old.services != services;
}
