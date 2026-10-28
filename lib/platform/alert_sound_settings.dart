import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alert_sound.dart';

/// Which alert sounds this till (or browser) plays. Saved on the device, not in the cafe's
/// settings, because each till is in a different spot and may want a different volume of noise.
class AlertSoundSettings extends ChangeNotifier {
  AlertSoundSettings._();

  static final AlertSoundSettings instance = AlertSoundSettings._();

  static const _allKey = 'alert_sound_all';
  static String _key(AlertKind kind) => 'alert_sound_${kind.name}';

  bool _all = true;
  final Map<AlertKind, bool> _kinds = {for (final kind in AlertKind.values) kind: true};
  bool _loaded = false;

  /// Master switch: off silences every alert.
  bool get all => _all;

  bool isOn(AlertKind kind) => _kinds[kind] ?? true;

  /// Whether [kind] should make a sound right now.
  bool plays(AlertKind kind) => _all && isOn(kind);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _all = prefs.getBool(_allKey) ?? true;
      for (final kind in AlertKind.values) {
        _kinds[kind] = prefs.getBool(_key(kind)) ?? true;
      }
      notifyListeners();
    } catch (_) {
      // Settings unreadable: every sound stays on.
    }
  }

  Future<void> setAll(bool value) async {
    _all = value;
    notifyListeners();
    await _save(_allKey, value);
  }

  Future<void> setKind(AlertKind kind, bool value) async {
    _kinds[kind] = value;
    notifyListeners();
    await _save(_key(kind), value);
  }

  Future<void> _save(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // Not saved; the choice still holds until the app closes.
    }
  }
}
