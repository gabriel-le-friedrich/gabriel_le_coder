// ══════════════════════════════════════════════════════════════════════
// Unit tests for the Health Monitor scoring engine — added during the
// stabilization pass to give `flutter test` something real to check, and
// to pin down (with runnable assertions, not just prose) that all four
// statuses are reachable, that named Emergency symptoms always force
// Critical, and that the count/score thresholds sit exactly where the
// decision-rule comments in health_calculations.dart say they do.
//
// Pure-Dart domain logic (no widgets involved), so these run fast and
// don't need a device/emulator.
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:asf_flutter/features/health/domain/health_calculations.dart';

void main() {
  group('computeHealthAssessment — status reachability', () {
    test('Healthy: all-normal selections plus healthy physical indicators', () {
      final a = computeHealthAssessment(
        behavior: 'normal',
        appetite: 'normal',
        physical: const ['pinkish', 'bright_eyes'],
        waste: 'normal',
      );
      expect(a.status, HealthStatus.healthy);
      expect(a.hasEmergencySymptom, isFalse);
      expect(a.riskCount, 0);
      expect(a.criticalCount, 0);
      expect(a.reasons, isNotEmpty);
    });

    test('Needs Monitoring: several tier-1 observations, nothing worse', () {
      final a = computeHealthAssessment(
        behavior: 'less_active',
        appetite: 'eating_less',
        physical: const ['watery_eyes'],
        waste: 'soft_stool',
      );
      expect(a.status, HealthStatus.monitor);
      expect(a.monitorCount, 4);
      expect(a.riskCount, 0);
      expect(a.criticalCount, 0);
      expect(a.severityScore, 4);
    });

    test('At Risk: two At-Risk-tier physical symptoms', () {
      final a = computeHealthAssessment(
        behavior: 'normal',
        appetite: 'normal',
        physical: const ['fever', 'wounds'],
        waste: 'normal',
      );
      expect(a.status, HealthStatus.risk);
      expect(a.riskCount, 2);
      expect(a.hasEmergencySymptom, isFalse);
    });

    test('At Risk: severity score alone crosses the At-Risk threshold', () {
      // 7 distinct tier-1 physical options + one tier-1 behavior = score 8,
      // which is exactly kAtRiskScoreThreshold.
      final a = computeHealthAssessment(
        behavior: 'less_active',
        appetite: 'normal',
        physical: const [
          'watery_eyes',
          'sneezing',
          'mild_nasal',
          'minor_bruises',
          'mild_lameness',
          'coughing',
          'labored_breathing'
        ],
        waste: 'normal',
      );
      expect(a.severityScore, kAtRiskScoreThreshold);
      expect(a.status, HealthStatus.risk);
    });

    test(
        'Needs Monitoring: severity score one below the At-Risk threshold stays Monitoring',
        () {
      // Same as above but without the extra tier-1 behavior — score 7, not 8.
      final a = computeHealthAssessment(
        behavior: 'normal',
        appetite: 'normal',
        physical: const [
          'watery_eyes',
          'sneezing',
          'mild_nasal',
          'minor_bruises',
          'mild_lameness',
          'coughing',
          'labored_breathing'
        ],
        waste: 'normal',
      );
      expect(a.severityScore, kAtRiskScoreThreshold - 1);
      expect(a.status, HealthStatus.monitor);
    });

    test(
        'Critical: a named Emergency symptom in Physical always wins, regardless of everything else',
        () {
      final a = computeHealthAssessment(
        behavior: 'normal',
        appetite: 'normal',
        physical: const ['collapse'],
        waste: 'normal',
      );
      expect(a.status, HealthStatus.critical);
      expect(a.hasEmergencySymptom, isTrue);
      expect(a.reasons.first, contains('Emergency'));
    });

    test('Critical: a named Emergency symptom in Behavior also always wins',
        () {
      final a = computeHealthAssessment(
        behavior: 'unable_stand',
        appetite: 'normal',
        physical: const [],
        waste: 'normal',
      );
      expect(a.status, HealthStatus.critical);
      expect(a.hasEmergencySymptom, isTrue);
    });

    test('Critical: two generic (non-Emergency) Critical-severity symptoms',
        () {
      // 'refusing' (Appetite) and 'bloody_diarrhea' (Waste) are tier 3 but
      // deliberately NOT in kEmergencySymptomKeys — this is the "2 or more
      // Critical-severity symptoms" count rule, distinct from the Emergency
      // whitelist short-circuit.
      final a = computeHealthAssessment(
        behavior: 'normal',
        appetite: 'refusing',
        physical: const [],
        waste: 'bloody_diarrhea',
      );
      expect(a.hasEmergencySymptom, isFalse);
      expect(a.criticalCount, 2);
      expect(a.status, HealthStatus.critical);
    });

    test(
        'Critical: one generic Critical-severity symptom plus two At-Risk symptoms',
        () {
      final a = computeHealthAssessment(
        behavior: 'normal',
        appetite: 'refusing',
        physical: const ['fever', 'wounds'],
        waste: 'normal',
      );
      expect(a.hasEmergencySymptom, isFalse);
      expect(a.criticalCount, 1);
      expect(a.riskCount, 2);
      expect(a.status, HealthStatus.critical);
    });

    test('Critical: total severity score alone crosses the Critical threshold',
        () {
      // All 6 distinct At-Risk-tier (weight 2) physical symptoms = 12,
      // plus two tier-1 selections = 14 — reaches the score threshold with
      // zero Critical-tier symptoms, so it's the score pathway specifically
      // (not the count-based Critical rules) being exercised here.
      final a = computeHealthAssessment(
        behavior: 'normal',
        appetite: 'eating_less',
        physical: const [
          'fever',
          'wounds',
          'limping',
          'swollen_joints',
          'severe_lameness',
          'severe_swelling'
        ],
        waste: 'soft_stool',
      );
      expect(a.criticalCount, 0);
      expect(a.severityScore, kCriticalScoreThreshold);
      expect(a.status, HealthStatus.critical);
      expect(a.reasons.first, contains('severity score'));
    });

    test(
        'A single At-Risk-tier symptom alone is not enough to reach At Risk (needs 2+, per the rule)',
        () {
      // Matches the documented rule exactly: At Risk requires 2+ At-Risk
      // symptoms (or a lone Critical-tier symptom, or a high score) — one
      // lone tier-2 symptom with everything else normal falls through to
      // the Monitoring catch-all instead.
      final a = computeHealthAssessment(
        behavior: 'normal',
        appetite: 'normal',
        physical: const ['fever'],
        waste: 'normal',
      );
      expect(a.riskCount, 1);
      expect(a.status, HealthStatus.monitor);
    });

    test(
        'A single Critical-tier (non-Emergency) symptom alone floors at least to At Risk',
        () {
      final a = computeHealthAssessment(
        behavior: 'normal',
        appetite: 'refusing',
        physical: const [],
        waste: 'normal',
      );
      expect(a.criticalCount, 1);
      expect(a.hasEmergencySymptom, isFalse);
      expect(a.status, HealthStatus.risk);
    });
  });

  group('kEmergencySymptomKeys sanity', () {
    test(
        'every emergency key resolves to a real, tier-3 option somewhere in the option lists',
        () {
      final allOptions = [
        ...kBehaviorOptions,
        ...kAppetiteOptions,
        ...kPhysicalOptions,
        ...kWasteOptions
      ];
      for (final key in kEmergencySymptomKeys) {
        final match = allOptions.where((o) => o.key == key).toList();
        expect(match, isNotEmpty,
            reason: 'Emergency key "$key" does not match any HealthOption');
        expect(match.first.tier, 3,
            reason: 'Emergency key "$key" should be tier 3');
      }
    });
  });

  group('computeHealthStatus (thin wrapper)', () {
    test('returns the same status as computeHealthAssessment', () {
      const args = (
        behavior: 'normal',
        appetite: 'normal',
        physical: <String>['collapse'],
        waste: 'normal'
      );
      final full = computeHealthAssessment(
          behavior: args.behavior,
          appetite: args.appetite,
          physical: args.physical,
          waste: args.waste);
      final quick = computeHealthStatus(
          behavior: args.behavior,
          appetite: args.appetite,
          physical: args.physical,
          waste: args.waste);
      expect(quick, full.status);
    });
  });

  group('computeDigestiveTip', () {
    test('fires when waste is loose and appetite is reduced', () {
      final tip = computeDigestiveTip(appetite: 'eating_less', waste: 'loose');
      expect(tip, isNotNull);
    });
    test('does not fire when appetite is normal', () {
      final tip = computeDigestiveTip(appetite: 'normal', waste: 'loose');
      expect(tip, isNull);
    });
  });

  group('HealthLogEntry JSON round-trip', () {
    test(
        'toJson/fromJson preserves every persisted field, including the severity counts',
        () {
      const entry = HealthLogEntry(
        id: 7,
        day: 15,
        date: '2026-07-20',
        time: '08:03',
        timestamp: '2026-07-20T08:03:00.000',
        behavior: 'less_active',
        appetite: 'normal',
        physical: ['watery_eyes', 'fever'],
        waste: 'normal',
        notes: 'Some notes',
        status: HealthStatus.risk,
        severityScore: 4,
        healthyCount: 2,
        monitorCount: 1,
        riskCount: 1,
        criticalCount: 0,
        batchName: 'Batch A',
        pigName: 'Pen 3',
        assessedBy: 'Juan',
      );
      final restored = HealthLogEntry.fromJson(entry.toJson());
      expect(restored.id, entry.id);
      expect(restored.day, entry.day);
      expect(restored.status, entry.status);
      expect(restored.severityScore, entry.severityScore);
      expect(restored.healthyCount, entry.healthyCount);
      expect(restored.monitorCount, entry.monitorCount);
      expect(restored.riskCount, entry.riskCount);
      expect(restored.criticalCount, entry.criticalCount);
      expect(restored.physical, entry.physical);
      expect(restored.batchName, entry.batchName);
      expect(restored.pigName, entry.pigName);
      expect(restored.assessedBy, entry.assessedBy);
    });

    test('fromJson tolerates a legacy single-string "physical" value', () {
      final json = {
        'id': 1,
        'day': 1,
        'date': '2026-01-01',
        'time': '08:00',
        'timestamp': '2026-01-01T08:00:00.000',
        'behavior': 'normal',
        'appetite': 'normal',
        'physical': 'pinkish',
        'waste': 'normal',
        'status': 'healthy',
      };
      final entry = HealthLogEntry.fromJson(json);
      expect(entry.physical, ['pinkish']);
    });

    test(
        'fromJson defaults missing severity-count fields to zero rather than throwing',
        () {
      final json = {
        'id': 1,
        'day': 1,
        'date': '2026-01-01',
        'time': '08:00',
        'timestamp': '2026-01-01T08:00:00.000',
        'behavior': 'normal',
        'appetite': 'normal',
        'physical': ['pinkish'],
        'waste': 'normal',
        'status': 'healthy',
      };
      final entry = HealthLogEntry.fromJson(json);
      expect(entry.healthyCount, 0);
      expect(entry.monitorCount, 0);
      expect(entry.riskCount, 0);
      expect(entry.criticalCount, 0);
      expect(entry.severityScore, 0);
    });
  });
}
