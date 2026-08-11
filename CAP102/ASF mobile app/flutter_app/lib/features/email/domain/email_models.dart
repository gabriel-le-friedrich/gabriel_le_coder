// ══════════════════════════════════════════════════════════════════════
// ASF — Brevo email integration: shared domain types.
//
// The wire-level `type` strings below MUST stay in sync with the
// `EmailType` union in supabase/functions/send-email/index.ts — this is
// the contract between the Flutter app and the Edge Function.
// ══════════════════════════════════════════════════════════════════════

enum EmailType {
  welcome,
  passwordReset,
  consultationRequest,
  consultationConfirmation,
  adminNotification,
  test,
}

extension EmailTypeWire on EmailType {
  String get wireValue {
    switch (this) {
      case EmailType.welcome:
        return 'welcome';
      case EmailType.passwordReset:
        return 'password_reset';
      case EmailType.consultationRequest:
        return 'consultation_request';
      case EmailType.consultationConfirmation:
        return 'consultation_confirmation';
      case EmailType.adminNotification:
        return 'admin_notification';
      case EmailType.test:
        return 'test';
    }
  }
}

/// Result of a single send attempt (immediate call, not the eventual
/// outcome of a queued retry — see EmailRepository.resyncPending for that).
class EmailSendResult {
  const EmailSendResult({
    required this.success,
    this.error,
    this.responseCode,
    this.queued = false,
  });

  final bool success;
  final String? error;
  final int? responseCode;

  /// True when every immediate attempt failed and the email was instead
  /// saved to the local offline queue for the sync engine to retry later.
  /// The caller (e.g. the Testing screen) should present this as "queued,
  /// will retry" rather than a hard failure.
  final bool queued;

  EmailSendResult copyWith({bool? queued}) => EmailSendResult(
        success: success,
        error: error,
        responseCode: responseCode,
        queued: queued ?? this.queued,
      );
}
