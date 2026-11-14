/// Works around a Flutter-on-Android bug that left a blank area where the keyboard had been.
///
/// Flutter's engine (`ImeSyncDeferringInsetsCallback`) ignores keyboard-size updates while a keyboard
/// animation is running and only listens again when the animation ends. If the app is sent to the
/// background while the keyboard is open, the hide animation never reports its end, so the app keeps
/// the old keyboard height: screens stay squashed above a blank area until a keyboard opens again.
///
/// The guard: when nothing is being typed (no text field has focus) there can't be a keyboard, so
/// any keyboard space reported then is ignored. And when the app comes back to the front, text
/// fields lose focus, so a stale keyboard height can't linger.
library;

import 'package:material_ui/material_ui.dart';

class KeyboardInsetsGuard extends StatefulWidget {
  const KeyboardInsetsGuard({super.key, required this.child});
  final Widget child;

  @override
  State<KeyboardInsetsGuard> createState() => _KeyboardInsetsGuardState();
}

class _KeyboardInsetsGuardState extends State<KeyboardInsetsGuard> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusChanged);
    _lifecycle = AppLifecycleListener(onResume: () => FocusManager.instance.primaryFocus?.unfocus());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusChanged);
    _lifecycle.dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  /// True when a text field (anything built on [EditableText]) has the focus.
  static bool get isTyping {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null || !context.mounted) return false;
    return context.widget is EditableText || context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (isTyping || media.viewInsets.bottom == 0) return widget.child;
    return MediaQuery(data: media.copyWith(viewInsets: media.viewInsets.copyWith(bottom: 0)), child: widget.child);
  }
}
