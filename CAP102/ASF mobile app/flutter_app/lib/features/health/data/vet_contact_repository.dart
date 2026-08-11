// ══════════════════════════════════════════════════════════════════════
// A single saved veterinarian contact (name + phone) — the "if the farmer
// has already saved veterinarian contacts" branch the Critical Health
// Alert's "Call Veterinarian" button needs. Same aggregate-settings-row
// pattern as every other single-value setting in this app (see
// DashboardRepository's pigBatchProfile/currentDay, or HealthRepository's
// own healthLogs) — one row per (uid, subkey), best-effort mirrored to
// Supabase.
// ══════════════════════════════════════════════════════════════════════

import '../../../core/config/supabase_config.dart';
import '../../../core/database/safe_parse.dart';
import '../../../core/database/sqlite_service.dart';
import '../../../core/services/device_id_service.dart';

class VetContact {
  const VetContact({this.name = '', this.phone = ''});
  final String name;
  final String phone;

  bool get isSaved => phone.trim().isNotEmpty;

  factory VetContact.fromJson(Map<String, dynamic> json) => VetContact(
        name: (json['name'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};
}

/// Persists the single saved veterinarian contact used by the Critical
/// Health Alert's "Call Veterinarian" button. Local-first (SQLite),
/// best-effort Supabase mirror.
class VetContactRepository {
  final SqliteService _sqlite = SqliteService.instance;

  /// Returns null when no phone number has actually been saved yet — the
  /// caller (Critical Alert dialog) uses that to decide whether to dial
  /// directly or send the farmer to the Vet Contacts screen instead. A
  /// corrupted or unexpectedly-shaped row is treated the same as "no
  /// contact saved" rather than throwing — same defense-in-depth pattern
  /// as HealthDraftRepository.getDraft(), so a bad vetContact row can
  /// never block the Critical Health Alert from opening.
  Future<VetContact?> getVetContact(String uid) async {
    final data =
        await _sqlite.getAggregate('settings', uid, subkey: 'vetContact');
    final contact = parseJsonObjectSafely(data, VetContact.fromJson,
        repoName: 'VetContactRepository.getVetContact');
    return (contact != null && contact.isSaved) ? contact : null;
  }

  /// Saves or replaces the farmer's veterinarian contact.
  Future<void> saveVetContact(String uid, VetContact contact) async {
    await _sqlite.setAggregate('settings', uid, 'vetContact', contact.toJson());
    try {
      await supabase.from('settings').upsert({
        'firebase_uid': uid,
        'subkey': 'vetContact',
        'data': contact.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'firebase_uid,subkey');
    } catch (_) {}
  }
}
