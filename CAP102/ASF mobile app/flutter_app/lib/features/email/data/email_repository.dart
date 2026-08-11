// ══════════════════════════════════════════════════════════════════════
// ASF — EmailRepository: the ONLY place in the Flutter app that talks to
// the Brevo integration, and it never talks to Brevo directly — every
// call goes through the `send-email` Supabase Edge Function
// (supabase/functions/send-email/index.ts), which is the only place the
// Brevo API key exists. See BREVO_SETUP.md.
//
// Retry/offline design (spec items 10-12):
//   - Every send first tries up to 3 immediate in-process attempts with a
//     short exponential backoff (2s, 4s) — covers "online but Brevo/network
//     hiccuped for a moment".
//   - If all 3 immediate attempts fail (including "genuinely offline, the
//     Edge Function call never even completed"), the email is written to
//     the local `emailQueue` SQLite table instead of being dropped.
//   - resyncPending(uid) — called by SyncEngine.syncNow() exactly like
//     every other repository's resync method — retries queued emails with
//     a longer backoff (30s/60s/120s) until they succeed or exhaust 3
//     queued attempts, at which point the row is marked 'failed' and left
//     for manual inspection (Testing screen / a future email-history view)
//     rather than retried forever.
//   - Nothing in this class ever throws — every public method returns an
//     EmailSendResult, so a failed welcome/consultation email can never
//     crash registration or a consultation submission (spec item 11).
// ══════════════════════════════════════════════════════════════════════

import 'dart:convert';

import '../../../core/config/supabase_config.dart';
import '../../../core/database/sqlite_service.dart';
import '../domain/email_models.dart';

class EmailRepository {
  final SqliteService _sqlite = SqliteService.instance;

  static const int _maxImmediateAttempts = 3;
  static const int _maxQueuedAttempts = 3;
  static const int _queueBaseBackoffSeconds = 30;

  // ── Public API — one method per spec function ──

  Future<EmailSendResult> sendWelcomeEmail(String uid,
      {required String to, required String name}) {
    return _sendWithRetry(uid, EmailType.welcome,
        to: to, toName: name, data: {'name': name});
  }

  Future<EmailSendResult> sendPasswordResetEmail(String uid,
      {required String to, String? name}) {
    return _sendWithRetry(
      uid,
      EmailType.passwordReset,
      to: to,
      toName: name,
      data: {'email': to, if (name != null) 'name': name},
    );
  }

  /// Sent to the ATI administrator (ADMIN_EMAIL secret) — the Edge
  /// Function resolves the recipient server-side for this type, so no
  /// `to` is passed. [data] must contain: referenceNumber, farmerName,
  /// farmerEmail, pigBatch, currentWeight, issueCategory,
  /// problemDescription, photoUrl (optional), submittedAt.
  Future<EmailSendResult> sendConsultationRequest(String uid,
      {required Map<String, dynamic> data}) {
    return _sendWithRetry(uid, EmailType.consultationRequest, data: data);
  }

  /// Sent to the farmer who submitted the request. [data] must contain:
  /// farmerName, referenceNumber, date, summary, expectedResponseTime.
  Future<EmailSendResult> sendConsultationConfirmation(
    String uid, {
    required String to,
    required Map<String, dynamic> data,
  }) {
    return _sendWithRetry(uid, EmailType.consultationConfirmation,
        to: to, toName: data['farmerName'] as String?, data: data);
  }

  /// Generic admin alert — used for critical health alerts today, and
  /// reusable for any future event (e.g. a feedback feature) that should
  /// notify the ATI administrator. [category] is a free-text tag (e.g.
  /// 'health_alert') the template uses to decide whether to show the
  /// red "Critical Alert" banner. [meta] is rendered as a simple label/
  /// value table under the message.
  Future<EmailSendResult> sendAdminNotification(
    String uid, {
    required String title,
    required String message,
    String? category,
    Map<String, dynamic>? meta,
  }) {
    return _sendWithRetry(
      uid,
      EmailType.adminNotification,
      data: {
        'title': title,
        'message': message,
        if (category != null) 'category': category,
        if (meta != null) 'meta': meta,
      },
    );
  }

  Future<EmailSendResult> sendTestingEmail(String uid,
      {required String to, String? name}) {
    return _sendWithRetry(uid, EmailType.test,
        to: to, toName: name, data: {if (name != null) 'name': name});
  }

  // ── Internals ──

  Future<EmailSendResult> _invokeOnce(
    EmailType type, {
    String? to,
    String? toName,
    required String firebaseUid,
    Map<String, dynamic>? data,
  }) async {
    try {
      final res = await supabase.functions.invoke(
        'send-email',
        body: {
          'type': type.wireValue,
          if (to != null) 'to': to,
          if (toName != null) 'toName': toName,
          'firebaseUid': firebaseUid,
          'data': data ?? const <String, dynamic>{},
        },
      );
      final body = res.data;
      final map =
          body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
      final ok =
          res.status >= 200 && res.status < 300 && map['success'] == true;
      if (ok) return const EmailSendResult(success: true);
      return EmailSendResult(
        success: false,
        error: map['error']?.toString() ??
            'Email send failed (HTTP ${res.status})',
        responseCode: res.status,
      );
    } catch (e) {
      return EmailSendResult(success: false, error: e.toString());
    }
  }

  Future<EmailSendResult> _sendWithRetry(
    String uid,
    EmailType type, {
    String? to,
    String? toName,
    Map<String, dynamic>? data,
  }) async {
    EmailSendResult last =
        const EmailSendResult(success: false, error: 'Not attempted');
    for (var attempt = 0; attempt < _maxImmediateAttempts; attempt++) {
      last = await _invokeOnce(type,
          to: to, toName: toName, firebaseUid: uid, data: data);
      if (last.success) return last;
      if (attempt < _maxImmediateAttempts - 1) {
        await Future.delayed(Duration(seconds: 2 * (1 << attempt))); // 2s, 4s
      }
    }
    // All immediate attempts failed (or we were offline the whole time) —
    // never lose the email; queue it for SyncEngine to retry later.
    await _enqueue(uid, type,
        to: to, toName: toName, data: data, lastError: last.error);
    return last.copyWith(queued: true);
  }

  Future<void> _enqueue(
    String uid,
    EmailType type, {
    String? to,
    String? toName,
    Map<String, dynamic>? data,
    String? lastError,
  }) async {
    final now = SqliteService.nowMs();
    final id =
        '${uid}_${now}_${DateTime.now().microsecondsSinceEpoch % 1000000}';
    try {
      await _sqlite.upsertEmailQueueItem({
        'id': id,
        'uid': uid,
        'emailType': type.wireValue,
        'payload': jsonEncode({'to': to, 'toName': toName, 'data': data ?? {}}),
        'recipient': to,
        'status': 'pending',
        'retryCount': 0,
        'nextAttemptAt': now + _queueBaseBackoffSeconds * 1000,
        'lastError': lastError,
        'createdAt': now,
        'updatedAt': now,
      });
    } catch (_) {
      // Even the local queue write failing must not throw back into the
      // caller's flow (registration/consultation submit) — the email is
      // simply lost in this worst-case scenario, same as any other
      // best-effort side-effect in this app.
    }
  }

  /// Retries every due queued email for [uid]. Called by
  /// SyncEngine.syncNow(), exactly like every other repository's
  /// resyncPending(). Never throws.
  Future<void> resyncPending(String uid) async {
    List<Map<String, dynamic>> due;
    try {
      due = await _sqlite.getDueEmailQueueItems(uid);
    } catch (_) {
      return;
    }
    for (final row in due) {
      final id = row['id'] as String;
      final typeWire = row['emailType'] as String? ?? '';
      Map<String, dynamic> payload;
      try {
        payload = (jsonDecode(row['payload'] as String) as Map)
            .cast<String, dynamic>();
      } catch (_) {
        await _sqlite.deleteEmailQueueItem(id);
        continue;
      }
      final type = EmailType.values.firstWhere(
        (t) => t.wireValue == typeWire,
        orElse: () => EmailType.test,
      );
      final dataMap = payload['data'];
      final result = await _invokeOnce(
        type,
        to: payload['to'] as String?,
        toName: payload['toName'] as String?,
        firebaseUid: uid,
        data: dataMap is Map ? dataMap.cast<String, dynamic>() : null,
      );
      if (result.success) {
        await _sqlite.deleteEmailQueueItem(id);
        continue;
      }
      final retryCount = (row['retryCount'] as int? ?? 0) + 1;
      try {
        if (retryCount >= _maxQueuedAttempts) {
          await _sqlite.updateEmailQueueItem(id,
              status: 'failed',
              retryCount: retryCount,
              lastError: result.error);
        } else {
          final backoffSeconds =
              _queueBaseBackoffSeconds * (1 << retryCount); // 60s, 120s
          await _sqlite.updateEmailQueueItem(
            id,
            status: 'pending',
            retryCount: retryCount,
            nextAttemptAt: SqliteService.nowMs() + backoffSeconds * 1000,
            lastError: result.error,
          );
        }
      } catch (_) {}
    }
  }
}
