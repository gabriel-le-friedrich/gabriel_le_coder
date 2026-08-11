// ══════════════════════════════════════════════════════════════════════
// Automated substitute for a physical small/medium/large phone sweep on
// the Dashboard. There's no device/emulator available in this environment,
// so this pumps the ACTUAL production Dashboard card widgets (not a
// simplified stand-in) at three real phone viewport widths and asserts
// zero exceptions — in `flutter test`, a RenderFlex/RenderBox overflow
// (the classic "yellow/black stripes" the user reported) surfaces as a
// FlutterError that TestWidgetsFlutterBinding fails the test on, so this
// genuinely catches the overflow class of bug the user asked about rather
// than just asserting the widgets build.
//
// Scope: this covers the Dashboard's presentational cards that are plain
// StatelessWidgets taking DashboardData/lang (GreetingHeader,
// HealthBannerCard, SummaryCardGrid, WeightProgressCard, TodayTasksCard,
// TipOfDayCard) — every card on the real Dashboard except the two that are
// ConsumerWidgets reaching notificationPrefsProvider/dashboardControllerProvider
// (_UpcomingRemindersCard, and DashboardScreen itself), which need Firebase/
// Supabase/SQLite-backed providers that aren't available inside `flutter
// test` (see health_translation_widget_test.dart's scope note for the same
// limitation). A full on-device pass remains the final check before release.
//
// Data fixtures deliberately stress layout: long task subtitles, a health
// log with every physical-condition option selected (longest possible
// summary text), an ROI/ADG/FCR combination that renders every stat tile,
// and a populated weight history so the "not recorded this week" banner,
// badges, and delta caption all render at once.
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asf_flutter/features/dashboard/domain/dashboard_calculations.dart';
import 'package:asf_flutter/features/dashboard/domain/pig_batch_profile.dart';
import 'package:asf_flutter/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:asf_flutter/features/dashboard/presentation/widgets/greeting_header.dart';
import 'package:asf_flutter/features/dashboard/presentation/widgets/health_banner_card.dart';
import 'package:asf_flutter/features/dashboard/presentation/widgets/summary_card_grid.dart';
import 'package:asf_flutter/features/dashboard/presentation/widgets/today_tasks_card.dart';
import 'package:asf_flutter/features/dashboard/presentation/widgets/tip_of_day_card.dart';
import 'package:asf_flutter/features/dashboard/presentation/widgets/weight_progress_card.dart';
import 'package:asf_flutter/features/health/domain/health_calculations.dart';
import 'package:asf_flutter/features/settings/domain/app_language.dart';

/// Real phone viewport widths (logical pixels) representing small/medium/
/// large phones — not tablets. Height is generous (this Dashboard scrolls
/// vertically in a ListView, so height doesn't drive overflow; width does,
/// via every Row without Expanded/Flexible).
const _screenSizes = {
  'small (320×568 — e.g. iPhone SE / small Android)': Size(320, 568),
  'medium (390×844 — e.g. iPhone 14 / mid Android)': Size(390, 844),
  'large (428×926 — e.g. iPhone 14 Pro Max)': Size(428, 926),
};

DashboardData _stressFixture() {
  return DashboardData(
    currentDay: 26,
    tasksToday: const {'1': true, '2': true, '3': true, '4': false, '5': false},
    weightLogs: const [
      WeightLogEntry(
          day: 1, weight: 1.2, date: '2026-07-01', isOfficial: false),
      WeightLogEntry(day: 8, weight: 3.1, date: '2026-07-08', isOfficial: true),
      WeightLogEntry(
          day: 15, weight: 6.4, date: '2026-07-15', isOfficial: true),
      WeightLogEntry(
          day: 22, weight: 9.8, date: '2026-07-22', isOfficial: true),
    ],
    expenses: const [
      ExpenseEntry(
          id: 1,
          category: 'Feed',
          description: 'Starter feed 25kg sack, premium brand',
          amount: 1250.75,
          date: '2026-07-10'),
      ExpenseEntry(
          id: 2,
          category: 'Medicine',
          description: 'Vitamin B-complex + electrolyte supplement',
          amount: 480.00,
          date: '2026-07-18'),
    ],
    feedLogs: const [
      FeedLogEntry(day: 25, date: '2026-07-25', feedKg: 4.2),
      FeedLogEntry(day: 26, date: '2026-07-26', feedKg: 4.3),
    ],
    batchProfile: const PigBatchProfile(
      pigName: 'Batch A — Landrace-Duroc Crossbreed Finisher Group',
      batchName: 'Batch A',
      numPigs: 12,
      startWeight: 1.2,
      startDate: '2026-07-01',
      feedPrice: 55.0,
    ),
    healthLogs: [
      HealthLogEntry(
        id: 1,
        day: 26,
        date: 'July 26, 2026',
        time: '8:15 AM',
        timestamp: DateTime(2026, 7, 26, 8, 15).toIso8601String(),
        behavior: 'lethargic',
        appetite: 'no_appetite',
        // Every physical-condition option at once — the longest possible
        // summary text HealthBannerCard/_TodaysHealthCard would ever render.
        physical: const [
          'coughing',
          'nasal_discharge',
          'skin_lesions',
          'lameness',
          'swelling',
          'diarrhea'
        ],
        waste: 'watery_diarrhea',
        notes:
            'Two pigs in the far pen showing reduced appetite and mild coughing since this morning; monitoring closely and separated from the rest of the group as a precaution.',
        status: HealthStatus.critical,
        severityScore: 18,
        healthyCount: 0,
        monitorCount: 1,
        riskCount: 2,
        criticalCount: 3,
        batchName: 'Batch A',
        pigName: 'Batch A — Landrace-Duroc Crossbreed Finisher Group',
        assessedBy: 'Juan Dela Cruz',
      ),
    ],
    pigCount: 12,
  );
}

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final data = _stressFixture();

  for (final entry in _screenSizes.entries) {
    group(entry.key, () {
      testWidgets('GreetingHeader renders with no overflow', (tester) async {
        await _pumpAt(
          tester,
          entry.value,
          GreetingHeader(
              firstName: 'Bartolome',
              data: data,
              onAdvance: () async => true,
              lang: AppLanguage.en),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'HealthBannerCard (critical, all-physical-options) renders with no overflow',
          (tester) async {
        await _pumpAt(tester, entry.value,
            HealthBannerCard(data: data, lang: AppLanguage.en));
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'SummaryCardGrid (2x2 hero + FCR/Growth row) renders with no overflow',
          (tester) async {
        await _pumpAt(tester, entry.value,
            SummaryCardGrid(data: data, lang: AppLanguage.en));
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'SummaryCardGrid renders with no overflow in Filipino (longer labels)',
          (tester) async {
        await _pumpAt(tester, entry.value,
            SummaryCardGrid(data: data, lang: AppLanguage.fil));
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'WeightProgressCard (with "not recorded this week" banner) renders with no overflow',
          (tester) async {
        await _pumpAt(
          tester,
          entry.value,
          WeightProgressCard(
            weightLogs: data.weightLogs,
            startWeight: data.batchProfile?.startWeight,
            currentWeight: data.currentWeight,
            hasPigs: data.hasPigs,
            currentDay: data.currentDay,
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'TodayTasksCard (long subtitles, completed+pending split) renders with no overflow',
          (tester) async {
        await _pumpAt(tester, entry.value,
            TodayTasksCard(data: data, lang: AppLanguage.en));
        expect(tester.takeException(), isNull);
      });

      testWidgets('TipOfDayCard renders with no overflow', (tester) async {
        await _pumpAt(
            tester, entry.value, const TipOfDayCard(lang: AppLanguage.en));
        expect(tester.takeException(), isNull);
      });
    });
  }

  group(
      'empty/edge-case data — smallest screen only (most overflow-prone combination)',
      () {
    const size = Size(320, 568);
    const empty = DashboardData.empty;

    testWidgets(
        'GreetingHeader with null firstName ("Farmer" fallback) renders with no overflow',
        (tester) async {
      await _pumpAt(
          tester,
          size,
          GreetingHeader(
              firstName: null,
              data: empty,
              onAdvance: () async => true,
              lang: AppLanguage.en));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'HealthBannerCard with zero health logs (prompt state) renders with no overflow',
        (tester) async {
      await _pumpAt(tester, size,
          const HealthBannerCard(data: empty, lang: AppLanguage.en));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'SummaryCardGrid with zero pigs ("--" empty state) renders with no overflow',
        (tester) async {
      await _pumpAt(tester, size,
          const SummaryCardGrid(data: empty, lang: AppLanguage.en));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'WeightProgressCard with zero pigs/weigh-ins renders with no overflow',
        (tester) async {
      await _pumpAt(
        tester,
        size,
        WeightProgressCard(
          weightLogs: empty.weightLogs,
          startWeight: empty.batchProfile?.startWeight,
          currentWeight: empty.currentWeight,
          hasPigs: empty.hasPigs,
          currentDay: empty.currentDay,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('TodayTasksCard with zero tasks done renders with no overflow',
        (tester) async {
      await _pumpAt(tester, size,
          const TodayTasksCard(data: empty, lang: AppLanguage.en));
      expect(tester.takeException(), isNull);
    });
  });
}
