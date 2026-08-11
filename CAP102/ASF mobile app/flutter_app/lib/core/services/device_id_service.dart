import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// ══════════════════════════════════════════════════════════════════════
// Stable per-install device identifier — part of the sync conflict-
// resolution metadata (device_id / sync_version / last_synced_at /
// updated_at) added to every synced table so a future conflict-resolution
// pass can tell which device last wrote a given row. This is NOT a
// hardware ID: it's a randomly generated UUID persisted via
// SharedPreferences the first time the app runs, so it's stable across
// restarts on one install but changes on reinstall/new device — exactly
// the granularity conflict metadata needs (per-install, not per-user,
// since one user can have the app on several phones).
// ══════════════════════════════════════════════════════════════════════
class DeviceIdService {
  DeviceIdService._();

  static const _prefsKey = 'asf_device_id';
  static String? _cached;

  /// Loads (generating on first run) the device id and caches it in memory.
  /// Called once during app bootstrap in main.dart, before any repository
  /// writes can occur, so [current] is always safe to read synchronously
  /// afterward.
  static Future<String> ensureLoaded() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefsKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_prefsKey, id);
    }
    _cached = id;
    return id;
  }

  /// Synchronous accessor for use inline inside Supabase payload maps and
  /// SQLite row maps. Returns 'unknown' only if read before [ensureLoaded]
  /// has ever completed, which should not happen once app startup has run.
  static String get current => _cached ?? 'unknown';

  /// Convenience for repositories building a Supabase upsert/insert
  /// payload: bundles device_id/sync_version/last_synced_at together in
  /// one spread-able map. [syncVersion] should be the same epoch-ms value
  /// already being sent as that row's updated_at (or created_at for
  /// insert-only tables like activity_logs), so the local SQLite row and
  /// its Supabase mirror always agree on which version this write was.
  static Map<String, dynamic> supabaseSyncFields(int syncVersion) => {
        'device_id': current,
        'sync_version': syncVersion,
        'last_synced_at': DateTime.now().toIso8601String(),
      };
}
