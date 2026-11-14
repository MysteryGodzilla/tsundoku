/// The Settings look picker: one of four accents, and Light or Dark. Until she picks a mode, the
/// app follows the phone's own light/dark setting, in Sage (roadmap Q6).
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/palette.dart';

enum AppearanceMode { system, light, dark }

class AppearanceSettings extends ChangeNotifier {
  AppearanceSettings._(this._prefs, this._accent, this._mode);

  static const _accentKey = 'appearance.accent';
  static const _modeKey = 'appearance.mode';

  static Future<AppearanceSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = AppearanceMode.values.where((m) => m.name == prefs.getString(_modeKey)).firstOrNull ?? AppearanceMode.system;
    return AppearanceSettings._(prefs, Accent.parse(prefs.getString(_accentKey)), mode);
  }

  final SharedPreferences _prefs;
  Accent _accent;
  AppearanceMode _mode;

  Accent get accent => _accent;
  AppearanceMode get mode => _mode;

  Future<void> setAccent(Accent a) async {
    _accent = a;
    notifyListeners();
    await _prefs.setString(_accentKey, a.name);
  }

  Future<void> setMode(AppearanceMode m) async {
    _mode = m;
    notifyListeners();
    await _prefs.setString(_modeKey, m.name);
  }
}
