// ══════════════════════════════════════════════════════════════════════
// Philippine mobile number validation/normalization — the single source
// of truth for turning whatever a user typed into either a strict E.164
// string Firebase's verifyPhoneNumber() will accept, or a clear rejection.
//
// Philippine mobile numbers are always: leading "0", then a "9", then 9
// more digits — 11 digits total in local format (e.g. 09171234567).
// Stripping the leading 0 and prefixing +63 gives the E.164 form Firebase
// requires: +639171234567 (13 characters, "+63" + 10 digits starting
// with 9).
//
// This replaces the old formatPhoneE164()/isValidPhoneE164() pair, which
// accepted anything matching a generic `^\+[1-9]\d{7,14}$` pattern — that
// was never actually Philippines-specific (it would happily accept, say,
// a US number typed in E.164 form) and didn't reject the specific bad
// inputs the audit asked for (letters, wrong length, invalid prefix).
// ══════════════════════════════════════════════════════════════════════

final RegExp _digitsOnly = RegExp(r'^[0-9]+$');
final RegExp _separators = RegExp(r'[\s\-()]');

/// Normalizes [raw] to strict E.164 (`+639XXXXXXXXX`) if — and only if —
/// it's a valid Philippine mobile number in one of these input shapes:
///   - Local format:      09XXXXXXXXX   (11 digits, starts with "09")
///   - Country-code form: 639XXXXXXXXX  (12 digits, starts with "63")
///   - Already E.164:     +639XXXXXXXXX (starts with "+63")
/// Internal spaces, dashes, and parentheses are stripped before checking.
/// Returns null for anything else — letters, symbols other than the
/// separators above, wrong digit count, or a prefix that isn't a real PH
/// mobile prefix (every PH mobile number has "9" as the digit right after
/// the leading 0 / country code, e.g. 0917, 0920, 0995 — a landline or
/// malformed number won't match this and is correctly rejected).
String? normalizePhilippineMobile(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final stripped = trimmed.replaceAll(_separators, '');
  final hasPlus = stripped.startsWith('+');
  final digits = hasPlus ? stripped.substring(1) : stripped;

  // Reject letters or any other non-digit character outright (e.g. "09-CALL-NOW").
  if (digits.isEmpty || !_digitsOnly.hasMatch(digits)) return null;

  String subscriberNumber; // the 10-digit "9XXXXXXXXX" portion
  if (digits.length == 12 && digits.startsWith('63')) {
    subscriberNumber = digits.substring(2);
  } else if (!hasPlus && digits.length == 11 && digits.startsWith('0')) {
    subscriberNumber = digits.substring(1);
  } else {
    // Covers: too short, too long, "+" present but not a 63-country-code
    // 12-digit number, or a bare number that isn't 11 digits starting
    // with 0 — all rejected rather than guessed at.
    return null;
  }

  if (subscriberNumber.length != 10 || !subscriberNumber.startsWith('9')) {
    return null; // invalid prefix (not a real PH mobile number)
  }
  return '+63$subscriberNumber';
}

/// True if [raw] is a valid Philippine mobile number in any of the
/// accepted input shapes (see [normalizePhilippineMobile]).
bool isValidPhilippineMobile(String raw) =>
    normalizePhilippineMobile(raw) != null;

/// Formats an already-E.164 Philippine number for display, e.g.
/// "+639171234567" -> "0917 123 4567". Falls back to the raw E.164 string
/// if it isn't a recognizable PH number (defensive — should never happen
/// for a number that passed [normalizePhilippineMobile]).
String displayPhilippineMobile(String e164) {
  if (!e164.startsWith('+63') || e164.length != 13) return e164;
  final local = '0${e164.substring(3)}'; // 0 + 9XXXXXXXXX
  return '${local.substring(0, 4)} ${local.substring(4, 7)} ${local.substring(7)}';
}

// ── Backward-compatible aliases (old call sites, if any remain) ──
// Deprecated in favor of normalizePhilippineMobile()/isValidPhilippineMobile()
// above, which are strict to PH mobile numbers specifically. Kept only so
// nothing outside this feature breaks if it still imports the old names.
@Deprecated(
    'Use normalizePhilippineMobile() instead — this no longer does generic E.164 formatting.')
String formatPhoneE164(String raw) => normalizePhilippineMobile(raw) ?? raw;

@Deprecated(
    'Use isValidPhilippineMobile() instead — this now validates PH mobile numbers specifically.')
bool isValidPhoneE164(String e164) => isValidPhilippineMobile(e164);
