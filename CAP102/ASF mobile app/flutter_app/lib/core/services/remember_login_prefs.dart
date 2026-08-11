// Ported from the REMEMBER_KEY / DISMISSED_VERSION_KEY logic in
// auth-main.js — plain SharedPreferences flags, separate from Firebase's
// own session persistence (which always persists regardless of this flag).

import 'package:shared_preferences/shared_preferences.dart';

class RememberLoginPrefs {
  static const _rememberKey = 'asf_remember_login';
  static const _dismissedUpdateVersionKey = 'asf_update_dismissed_version';

  Future<void> setRemember(bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberKey, remember ? 'true' : 'false');
  }

  /// Returns true unless the user explicitly unchecked "Remember Login" on
  /// their last login — matches the JS version's "any other value
  /// (including none at all) is treated as remembered" behavior.
  Future<bool> shouldRemember() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberKey) != 'false';
  }

  Future<String?> getDismissedUpdateVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dismissedUpdateVersionKey);
  }

  Future<void> setDismissedUpdateVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedUpdateVersionKey, version);
  }
}
