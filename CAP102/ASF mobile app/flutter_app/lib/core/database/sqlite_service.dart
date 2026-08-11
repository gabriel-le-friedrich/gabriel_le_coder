// ══════════════════════════════════════════════════════════════════════
// ASF — Local SQLite Database (offline-first storage layer)
// ══════════════════════════════════════════════════════════════════════
// Direct Dart port of src/sqlite-db.js, using sqflite instead of
// @capacitor-community/sqlite. Table names, columns, and the
// aggregate-vs-per-row table shape are IDENTICAL to the existing app, so
// the two apps' offline-storage design stays conceptually interchangeable
// even though this is a separate on-device database file (a Flutter app
// and a Capacitor app can never literally share one sqlite file on
// Android — each app has its own private storage sandbox).
//
// Table shapes (unchanged from the JS version):
//   - AGGREGATE tables (feedingLogs, healthLogs, expenses, growthLogs,
//     settings, reports): one row per (uid, subkey), storing one whole
//     JSON blob — matches how the existing app already treats these
//     categories (one array/object per category, not one row per record).
//   - PER-ROW tables (pigs, weeklyPigImages, notifications): one row per
//     real record, each with its own id/updatedAt/synced lifecycle.
// ══════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../services/device_id_service.dart';

class SqliteService {
  SqliteService._();
  static final SqliteService instance = SqliteService._();

  Database? _db;
  Future<Database>? _readyFuture;

  static const List<String> _schemaStatements = [
    '''CREATE TABLE IF NOT EXISTS users (
       id TEXT PRIMARY KEY,
       fullName TEXT, phoneNumber TEXT, municipality TEXT, email TEXT,
       role TEXT, profileImage TEXT, verified INTEGER DEFAULT 0,
       onboardingCompleted INTEGER DEFAULT 0,
       province TEXT, farmName TEXT, farmerType TEXT,
       createdAt INTEGER, updatedAt INTEGER NOT NULL, synced INTEGER DEFAULT 0,
       deviceId TEXT, syncVersion INTEGER DEFAULT 1, lastSyncedAt INTEGER,
       phoneVerified INTEGER DEFAULT 0, lastLogin INTEGER
     );''',
    '''CREATE TABLE IF NOT EXISTS pigs (
       id TEXT PRIMARY KEY,
       uid TEXT NOT NULL,
       data TEXT NOT NULL,
       updatedAt INTEGER NOT NULL,
       synced INTEGER DEFAULT 0,
       deleted INTEGER DEFAULT 0,
       deviceId TEXT, syncVersion INTEGER DEFAULT 1, lastSyncedAt INTEGER
     );''',
    'CREATE INDEX IF NOT EXISTS idx_pigs_uid ON pigs(uid);',
    '''CREATE TABLE IF NOT EXISTS feedingLogs (
       id TEXT PRIMARY KEY, uid TEXT NOT NULL, subkey TEXT NOT NULL,
       data TEXT NOT NULL, updatedAt INTEGER NOT NULL, synced INTEGER DEFAULT 0,
       deviceId TEXT, syncVersion INTEGER DEFAULT 1, lastSyncedAt INTEGER
     );''',
    'CREATE INDEX IF NOT EXISTS idx_feedingLogs_uid ON feedingLogs(uid);',
    '''CREATE TABLE IF NOT EXISTS healthLogs (
       id TEXT PRIMARY KEY, uid TEXT NOT NULL, subkey TEXT NOT NULL,
       data TEXT NOT NULL, updatedAt INTEGER NOT NULL, synced INTEGER DEFAULT 0,
       deviceId TEXT, syncVersion INTEGER DEFAULT 1, lastSyncedAt INTEGER
     );''',
    'CREATE INDEX IF NOT EXISTS idx_healthLogs_uid ON healthLogs(uid);',
    '''CREATE TABLE IF NOT EXISTS growthLogs (
       id TEXT PRIMARY KEY, uid TEXT NOT NULL, subkey TEXT NOT NULL,
       data TEXT NOT NULL, updatedAt INTEGER NOT NULL, synced INTEGER DEFAULT 0,
       deviceId TEXT, syncVersion INTEGER DEFAULT 1, lastSyncedAt INTEGER
     );''',
    'CREATE INDEX IF NOT EXISTS idx_growthLogs_uid ON growthLogs(uid);',
    '''CREATE TABLE IF NOT EXISTS expenses (
       id TEXT PRIMARY KEY, uid TEXT NOT NULL, subkey TEXT NOT NULL,
       data TEXT NOT NULL, updatedAt INTEGER NOT NULL, synced INTEGER DEFAULT 0,
       deviceId TEXT, syncVersion INTEGER DEFAULT 1, lastSyncedAt INTEGER
     );''',
    'CREATE INDEX IF NOT EXISTS idx_expenses_uid ON expenses(uid);',
    '''CREATE TABLE IF NOT EXISTS notifications (
       id TEXT PRIMARY KEY,
       uid TEXT NOT NULL,
       type TEXT,
       data TEXT,
       read INTEGER DEFAULT 0,
       createdAt INTEGER NOT NULL,
       synced INTEGER DEFAULT 0,
       deviceId TEXT, syncVersion INTEGER DEFAULT 1, lastSyncedAt INTEGER
     );''',
    'CREATE INDEX IF NOT EXISTS idx_notifications_uid ON notifications(uid);',
    '''CREATE TABLE IF NOT EXISTS reports (
       id TEXT PRIMARY KEY, uid TEXT NOT NULL, subkey TEXT NOT NULL,
       data TEXT NOT NULL, updatedAt INTEGER NOT NULL, synced INTEGER DEFAULT 0,
       deviceId TEXT, syncVersion INTEGER DEFAULT 1, lastSyncedAt INTEGER
     );''',
    '''CREATE TABLE IF NOT EXISTS weeklyPigImages (
       id TEXT PRIMARY KEY,
       uid TEXT NOT NULL,
       pigId TEXT,
       weekNumber INTEGER,
       localUri TEXT,
       remoteUrl TEXT,
       captureDate TEXT,
       notes TEXT,
       updatedAt INTEGER NOT NULL,
       synced INTEGER DEFAULT 0,
       uploadAttempts INTEGER DEFAULT 0,
       deleted INTEGER DEFAULT 0,
       deviceId TEXT, syncVersion INTEGER DEFAULT 1, lastSyncedAt INTEGER
     );''',
    'CREATE INDEX IF NOT EXISTS idx_images_uid ON weeklyPigImages(uid);',
    '''CREATE TABLE IF NOT EXISTS settings (
       id TEXT PRIMARY KEY, uid TEXT NOT NULL, subkey TEXT NOT NULL,
       data TEXT, updatedAt INTEGER NOT NULL, synced INTEGER DEFAULT 0,
       deviceId TEXT, syncVersion INTEGER DEFAULT 1, lastSyncedAt INTEGER
     );''',
    'CREATE INDEX IF NOT EXISTS idx_settings_uid ON settings(uid);',
    '''CREATE TABLE IF NOT EXISTS sync_meta (
       id TEXT PRIMARY KEY, lastSyncAt INTEGER, lastSyncStatus TEXT
     );''',
    '''CREATE TABLE IF NOT EXISTS activityLogs (
       id TEXT PRIMARY KEY,
       uid TEXT NOT NULL,
       actionType TEXT,
       description TEXT,
       username TEXT,
       createdAt INTEGER NOT NULL,
       synced INTEGER DEFAULT 0,
       deviceId TEXT, syncVersion INTEGER DEFAULT 1, lastSyncedAt INTEGER,
       action TEXT, status TEXT
     );''',
    'CREATE INDEX IF NOT EXISTS idx_activityLogs_uid ON activityLogs(uid);',
    // Brevo email integration (v6) — see lib/features/email/.
    // consultations: per-row, same shape as pigs/notifications — one row
    // per Expert Consultation request, pushed to Supabase's
    // public.consultations table via the sync engine.
    '''CREATE TABLE IF NOT EXISTS consultations (
       id TEXT PRIMARY KEY,
       uid TEXT NOT NULL,
       data TEXT NOT NULL,
       createdAt INTEGER NOT NULL,
       synced INTEGER DEFAULT 0,
       deviceId TEXT, syncVersion INTEGER DEFAULT 1, lastSyncedAt INTEGER
     );''',
    'CREATE INDEX IF NOT EXISTS idx_consultations_uid ON consultations(uid);',
    // emailQueue: purely local, never synced to Supabase — the offline
    // retry queue for outbound Brevo emails. A row here means "the
    // send-email Edge Function call for this email hasn't succeeded yet";
    // EmailRepository.resyncPending() (called by SyncEngine, same as every
    // other repository's resync method) retries it with exponential
    // backoff via nextAttemptAt, up to 3 attempts.
    '''CREATE TABLE IF NOT EXISTS emailQueue (
       id TEXT PRIMARY KEY,
       uid TEXT NOT NULL,
       emailType TEXT NOT NULL,
       payload TEXT NOT NULL,
       recipient TEXT,
       status TEXT NOT NULL DEFAULT 'pending',
       retryCount INTEGER NOT NULL DEFAULT 0,
       nextAttemptAt INTEGER,
       lastError TEXT,
       createdAt INTEGER NOT NULL,
       updatedAt INTEGER NOT NULL
     );''',
    'CREATE INDEX IF NOT EXISTS idx_emailQueue_uid ON emailQueue(uid);',
  ];

  /// Tables that carry the sync conflict-resolution metadata columns
  /// (deviceId/syncVersion/lastSyncedAt), added in schema v3. Used by the
  /// v2->v3 migration below to apply the same three ALTER TABLE statements
  /// to every one of them without repeating the column list eleven times.
  static const List<String> _syncMetadataTables = [
    'users',
    'pigs',
    'feedingLogs',
    'healthLogs',
    'growthLogs',
    'expenses',
    'notifications',
    'reports',
    'weeklyPigImages',
    'settings',
    'activityLogs',
  ];

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'asf_offline.db');
    final database = await openDatabase(
      dbPath,
      version: 6,
      onCreate: (db, version) async {
        for (final stmt in _schemaStatements) {
          await db.execute(stmt);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2: Settings module's Profile editing added province/farmName/
        // farmerType to the `users` table. New installs already get these
        // columns via the CREATE TABLE statement above; existing installs
        // need them added in place. Each ADD COLUMN is wrapped individually
        // since sqflite has no "IF NOT EXISTS" for columns and this must
        // stay a no-op/non-fatal if it somehow already ran.
        if (oldVersion < 2) {
          for (final col in ['province', 'farmName', 'farmerType']) {
            try {
              await db.execute('ALTER TABLE users ADD COLUMN $col TEXT;');
            } catch (_) {}
          }
        }
        // v2 -> v3: sync conflict-resolution metadata (see the sync
        // conflict metadata task) — every synced table gains deviceId/
        // syncVersion/lastSyncedAt so a future device can tell which
        // install last wrote a row and compare versions. New installs
        // already get these via the CREATE TABLE statements above.
        if (oldVersion < 3) {
          for (final table in _syncMetadataTables) {
            for (final ddl in [
              'ALTER TABLE $table ADD COLUMN deviceId TEXT;',
              'ALTER TABLE $table ADD COLUMN syncVersion INTEGER DEFAULT 1;',
              'ALTER TABLE $table ADD COLUMN lastSyncedAt INTEGER;',
            ]) {
              try {
                await db.execute(ddl);
              } catch (_) {}
            }
          }
        }
        // v3 -> v4: structured activity-log fields (logging system audit
        // fix #1) — activityLogs gains explicit `action` (e.g. LOGIN,
        // EXPENSE_ADD) and `status` (SUCCESS/FAILED) columns instead of
        // only a free-text `description` that narrated success/failure in
        // prose. Both are nullable so every pre-existing row stays valid
        // (read as action=null/status=null, which AuthRepository and the
        // Activity Log viewer already treat as "no structured data
        // available" rather than an error) — no backfill needed, no
        // existing row becomes unreadable.
        if (oldVersion < 4) {
          for (final ddl in [
            'ALTER TABLE activityLogs ADD COLUMN action TEXT;',
            'ALTER TABLE activityLogs ADD COLUMN status TEXT;',
          ]) {
            try {
              await db.execute(ddl);
            } catch (_) {}
          }
        }
        // v4 -> v5: Phone Auth audit — explicit `phoneVerified` and
        // `lastLogin` columns on `users`. `phoneVerified` mirrors the
        // existing `verified` column's intent (both are only ever set true
        // once the OTP step actually completes — see
        // AuthRepository.createUserProfile) but under an unambiguous name
        // now that this table also has to represent phone-login users,
        // matching the field the audit explicitly asked for. `lastLogin` is
        // stamped on every successful sign-in (email/password AND phone
        // OTP) — previously only recorded as an activity-log row, not on
        // the user record itself.
        if (oldVersion < 5) {
          for (final ddl in [
            'ALTER TABLE users ADD COLUMN phoneVerified INTEGER DEFAULT 0;',
            'ALTER TABLE users ADD COLUMN lastLogin INTEGER;',
          ]) {
            try {
              await db.execute(ddl);
            } catch (_) {}
          }
        }
        // v5 -> v6: Brevo email integration — new `consultations` (synced)
        // and `emailQueue` (local-only) tables. Both statements are
        // CREATE TABLE IF NOT EXISTS, safe to run even if a future
        // onCreate already made them.
        if (oldVersion < 6) {
          for (final ddl in [
            '''CREATE TABLE IF NOT EXISTS consultations (
               id TEXT PRIMARY KEY,
               uid TEXT NOT NULL,
               data TEXT NOT NULL,
               createdAt INTEGER NOT NULL,
               synced INTEGER DEFAULT 0,
               deviceId TEXT, syncVersion INTEGER DEFAULT 1, lastSyncedAt INTEGER
             );''',
            'CREATE INDEX IF NOT EXISTS idx_consultations_uid ON consultations(uid);',
            '''CREATE TABLE IF NOT EXISTS emailQueue (
               id TEXT PRIMARY KEY,
               uid TEXT NOT NULL,
               emailType TEXT NOT NULL,
               payload TEXT NOT NULL,
               recipient TEXT,
               status TEXT NOT NULL DEFAULT 'pending',
               retryCount INTEGER NOT NULL DEFAULT 0,
               nextAttemptAt INTEGER,
               lastError TEXT,
               createdAt INTEGER NOT NULL,
               updatedAt INTEGER NOT NULL
             );''',
            'CREATE INDEX IF NOT EXISTS idx_emailQueue_uid ON emailQueue(uid);',
          ]) {
            try {
              await db.execute(ddl);
            } catch (_) {}
          }
        }
      },
    );
    return database;
  }

  /// Idempotent — safe to call from multiple places. Never throws: callers
  /// should still guard against a null/failed database the same way the
  /// JS version's initSqlite() does (falling back to in-memory state only
  /// if this genuinely fails, which should be rare on a real device).
  Future<Database> init() {
    return _readyFuture ??= _open().then((db) {
      _db = db;
      return db;
    });
  }

  Database get _requireDb {
    final db = _db;
    if (db == null) {
      throw StateError('SqliteService.init() must complete before use.');
    }
    return db;
  }

  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  // ── Aggregate table helpers (feedingLogs / healthLogs / expenses /
  // growthLogs / reports / settings — one row per uid+subkey) ──
  Future<dynamic> getAggregate(String table, String uid,
      {String subkey = 'main'}) async {
    await init();
    final id = '$uid:$subkey';
    final rows =
        await _requireDb.query(table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty || rows.first['data'] == null) return null;
    try {
      return jsonDecode(rows.first['data'] as String);
    } catch (_) {
      return null;
    }
  }

  Future<bool> setAggregate(
    String table,
    String uid,
    String subkey,
    dynamic value, {
    int? updatedAt,
    bool synced = false,
  }) async {
    await init();
    final id = '$uid:$subkey';
    final resolvedUpdatedAt = updatedAt ?? nowMs();
    await _requireDb.insert(
      table,
      {
        'id': id,
        'uid': uid,
        'subkey': subkey,
        'data': jsonEncode(value),
        'updatedAt': resolvedUpdatedAt,
        'synced': synced ? 1 : 0,
        // Sync conflict-resolution metadata: deviceId identifies which
        // install wrote this row; syncVersion piggybacks on the write's own
        // timestamp (monotonic per row, no extra query needed) so a future
        // conflict-resolution pass can compare "which write is newer"
        // without a separate counter table; lastSyncedAt is only stamped
        // when the caller already knows this value came from/reached the
        // server (mirrors the existing `synced` flag's own semantics).
        'deviceId': DeviceIdService.current,
        'syncVersion': resolvedUpdatedAt,
        'lastSyncedAt': synced ? nowMs() : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAggregates(
      String table, String uid) async {
    await init();
    return _requireDb
        .query(table, where: 'uid = ? AND synced = 0', whereArgs: [uid]);
  }

  Future<void> markAggregateSynced(
      String table, String uid, String subkey) async {
    await init();
    await _requireDb.update(table, {'synced': 1, 'lastSyncedAt': nowMs()},
        where: 'id = ?', whereArgs: ['$uid:$subkey']);
  }

  // ── Per-row table helpers (pigs / weeklyPigImages / notifications) ──
  Future<bool> upsertRow(String table, Map<String, dynamic> row) async {
    await init();
    // Sync conflict-resolution metadata (see setAggregate's doc above for
    // the reasoning) — injected here so none of this method's ~11 call
    // sites across the repositories need to be individually updated.
    final merged = Map<String, dynamic>.from(row);
    merged['deviceId'] ??= DeviceIdService.current;
    final resolvedUpdatedAt = merged['updatedAt'] as int? ?? nowMs();
    merged['syncVersion'] = resolvedUpdatedAt;
    final syncedVal = merged['synced'];
    final isSynced = syncedVal == 1 || syncedVal == true;
    if (isSynced) merged['lastSyncedAt'] = nowMs();
    await _requireDb.insert(table, merged,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  Future<List<Map<String, dynamic>>> getRows(
    String table,
    String uid, {
    bool includeDeleted = false,
  }) async {
    await init();
    final where = includeDeleted
        ? 'uid = ?'
        : 'uid = ? AND (deleted IS NULL OR deleted = 0)';
    return _requireDb.query(table, where: where, whereArgs: [uid]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRows(
      String table, String uid) async {
    await init();
    return _requireDb
        .query(table, where: 'uid = ? AND synced = 0', whereArgs: [uid]);
  }

  Future<void> markRowSynced(String table, String id,
      {Map<String, dynamic> extra = const {}}) async {
    await init();
    await _requireDb.update(
      table,
      {'synced': 1, 'lastSyncedAt': nowMs(), ...extra},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Bulk form of [markRowSynced] — marks every id in [ids] synced in one
  /// SQL statement instead of one UPDATE per row. Added for the logging
  /// system audit's bulk-upload fix: once a repository pushes a whole
  /// batch to Supabase in a single request, it should be able to mark
  /// that whole batch synced just as cheaply, rather than looping
  /// [markRowSynced] once per row (still correct, just needlessly slow
  /// for a batch of any real size). No-op on an empty list.
  Future<void> markRowsSynced(String table, List<String> ids) async {
    if (ids.isEmpty) return;
    await init();
    final placeholders = List.filled(ids.length, '?').join(',');
    await _requireDb.rawUpdate(
      'UPDATE $table SET synced = 1, lastSyncedAt = ? WHERE id IN ($placeholders)',
      [nowMs(), ...ids],
    );
  }

  Future<void> softDeleteRow(String table, String id) async {
    await init();
    await _requireDb.update(
      table,
      {'deleted': 1, 'synced': 0, 'updatedAt': nowMs()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── activityLogs (immutable audit trail) ──
  Future<List<Map<String, dynamic>>> getActivityLogs(String uid) async {
    await init();
    return _requireDb.query(
      'activityLogs',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'createdAt DESC',
    );
  }

  // ── users table (single profile row per uid) ──
  Future<bool> upsertUser(Map<String, dynamic> profile) =>
      upsertRow('users', profile);

  Future<Map<String, dynamic>?> getUser(String uid) async {
    await init();
    final rows =
        await _requireDb.query('users', where: 'id = ?', whereArgs: [uid]);
    return rows.isEmpty ? null : rows.first;
  }

  // ── emailQueue (local-only outbound-email retry queue, see
  // lib/features/email/data/email_repository.dart) ──
  Future<void> upsertEmailQueueItem(Map<String, dynamic> row) async {
    await init();
    await _requireDb.insert('emailQueue', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Rows that are still pending and due for another attempt (nextAttemptAt
  /// is null — never tried — or in the past). Rows whose backoff window
  /// hasn't elapsed yet are deliberately excluded so a periodic sync pass
  /// doesn't hammer Brevo/the Edge Function before the delay is up.
  Future<List<Map<String, dynamic>>> getDueEmailQueueItems(String uid) async {
    await init();
    final now = nowMs();
    return _requireDb.query(
      'emailQueue',
      where:
          "uid = ? AND status = 'pending' AND (nextAttemptAt IS NULL OR nextAttemptAt <= ?)",
      whereArgs: [uid, now],
    );
  }

  Future<void> updateEmailQueueItem(
    String id, {
    required String status,
    required int retryCount,
    int? nextAttemptAt,
    String? lastError,
  }) async {
    await init();
    await _requireDb.update(
      'emailQueue',
      {
        'status': status,
        'retryCount': retryCount,
        'nextAttemptAt': nextAttemptAt,
        'lastError': lastError,
        'updatedAt': nowMs(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteEmailQueueItem(String id) async {
    await init();
    await _requireDb.delete('emailQueue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setSyncMeta(String uid, String status) async {
    await init();
    await _requireDb.insert(
      'sync_meta',
      {'id': uid, 'lastSyncAt': nowMs(), 'lastSyncStatus': status},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
