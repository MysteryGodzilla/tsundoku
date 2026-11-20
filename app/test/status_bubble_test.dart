import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsundoku/src/books/models.dart';
import 'package:tsundoku/src/theme/palette.dart';
import 'package:tsundoku/src/theme/theme.dart';
import 'package:tsundoku/src/ui/widgets.dart';

/// WCAG relative luminance and contrast ratio.
double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final (x, y) = (_lum(a), _lum(b));
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

void main() {
  test('each status has its own colour and icon, and its word and icon are readable on it', () {
    for (final b in Brightness.values) {
      final fills = <Color>{};
      for (final s in ReadingStatus.values) {
        final c = statusColours(s, b);
        expect(_contrast(c.fill, c.on), greaterThanOrEqualTo(4.5), reason: '$s in $b: ${_contrast(c.fill, c.on).toStringAsFixed(2)}:1');
        fills.add(c.fill);
      }
      expect(fills.length, ReadingStatus.values.length, reason: 'four different colours in $b');
    }
    expect(ReadingStatus.values.map(statusIcon).toSet().length, ReadingStatus.values.length, reason: 'four different icons');
    expect(statusIcon(ReadingStatus.read), Icons.check_rounded, reason: 'Read has a tick');
  });

  testWidgets('the bubble shows the icon and the word, and reads the full status aloud', (tester) async {
    final handle = tester.ensureSemantics();
    for (final mode in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Accent.sage, mode),
        home: const Scaffold(body: Row(children: [StatusBubble(status: ReadingStatus.read), StatusBubble(status: ReadingStatus.dnf)])),
      ));
      await tester.pump(const Duration(milliseconds: 400)); // The theme fades between modes.
      expect(find.text('Read'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
      final fill = (tester.widget<Container>(find.descendant(of: find.byType(StatusBubble).first, matching: find.byType(Container))).decoration!
              as BoxDecoration)
          .color;
      expect(fill, statusColours(ReadingStatus.read, mode).fill);
      expect(find.bySemanticsLabel('Did not finish'), findsOneWidget);
    }
    handle.dispose();
  });
}
