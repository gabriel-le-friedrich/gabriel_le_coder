// ══════════════════════════════════════════════════════════════════════
// Settings module: Theme + Language preferences (new, no legacy web
// equivalent for Theme; Language mirrors index.html's toggleLang()), plus
// Profile editing (delegates to AuthRepository, which owns the `profiles`
// table) and Logout. Theme/Language follow the exact same SQLite-first,
// best-effort-Supabase-mirror pattern as NotificationRepository, storing
// into the generic `settings` aggregate table (subkeys: 'themeMode',
// 'appLanguage') alongside farmerProfile/pigBatchProfile/notifPrefs/
// appLang, per supabase_schema.sql's own comment describing that table.
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/database/sqlite_service.dart';
import '../../../core/services/device_id_service.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/app_language.dart';

class SettingsRepository {
  SettingsRepository({AuthRepository? authRepo})
      : _authRepo = authRepo ?? AuthRepository();

  final AuthRepository _authRepo;
  final SqliteService _sqlite = SqliteService.instance;

  // ── Theme ──

  Future<ThemeMode> getThemeMode(String uid) async {
    final data =
        await _sqlite.getAggregate('settings', uid, subkey: 'themeMode');
    final mode = data is Map ? data['mode'] as String? : null;
    return _themeModeFromString(mode);
  }

  Future<void> setThemeMode(String uid, ThemeMode mode) async {
    await _sqlite
        .setAggregate('settings', uid, 'themeMode', {'mode': mode.name});
    try {
      await supabase.from('settings').upsert({
        'firebase_uid': uid,
        'subkey': 'themeMode',
        'data': {'mode': mode.name},
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'firebase_uid,subkey');
    } catch (_) {}
    await _authRepo.recordActivityLog(
      uid: uid,
      actionType: 'settings',
      description: 'Changed theme to ${_themeModeLabel(mode)}',
    );
  }

  ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.system:
        return 'System default';
    }
  }

  // ── Language ──

  Future<AppLanguage> getLanguage(String uid) async {
    final data =
        await _sqlite.getAggregate('settings', uid, subkey: 'appLanguage');
    final code = data is Map ? data['lang'] as String? : null;
    return AppLanguage.fromCode(code);
  }

  Future<void> setLanguage(String uid, AppLanguage lang) async {
    await _sqlite
        .setAggregate('settings', uid, 'appLanguage', {'lang': lang.code});
    try {
      await supabase.from('settings').upsert({
        'firebase_uid': uid,
        'subkey': 'appLanguage',
        'data': {'lang': lang.code},
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'firebase_uid,subkey');
    } catch (_) {}
    await _authRepo.recordActivityLog(
      uid: uid,
      actionType: 'settings',
      description: 'Changed app language to ${lang.label}',
    );
  }

  // ── Profile ──

  Future<Map<String, dynamic>?> getProfile(String uid) =>
      _authRepo.getUserProfile(uid);

  /// Returns the new display path (local file or remote URL) on success,
  /// or null if the picked image couldn't be compressed under the 3 MB cap.
  Future<String?> updateProfileImage(String uid, String localImagePath) async {
    final path = await _authRepo.updateProfileImage(uid, localImagePath);
    if (path != null) {
      await _authRepo.recordActivityLog(
          uid: uid,
          actionType: 'settings',
          description: 'Updated profile photo');
    }
    return path;
  }

  Future<void> updateProfile(
    String uid, {
    required String fullName,
    required String municipality,
    String? province,
    String? farmName,
    String? farmerType,
    String? phoneNumber,
    String? email,
  }) async {
    await _authRepo.updateProfileFields(
      uid,
      fullName: fullName,
      municipality: municipality,
      province: province,
      farmName: farmName,
      farmerType: farmerType,
      phoneNumber: phoneNumber,
      email: email,
    );
    await _authRepo.recordActivityLog(
      uid: uid,
      actionType: 'settings',
      description: 'Updated profile settings',
    );
  }

  /// Sync engine support — re-pushes the current theme/language values.
  /// Cheap (two small upserts) and idempotent, so it's safe to call on
  /// every reconnect regardless of whether the previous push actually
  /// failed.
  Future<void> resyncPending(String uid) async {
    final mode = await getThemeMode(uid);
    try {
      await supabase.from('settings').upsert({
        'firebase_uid': uid,
        'subkey': 'themeMode',
        'data': {'mode': mode.name},
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'firebase_uid,subkey');
    } catch (_) {}
    final lang = await getLanguage(uid);
    try {
      await supabase.from('settings').upsert({
        'firebase_uid': uid,
        'subkey': 'appLanguage',
        'data': {'lang': lang.code},
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'firebase_uid,subkey');
    } catch (_) {}
  }

  // Logout itself is NOT duplicated here — AuthFlowController.logout()
  // (features/auth/presentation/providers/auth_providers.dart) already
  // records the "logged out" activity entry before signing out, matching
  // auth-main.js's ordering exactly, and is already wired to the
  // Dashboard's app bar icon. The Settings screen's Logout menu item calls
  // that same controller method so there's one canonical logout path.
}
