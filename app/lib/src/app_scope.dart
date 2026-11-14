/// Hands the app's services to every screen.
library;

import 'package:material_ui/material_ui.dart';

import 'books/library_repository.dart';
import 'covers/cover_store.dart';
import 'settings/appearance.dart';
import 'sources/book_source.dart';

class AppServices {
  AppServices({required this.library, required this.lookup, required this.covers, required this.appearance});
  final LibraryRepository library;
  final BookLookup lookup;
  final CoverStore covers;
  final AppearanceSettings appearance;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});
  final AppServices services;

  static AppServices of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope old) => old.services != services;
}
