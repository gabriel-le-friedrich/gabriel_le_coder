// ══════════════════════════════════════════════════════════════════════
// Shared defensive-parsing helpers for every repository that reads stored
// JSON out of SqliteService's aggregate tables (healthLogs, growthLogs,
// expenses, feedingLogs, settings) or per-row tables (pigs,
// weeklyPigImages). SqliteService.getAggregate() already guards the outer
// jsonDecode, but a caller's subsequent `as List` / `Model.fromJson(...)`
// cast is not protected by that — historically, a single corrupted or
// unexpectedly-shaped record anywhere in a stored list has been enough to
// throw out of an entire `.map(...)` call, failing every OTHER, perfectly
// valid record in the same read (this was the exact root cause of the
// Health Monitor "not loading" bug).
//
// These two helpers are the single place that resilience behavior lives
// now, so it can never again be implemented inconsistently between
// repositories, and so it's unit-testable without a device (they take
// already-decoded `dynamic` input, no SQLite involved).
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

/// Result of parsing a raw decoded-JSON list defensively: the entries that
/// parsed successfully, plus how many did not. Callers that don't care how
/// many were skipped can just take `.entries`; a debug-only "N invalid
/// records were ignored" UI notice (see the Health History screen) reads
/// `.skipped`.
class SafeParseListResult<T> {
  const SafeParseListResult({required this.entries, required this.skipped});
  final List<T> entries;
  final int skipped;
}

/// Parses [raw] (the already jsonDecode'd value from an aggregate row) as
/// a list of [T], parsing each element independently via [fromJson]. Any
/// element that fails to parse — wrong shape, missing required field,
/// corrupted write, or [raw] itself not being a List at all — is skipped
/// rather than allowed to fail the whole read. [repoName] is only used to
/// label debug-mode log lines (e.g. `'HealthRepository.getHealthLogs'`).
SafeParseListResult<T> parseJsonListSafely<T>(
  dynamic raw,
  T Function(Map<String, dynamic> json) fromJson, {
  required String repoName,
}) {
  if (raw == null || raw is! List)
    return SafeParseListResult<T>(entries: <T>[], skipped: 0);
  final entries = <T>[];
  var skipped = 0;
  for (var i = 0; i < raw.length; i++) {
    try {
      entries.add(fromJson(Map<String, dynamic>.from(raw[i] as Map)));
    } catch (e, st) {
      skipped++;
      if (kDebugMode) {
        debugPrint('$repoName: skipped corrupted record at index $i — $e');
        debugPrint('$st');
      }
    }
  }
  return SafeParseListResult<T>(entries: entries, skipped: skipped);
}

/// Parses [raw] (the already jsonDecode'd value from a settings-style
/// single-value aggregate row) as one [T] via [fromJson]. Returns null —
/// rather than throwing — if [raw] is null or fails to parse for any
/// reason, matching the "a corrupted single-value row is the same as no
/// value saved yet" pattern already used by HealthDraftRepository and
/// VetContactRepository.
/// Generic per-element defensive mapping — like `source.map(parse).toList()`
/// but skips (rather than throws on) any single element that fails, with
/// the same debug-mode index/exception/stack-trace logging as
/// [parseJsonListSafely]. Use this when the source isn't a raw
/// decoded-JSON list (e.g. real SQL rows that each carry their own
/// JSON-encoded `data` column, as in PigRepository.getPigs()).
SafeParseListResult<T> mapSafely<S, T>(
  Iterable<S> source,
  T Function(S element) parse, {
  required String repoName,
}) {
  final entries = <T>[];
  var skipped = 0;
  var i = 0;
  for (final element in source) {
    try {
      entries.add(parse(element));
    } catch (e, st) {
      skipped++;
      if (kDebugMode) {
        debugPrint('$repoName: skipped corrupted record at index $i — $e');
        debugPrint('$st');
      }
    }
    i++;
  }
  return SafeParseListResult<T>(entries: entries, skipped: skipped);
}

T? parseJsonObjectSafely<T>(
  dynamic raw,
  T Function(Map<String, dynamic> json) fromJson, {
  required String repoName,
}) {
  if (raw == null) return null;
  try {
    return fromJson(Map<String, dynamic>.from(raw as Map));
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('$repoName: skipped a corrupted record — $e');
      debugPrint('$st');
    }
    return null;
  }
}
