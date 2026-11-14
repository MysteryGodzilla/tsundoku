import 'package:material_ui/material_ui.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'src/app_info.dart';
import 'src/app_scope.dart';
import 'src/backup/backup_service.dart';
import 'src/books/library_repository.dart';
import 'src/covers/cover_store.dart';
import 'src/db/database.dart';
import 'src/settings/appearance.dart';
import 'src/settings/view_settings.dart';
import 'src/sources/book_source.dart';
import 'src/sources/open_library_source.dart';
import 'src/theme/theme.dart';
import 'src/ui/keyboard_guard.dart';
import 'src/ui/library_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Open Library only for now (roadmap Q7); more sources plug in here.
  final lookup = BookLookup([OpenLibrarySource(appVersion: appVersion)]);
  final library = LibraryRepository(AppDatabase());
  final covers = CoverStore(lookup);
  final services = AppServices(
    library: library,
    lookup: lookup,
    covers: covers,
    appearance: await AppearanceSettings.load(),
    view: await ViewSettings.load(),
    backups: BackupService(library: library, covers: covers, prefs: await SharedPreferences.getInstance()),
  );
  runApp(TsundokuApp(services: services));
}

class TsundokuApp extends StatelessWidget {
  const TsundokuApp({super.key, required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) => AppScope(
        services: services,
        child: ListenableBuilder(
          listenable: services.appearance,
          builder: (context, _) {
            final a = services.appearance;
            return MaterialApp(
              title: 'Tsundoku',
              debugShowCheckedModeBanner: false,
              theme: buildTheme(a.accent, Brightness.light),
              darkTheme: buildTheme(a.accent, Brightness.dark),
              themeMode: switch (a.mode) {
                AppearanceMode.system => ThemeMode.system,
                AppearanceMode.light => ThemeMode.light,
                AppearanceMode.dark => ThemeMode.dark,
              },
              builder: (context, child) => _BackupHook(services: services, child: KeyboardInsetsGuard(child: child!)),
              home: const LibraryScreen(),
            );
          },
        ),
      );
}

/// Checks for a due backup when the app opens and whenever it comes back to the front.
class _BackupHook extends StatefulWidget {
  const _BackupHook({required this.services, required this.child});
  final AppServices services;
  final Widget child;

  @override
  State<_BackupHook> createState() => _BackupHookState();
}

class _BackupHookState extends State<_BackupHook> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: widget.services.backups.runIfDue);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.services.backups.runIfDue());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
