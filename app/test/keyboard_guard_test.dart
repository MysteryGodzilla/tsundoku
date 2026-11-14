import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsundoku/src/ui/keyboard_guard.dart';

void main() {
  testWidgets('a stale keyboard height is ignored unless a text field is focused', (tester) async {
    // A keyboard height the engine kept after the keyboard went away (the bug she hit).
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);

    double? seenInset;
    final field = FocusNode();
    addTearDown(field.dispose);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => KeyboardInsetsGuard(child: child!),
      // Read above the Scaffold: a Scaffold removes the keyboard space from what its body sees.
      home: Builder(builder: (context) {
        seenInset = MediaQuery.viewInsetsOf(context).bottom;
        return Scaffold(body: TextField(focusNode: field));
      }),
    ));
    expect(seenInset, 0, reason: 'nothing focused: no keyboard, so no blank area');

    field.requestFocus();
    await tester.pump();
    expect(seenInset, greaterThan(0), reason: 'typing: the keyboard space is real');

    // Back from another app: focus is cleared, so the stale height can't linger.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(field.hasFocus, isFalse);
    expect(seenInset, 0);
  });
}
