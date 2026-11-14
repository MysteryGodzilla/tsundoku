/// Material theme built from the palette: calm, neutral, one soft accent, covers as the focus.
library;

import 'package:material_ui/material_ui.dart';

import 'palette.dart';

ThemeData buildTheme(Accent accent, Brightness brightness) {
  final n = brightness == Brightness.dark ? darkNeutrals : lightNeutrals;
  final a = accentColours(accent, brightness);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: a.accent,
    onPrimary: a.onAccent,
    primaryContainer: a.tint,
    onPrimaryContainer: a.onTint,
    secondary: a.accent,
    onSecondary: a.onAccent,
    secondaryContainer: a.tint,
    onSecondaryContainer: a.onTint,
    error: brightness == Brightness.dark ? const Color(0xFFF2B8B5) : const Color(0xFFB3261E),
    onError: brightness == Brightness.dark ? const Color(0xFF601410) : const Color(0xFFFFFFFF),
    surface: n.background,
    onSurface: n.text,
    onSurfaceVariant: n.muted,
    surfaceContainerLowest: n.surface,
    surfaceContainerLow: n.surface,
    surfaceContainer: n.surface,
    surfaceContainerHigh: n.field,
    surfaceContainerHighest: n.border,
    outline: n.muted,
    outlineVariant: n.border,
  );
  final shape16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: n.background,
    appBarTheme: AppBarTheme(
      backgroundColor: n.background,
      foregroundColor: n.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: n.text, letterSpacing: -0.2),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(n.field),
      shape: WidgetStatePropertyAll(StadiumBorder(side: BorderSide(color: n.border))),
      padding: const WidgetStatePropertyAll(EdgeInsets.only(left: 16, right: 4)),
      constraints: const BoxConstraints(minHeight: 52),
      hintStyle: WidgetStatePropertyAll(TextStyle(color: n.muted, fontSize: 16)),
      textStyle: WidgetStatePropertyAll(TextStyle(color: n.text, fontSize: 16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 48), shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: const StadiumBorder(),
        side: BorderSide(color: a.accent, width: 1.5),
        foregroundColor: a.accent,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: a.accent,
      foregroundColor: a.onAccent,
      extendedTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      shape: const StadiumBorder(),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: n.border),
      backgroundColor: Colors.transparent,
      selectedColor: a.tint,
      labelStyle: TextStyle(color: n.text, fontSize: 14),
      secondaryLabelStyle: TextStyle(color: a.onTint, fontSize: 14, fontWeight: FontWeight.w600),
      checkmarkColor: a.onTint,
    ),
    cardTheme: CardThemeData(color: n.surface, elevation: 0, margin: EdgeInsets.zero, shape: shape16.copyWith(side: BorderSide(color: n.border))),
    dividerTheme: DividerThemeData(color: n.border, space: 1, thickness: 1),
    listTileTheme: ListTileThemeData(iconColor: n.muted, subtitleTextStyle: TextStyle(color: n.muted, fontSize: 14)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: n.field,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: n.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: n.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: a.accent, width: 2)),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: n.surface, showDragHandle: true, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: n.surface, surfaceTintColor: Colors.transparent),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? a.accent : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? a.onAccent : n.text),
        side: WidgetStatePropertyAll(BorderSide(color: n.border)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      ),
    ),
  );
}
