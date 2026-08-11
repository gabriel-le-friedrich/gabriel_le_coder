// ══════════════════════════════════════════════════════════════════════
// Expenses data access — reads/writes the same SQLite aggregate row
// (expenses/main) the Onboarding slice seeds with the initial feed cost
// entry and the Dashboard already reads for ROI. Supabase writes are the
// same best-effort, individually-wrapped pattern as every other repository
// in this app — a failure here never blocks the local, offline-first
// read/write path. Matches the web app's addExpense()/editExpense()/
// deleteExpense() (see saveExpense()/getExpenses() in index.html) plus the
// new firebase_uid/created_at/updated_at fields the Flutter spec adds.
// ══════════════════════════════════════════════════════════════════════

import '../../../core/config/supabase_config.dart';
import '../../../core/database/safe_parse.dart';
import '../../../core/database/sqlite_service.dart';
import '../../../core/services/device_id_service.dart';
import '../../dashboard/domain/dashboard_calculations.dart';

class ExpensesRepository {
  final SqliteService _sqlite = SqliteService.instance;

  Future<List<ExpenseEntry>> getExpenses(String uid) async {
    final data = await _sqlite.getAggregate('expenses', uid, subkey: 'main');
    final list = parseJsonListSafely(data, ExpenseEntry.fromJson,
            repoName: 'ExpensesRepository.getExpenses')
        .entries;
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> _setExpenses(String uid, List<ExpenseEntry> expenses) async {
    final nowMs = SqliteService.nowMs();
    await _sqlite.setAggregate(
        'expenses', uid, 'main', expenses.map((e) => e.toJson()).toList());
    try {
      await supabase.from('settings').upsert({
        'firebase_uid': uid,
        'subkey': 'expenses',
        'data': expenses.map((e) => e.toJson()).toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(nowMs),
      }, onConflict: 'firebase_uid,subkey');
    } catch (_) {}
  }

  Future<void> _mirrorExpenseToSupabase(String uid, ExpenseEntry entry) async {
    try {
      await supabase.from('expenses').upsert({
        'firebase_uid': uid,
        'app_entry_id': '${entry.id}',
        'category': entry.category,
        'description': entry.description,
        'amount': entry.amount,
        'expense_date': entry.date,
        'note': entry.note,
        'created_at': entry.createdAt,
        'updated_at': entry.updatedAt,
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'firebase_uid,app_entry_id');
    } catch (_) {}
  }

  /// Adds a new expense. The id is generated the same way the web app's
  /// nextExpenseId++ counter worked — highest existing id + 1 — computed
  /// fresh from what's actually on file, so there's no separate counter
  /// that could drift from the real data.
  Future<ExpenseEntry> addExpense({
    required String uid,
    required String category,
    required String description,
    required double amount,
    required String date,
    String note = '',
  }) async {
    final expenses = await getExpenses(uid);
    final nextId =
        expenses.fold<int>(0, (max, e) => e.id > max ? e.id : max) + 1;
    final nowIso = DateTime.now().toIso8601String();
    final entry = ExpenseEntry(
      id: nextId,
      category: category,
      description: description,
      amount: amount,
      date: date,
      note: note,
      firebaseUid: uid,
      createdAt: nowIso,
      updatedAt: nowIso,
    );
    final updated = [...expenses, entry];
    await _setExpenses(uid, updated);
    await _mirrorExpenseToSupabase(uid, entry);
    return entry;
  }

  Future<void> updateExpense({
    required String uid,
    required int id,
    required String category,
    required String description,
    required double amount,
    required String date,
    String note = '',
  }) async {
    final expenses = await getExpenses(uid);
    final idx = expenses.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final updatedEntry = expenses[idx].copyWith(
      category: category,
      description: description,
      amount: amount,
      date: date,
      note: note,
      updatedAt: DateTime.now().toIso8601String(),
    );
    final updated = [...expenses]..[idx] = updatedEntry;
    await _setExpenses(uid, updated);
    await _mirrorExpenseToSupabase(uid, updatedEntry);
  }

  Future<void> deleteExpense({required String uid, required int id}) async {
    final expenses = await getExpenses(uid);
    final updated = expenses.where((e) => e.id != id).toList();
    await _setExpenses(uid, updated);
    try {
      await supabase
          .from('expenses')
          .delete()
          .eq('firebase_uid', uid)
          .eq('app_entry_id', '$id');
    } catch (_) {}
  }

  /// First-login-on-a-new-device support. getExpenses() only ever reads the
  /// local SQLite aggregate cache, which starts out completely empty on a
  /// fresh install/reinstall — even for an account that already has
  /// expenses recorded in the cloud from a different phone. The old sync
  /// engine only ever pushed local->cloud, never pulled cloud->local, which
  /// is exactly why expenses entered on one phone never showed up after
  /// switching to another. Only pulls when the local cache is empty, so an
  /// existing device's own not-yet-synced edits are never overwritten by
  /// this.
  Future<void> pullFromCloudIfEmpty(String uid) async {
    try {
      final local = await getExpenses(uid);
      if (local.isNotEmpty) return;
      final rows =
          await supabase.from('expenses').select().eq('firebase_uid', uid);
      if ((rows as List).isEmpty) return;
      final entries = rows.map((map) {
        return ExpenseEntry(
          id: int.tryParse('${map['app_entry_id']}') ?? 0,
          category: map['category'] as String? ?? 'other',
          description: map['description'] as String? ?? '',
          amount: (map['amount'] as num?)?.toDouble() ?? 0,
          date: map['expense_date'] as String? ?? '',
          note: map['note'] as String? ?? '',
          firebaseUid: uid,
          createdAt: map['created_at'] as String?,
          updatedAt: map['updated_at'] as String?,
        );
      }).toList();
      await _sqlite.setAggregate(
          'expenses', uid, 'main', entries.map((e) => e.toJson()).toList(),
          synced: true);
    } catch (_) {
      // Offline or Supabase unreachable — local (empty) cache stays as-is;
      // this runs again on the next bootstrap/reconnect.
    }
  }

  /// Sync engine support — re-pushes the current list unconditionally.
  /// There's no per-entry "did this reach Supabase" flag today (only the
  /// whole-blob `expenses/main` aggregate row has a synced bit, and
  /// `_setExpenses` never actually flips it true), so the correct-but-
  /// simple fix is an idempotent full re-push: every upsert here is keyed
  /// by `(firebase_uid, app_entry_id)`, so re-sending an already-synced
  /// entry is a harmless no-op, not a duplicate. Fine at this app's real
  /// scale (tens of expenses per 120-day cycle).
  /// Bug B3 fix: pushes every expense in ONE batched upsert instead of one
  /// Supabase request per row — mirrors the batching already applied to
  /// PigRepository.resyncPendingImages/resyncPendingPigs. Falls back to
  /// per-row upserts only if the whole-batch call itself fails.
  Future<void> resyncPending(String uid) async {
    final expenses = await getExpenses(uid);
    await _setExpenses(uid, expenses);
    if (expenses.isEmpty) return;
    final payload = expenses
        .map((e) => {
              'firebase_uid': uid,
              'app_entry_id': '${e.id}',
              'category': e.category,
              'description': e.description,
              'amount': e.amount,
              'expense_date': e.date,
              'note': e.note,
              'created_at': e.createdAt,
              'updated_at': e.updatedAt,
              ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
            })
        .toList();
    try {
      await supabase
          .from('expenses')
          .upsert(payload, onConflict: 'firebase_uid,app_entry_id');
    } catch (_) {
      for (final e in expenses) {
        await _mirrorExpenseToSupabase(uid, e);
      }
    }
  }
}
