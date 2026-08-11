// ══════════════════════════════════════════════════════════════════════
// OTA-style update check — faithful port of auth-main.js's
// window.AsfCheckForUpdate (lines 522-538 there). Reads the same
// `app_releases` Supabase table (public read-only, admin-only inserts —
// see supabase_schema.sql:558-572), compares against the running app's
// version (package_info_plus == the Capacitor App.getInfo().version
// equivalent), and respects a device-local "dismissed this version"
// flag (RememberLoginPrefs, already built for exactly this key). Never
// throws — a failed check (offline, no rows yet, etc.) just means no
// update prompt this launch, same as the legacy try/catch.
// ══════════════════════════════════════════════════════════════════════

import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/services/remember_login_prefs.dart';
import '../domain/ota_update.dart';

class OtaUpdateRepository {
  final RememberLoginPrefs _prefs = RememberLoginPrefs();

  Future<String> _currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '1.0.0'; // web/unsupported-platform fallback — keep in sync with pubspec.yaml
    }
  }

  Future<AppRelease?> checkForUpdate() async {
    try {
      final res = await supabase
          .from('app_releases')
          .select('version, apk_url, notes')
          .order('published_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;

      final latestVersion = res['version'] as String?;
      final apkUrl = res['apk_url'] as String?;
      if (latestVersion == null || apkUrl == null) return null;

      final current = await _currentVersion();
      if (compareVersions(latestVersion, current) <= 0) return null;

      final dismissed = await _prefs.getDismissedUpdateVersion();
      if (dismissed == latestVersion) return null;

      return AppRelease(
          version: latestVersion,
          apkUrl: apkUrl,
          notes: res['notes'] as String?);
    } catch (_) {
      return null;
    }
  }

  Future<void> dismiss(String version) =>
      _prefs.setDismissedUpdateVersion(version);
}
