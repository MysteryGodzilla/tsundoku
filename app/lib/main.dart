import 'package:material_ui/material_ui.dart';

import 'src/app_scope.dart';
import 'src/books/library_repository.dart';
import 'src/covers/cover_store.dart';
import 'src/db/database.dart';
import 'src/settings/appearance.dart';
import 'src/sources/book_source.dart';
import 'src/sources/open_library_source.dart';
import 'src/theme/theme.dart';
import 'src/ui/library_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Open Library only for now (roadmap Q7); more sources plug in here.
  final lookup = BookLookup([OpenLibrarySource()]);
  final services = AppServices(
    library: LibraryRepository(AppDatabase()),
    lookup: lookup,
    covers: CoverStore(lookup),
    appearance: await AppearanceSettings.load(),
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
              home: const LibraryScreen(),
            );
          },
        ),
      );
}
