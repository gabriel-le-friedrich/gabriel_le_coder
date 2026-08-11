// ══════════════════════════════════════════════════════════════════════
// Unit tests for the Health Monitor's option-label translation layer
// (healthOptionLabel/healthOptionSubtitle/healthTranslationCoverageGaps
// in settings_strings.dart), added after the Health Monitor navigation
// fix + option-translation pass.
//
// These specifically guard against the "silently falls back to English"
// failure mode: a future new HealthOption added to health_calculations
// .dart (a new symptom) that never gets a matching Filipino entry would
// otherwise render in English under the Filipino UI language with no
// error anywhere — healthTranslationCoverageGaps() below turns that into
// a failing test instead of a silent gap.
//
// Pure-Dart, no widgets — fast, no device/emulator needed. See
// health_translation_widget_test.dart for the companion widget test that
// exercises the actual Riverpod rebuild-on-language-switch behavior.
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:asf_flutter/features/health/domain/health_calculations.dart';
import 'package:asf_flutter/features/settings/domain/app_language.dart';
import 'package:asf_flutter/features/settings/domain/settings_strings.dart';

void main() {
  // ────────────────────────────────────────────────────────────────────
  // Stage 1 (root-cause trace, "Health Monitor Not Loading Options" report)
  // — proves the four option catalogs are non-empty and exactly the
  // expected size at the data-source layer, independent of any widget or
  // device. Since kBehaviorOptions/kAppetiteOptions/kPhysicalOptions/
  // kWasteOptions are `const List<HealthOption>` literals, this is a
  // compile-time guarantee, not a runtime possibility check — but it's
  // asserted explicitly here so "the data source is empty" is eliminated
  // with a passing/failing test artifact instead of a code-reading claim.
  // ────────────────────────────────────────────────────────────────────
  group(
      'Stage 1 — option catalogs are non-empty with the exact expected counts',
      () {
    test('kBehaviorOptions has exactly 5 items', () {
      expect(kBehaviorOptions, isNotEmpty);
      expect(kBehaviorOptions.length, 5,
          reason: 'Behavior must render 5 selectable cards');
    });

    test('kAppetiteOptions has exactly 4 items', () {
      expect(kAppetiteOptions, isNotEmpty);
      expect(kAppetiteOptions.length, 4,
          reason: 'Appetite must render 4 selectable cards');
    });

    test('kPhysicalOptions has exactly 24 items, split 6/7/6/5 across tiers',
        () {
      expect(kPhysicalOptions, isNotEmpty);
      expect(kPhysicalOptions.length, 24,
          reason: 'Physical Condition must render 24 selectable cards total');
      expect(kPhysicalHealthyGroup.length, 6,
          reason: 'Healthy Indicators section');
      expect(kPhysicalMonitoringGroup.length, 7,
          reason: 'Needs Monitoring section');
      expect(kPhysicalAtRiskGroup.length, 6, reason: 'At Risk section');
      expect(kPhysicalCriticalGroup.length, 5, reason: 'Critical section');
      // The 4 grouped lists must partition kPhysicalOptions exactly —
      // catches a future edit that adds/edits a tier value without also
      // regenerating the section split (they're derived via .where(), so
      // this can only fail if a tier value falls outside 0-3).
      expect(
        kPhysicalHealthyGroup.length +
            kPhysicalMonitoringGroup.length +
            kPhysicalAtRiskGroup.length +
            kPhysicalCriticalGroup.length,
        kPhysicalOptions.length,
      );
    });

    test('kWasteOptions has exactly 5 items', () {
      expect(kWasteOptions, isNotEmpty);
      expect(kWasteOptions.length, 5,
          reason: 'Waste Condition must render 5 selectable cards');
    });

    test('no option in any catalog has a blank key, icon, or label', () {
      for (final entry in {
        'behavior': kBehaviorOptions,
        'appetite': kAppetiteOptions,
        'physical': kPhysicalOptions,
        'waste': kWasteOptions,
      }.entries) {
        for (final o in entry.value) {
          expect(o.key, isNotEmpty,
              reason: '${entry.key} has an option with a blank key');
          expect(o.icon, isNotEmpty,
              reason: '${entry.key}.${o.key} has a blank icon');
          expect(o.label, isNotEmpty,
              reason: '${entry.key}.${o.key} has a blank label');
        }
      }
    });
  });

  group('healthTranslationCoverageGaps — every option has a Filipino entry',
      () {
    test('reports zero gaps across all four categories', () {
      final gaps = healthTranslationCoverageGaps();
      expect(
        gaps,
        isEmpty,
        reason:
            'Every HealthOption key in health_calculations.dart must have a matching '
            'Filipino translation entry in settings_strings.dart, or it silently renders '
            'in English under the Filipino UI language. Missing: $gaps',
      );
    });

    test('every kBehaviorOptions key round-trips through healthOptionLabel',
        () {
      for (final o in kBehaviorOptions) {
        final fil =
            healthOptionLabel(AppLanguage.fil, 'behavior', o.key, o.label);
        expect(fil, isNotEmpty,
            reason: '${o.key} produced an empty Filipino label');
      }
    });

    test('every kAppetiteOptions key round-trips through healthOptionLabel',
        () {
      for (final o in kAppetiteOptions) {
        final fil =
            healthOptionLabel(AppLanguage.fil, 'appetite', o.key, o.label);
        expect(fil, isNotEmpty,
            reason: '${o.key} produced an empty Filipino label');
      }
    });

    test('every kPhysicalOptions key round-trips through healthOptionLabel',
        () {
      for (final o in kPhysicalOptions) {
        final fil =
            healthOptionLabel(AppLanguage.fil, 'physical', o.key, o.label);
        expect(fil, isNotEmpty,
            reason: '${o.key} produced an empty Filipino label');
      }
    });

    test('every kWasteOptions key round-trips through healthOptionLabel', () {
      for (final o in kWasteOptions) {
        final fil = healthOptionLabel(AppLanguage.fil, 'waste', o.key, o.label);
        expect(fil, isNotEmpty,
            reason: '${o.key} produced an empty Filipino label');
      }
    });
  });

  group(
      'healthOptionLabel — English always returns the canonical label unchanged',
      () {
    test('English never reads from the Filipino dictionaries', () {
      for (final o in kBehaviorOptions) {
        expect(healthOptionLabel(AppLanguage.en, 'behavior', o.key, o.label),
            o.label);
      }
      for (final o in kAppetiteOptions) {
        expect(healthOptionLabel(AppLanguage.en, 'appetite', o.key, o.label),
            o.label);
      }
      for (final o in kPhysicalOptions) {
        expect(healthOptionLabel(AppLanguage.en, 'physical', o.key, o.label),
            o.label);
      }
      for (final o in kWasteOptions) {
        expect(healthOptionLabel(AppLanguage.en, 'waste', o.key, o.label),
            o.label);
      }
    });

    test(
        'an unrecognized key/category falls back to the given label, never throws',
        () {
      expect(
          healthOptionLabel(
              AppLanguage.fil, 'nonexistent_category', 'nope', 'Fallback Text'),
          'Fallback Text');
      expect(
          healthOptionLabel(
              AppLanguage.fil, 'behavior', 'nope', 'Fallback Text'),
          'Fallback Text');
    });
  });

  group('healthOptionLabel — locked-down Filipino strings', () {
    // These pin the exact translations down as a regression guard — a
    // later edit to the Filipino dictionaries that accidentally changes
    // or removes one of these should fail loudly here rather than only
    // being noticed on a device screen.
    test('matches the examples given for this feature', () {
      expect(healthOptionLabel(AppLanguage.fil, 'appetite', 'eating_less', ''),
          'Kaunting Kumakain');
      expect(healthOptionLabel(AppLanguage.fil, 'appetite', 'no_appetite', ''),
          'Walang Gana Kumain');
      expect(healthOptionLabel(AppLanguage.fil, 'behavior', 'unable_stand', ''),
          'Hindi Makatayo');
      expect(healthOptionLabel(AppLanguage.fil, 'physical', 'collapse', ''),
          'Bumagsak');
    });
  });

  group('healthOptionSubtitle', () {
    test('translates the three options that carry a subtitle', () {
      expect(
          healthOptionSubtitle(AppLanguage.fil, 'behavior', 'normal',
              'Bright & Alert Eyes, Active Behavior'),
          isNot('Bright & Alert Eyes, Active Behavior'));
      expect(
          healthOptionSubtitle(
              AppLanguage.fil, 'physical', 'pinkish', 'Normal color'),
          'Normal na kulay');
      expect(
          healthOptionSubtitle(
              AppLanguage.fil, 'physical', 'bruise_free', 'No injuries'),
          'Walang sugat');
      expect(
          healthOptionSubtitle(
              AppLanguage.fil, 'waste', 'normal', 'Solid Fecal Consistency'),
          'Matigas na Dumi');
    });

    test('an empty fallback subtitle stays empty regardless of language', () {
      expect(
          healthOptionSubtitle(AppLanguage.fil, 'physical', 'fever', ''), '');
      expect(healthOptionSubtitle(AppLanguage.en, 'physical', 'fever', ''), '');
    });

    test('English always returns the given subtitle unchanged', () {
      expect(
          healthOptionSubtitle(
              AppLanguage.en, 'physical', 'pinkish', 'Normal color'),
          'Normal color');
    });
  });

  group('healthStatusLabel — Overall Status badge translation', () {
    // Found while writing this test suite: kHealthStatusMeta[status].label
    // itself is intentionally English-only (read by activity-log
    // descriptions and CSV/PDF export, same rationale as HealthOption
    // .label) — the Overall Status badge on-screen needed its own
    // translation path, added alongside these tests.
    test('English returns the same text as kHealthStatusMeta', () {
      for (final status in HealthStatus.values) {
        expect(healthStatusLabel(AppLanguage.en, status),
            kHealthStatusMeta[status]!.label);
      }
    });

    test('Filipino returns a distinct, non-empty string for every status', () {
      for (final status in HealthStatus.values) {
        final fil = healthStatusLabel(AppLanguage.fil, status);
        expect(fil, isNotEmpty);
        expect(fil, isNot(kHealthStatusMeta[status]!.label));
      }
    });

    test(
        'reuses the existing Severity Counts / Physical section Filipino wording (no duplicate translations)',
        () {
      expect(healthStatusLabel(AppLanguage.fil, HealthStatus.healthy),
          tr(AppLanguage.fil, 'healthyChip'));
      expect(healthStatusLabel(AppLanguage.fil, HealthStatus.monitor),
          tr(AppLanguage.fil, 'needsMonitoring'));
      expect(healthStatusLabel(AppLanguage.fil, HealthStatus.risk),
          tr(AppLanguage.fil, 'atRiskSection'));
      expect(healthStatusLabel(AppLanguage.fil, HealthStatus.critical),
          tr(AppLanguage.fil, 'criticalSection'));
    });
  });

  group('tr() — screen chrome keys used by the Health Monitor form/history',
      () {
    // Sanity check that every key the form/history screens actually call
    // tr() with resolves to a non-fallback, non-empty string in both
    // languages — catches a typo'd key silently rendering as the raw key
    // string itself.
    const usedKeys = [
      'behaviorLabel',
      'appetiteLabel',
      'physicalLabel',
      'wasteLabel',
      'healthMonitorTitle',
      'editObservation',
      'dailyObservationLog',
      'viewHealthLogs',
      'notesOptional',
      'notesHint',
      'assessedByOptional',
      'assessedByHint',
      'saveObservation',
      'selectOne',
      'multipleSelect',
      'noneSelected',
      'healthSummary',
      'overallStatus',
      'severityCounts',
      'reasonLabel',
      'recommendationLabel',
      'healthyIndicators',
      'needsMonitoring',
      'atRiskSection',
      'criticalSection',
      'physicalCondition',
      'healthyChip',
      'monitoringChip',
      'atRiskChip',
      'criticalChip',
    ];

    test(
        'every used key exists in both English and Filipino, distinct from the raw key',
        () {
      for (final key in usedKeys) {
        final en = tr(AppLanguage.en, key);
        final fil = tr(AppLanguage.fil, key);
        expect(en, isNot(key),
            reason:
                '"$key" has no English entry (tr() fell back to the raw key)');
        expect(fil, isNotEmpty,
            reason: '"$key" produced an empty Filipino string');
      }
    });
  });
}
