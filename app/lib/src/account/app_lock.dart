/// The app lock (roadmap Q3): when she's signed in and the app hasn't been used for a day, it opens
/// locked and unlocks with her fingerprint, face or phone PIN. A phone with no screen lock can't be
/// locked this way, so the app stays open there.
library;

import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_service.dart';

const lockAfter = Duration(days: 1);

/// Asks the phone to confirm it's her. Separate so tests can replace it.
abstract interface class DeviceAuth {
  Future<bool> available();
  Future<bool> confirm();
}

class PhoneAuth implements DeviceAuth {
  final _auth = LocalAuthentication();
  @override
  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false; // No lock support here (the browser, say).
    }
  }

  @override
  Future<bool> confirm() async {
    try {
      return await _auth.authenticate(localizedReason: 'Unlock Tsundoku', persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }
}

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.account, required this.child, this.auth, this.clock});
  final AccountService account;
  final Widget child;
  final DeviceAuth? auth;
  final DateTime Function()? clock;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  static const _kLastActive = 'lock.lastActive';
  late final DeviceAuth _auth = widget.auth ?? PhoneAuth();
  late final AppLifecycleListener _lifecycle;
  bool _locked = false;
  bool _asking = false;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _markActive, onResume: _checkLock);
    _checkLock();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _markActive() async {
    if (_locked) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastActive, _now.toIso8601String());
  }

  Future<void> _checkLock() async {
    if (!widget.account.signedIn) return;
    final prefs = await SharedPreferences.getInstance();
    final last = DateTime.tryParse(prefs.getString(_kLastActive) ?? '');
    if (last == null || _now.difference(last) < lockAfter) return;
    if (!await _auth.available()) return;
    if (mounted) setState(() => _locked = true);
    await _unlock();
  }

  Future<void> _unlock() async {
    if (_asking) return;
    _asking = true;
    final ok = await _auth.confirm();
    _asking = false;
    if (ok && mounted) {
      setState(() => _locked = false);
      await _markActive();
    }
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Builder(builder: (context) {
              final cs = Theme.of(context).colorScheme;
              return Material(
                color: cs.surface,
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.lock_outline, size: 56, color: cs.tertiary),
                        const SizedBox(height: 16),
                        Text('Tsundoku is locked', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text('It hasn\'t been used for a day.', style: TextStyle(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 24),
                        FilledButton.icon(onPressed: _unlock, icon: const Icon(Icons.fingerprint), label: const Text('Unlock')),
                      ]),
                    ),
                  ),
                ),
              );
            }),
          ),
      ]);
}
