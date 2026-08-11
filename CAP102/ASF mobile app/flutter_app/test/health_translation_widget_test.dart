// ══════════════════════════════════════════════════════════════════════
// Widget test proving the actual Riverpod rebuild path: when
// appLanguageProvider changes, every widget that watches it and calls
// tr()/healthOptionLabel() re-renders with the new language IN PLACE —
// no screen restart, no re-pump from scratch, no navigation round trip.
//
// Scope note: this deliberately does NOT pump the real HealthFormScreen.
// That screen's providers (authRepositoryProvider.currentUser,
// healthRepositoryProvider, healthFormControllerProvider, the duplicate/
// draft guards) reach real FirebaseAuth/SqliteService/Supabase clients,
// none of which are available inside `flutter test` (no platform
// channels, no mocking library in this project's dev_dependencies —
// see pubspec.yaml). Building fakes for all of that is a real, separate
// investment or a repository DI change, not something to bolt on
// silently inside a translation-focused test.
//
// What this test verifies instead is the actual mechanism the checklist
// item is really asking about: watching appLanguageProvider + calling
// the SAME production functions (tr, healthOptionLabel, healthOptionSubtitle)
// that health_form_screen.dart and health_history_screen.dart call,
// inside a real widget tree, and confirming a language flip re-renders
// them without any pumpWidget() call in between — i.e. the exact
// "changes ... without rebuilding the screen [from scratch]" behavior.
// A full on-device pass of the actual HealthFormScreen is still the
// right final check before release (see the Manual Device Validation
// item in the verification report).
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asf_flutter/features/health/domain/health_calculations.dart';
import 'package:asf_flutter/features/settings/domain/app_language.dart';
import 'package:asf_flutter/features/settings/domain/settings_strings.dart';
import 'package:asf_flutter/features/settings/presentation/providers/settings_providers.dart';

/// Minimal stand-in for the Health Monitor form's option-label rendering
/// — watches appLanguageProvider (exactly like HealthFormScreen.build()
/// does) and renders every category's chrome label plus every option's
/// translated label through the real production helpers, with distinct
/// Keys so the test can look each one up individually.
class _HealthLabelsHarness extends ConsumerWidget {
  const _HealthLabelsHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Text(tr(lang, 'behaviorLabel'),
                key: const Key('chrome.behaviorLabel')),
            Text(tr(lang, 'appetiteLabel'),
                key: const Key('chrome.appetiteLabel')),
            Text(tr(lang, 'physicalCondition'),
                key: const Key('chrome.physicalCondition')),
            Text(tr(lang, 'wasteLabel'), key: const Key('chrome.wasteLabel')),
            Text(tr(lang, 'notesOptional'),
                key: const Key('chrome.notesOptional')),
            Text(tr(lang, 'saveObservation'),
                key: const Key('chrome.saveObservation')),
            for (final o in kAppetiteOptions)
              Text(
                healthOptionLabel(lang, 'appetite', o.key, o.label),
                key: Key('option.appetite.${o.key}'),
              ),
            for (final s in kHealthStatusMeta.entries)
              Text('${s.value.emoji} ${healthStatusLabel(lang, s.key)}',
                  key: Key('status.${s.key.name}')),
            ElevatedButton(
              key: const Key('toggleLangBtn'),
              onPressed: () {
                final notifier = ref.read(appLanguageProvider.notifier);
                notifier.state = notifier.state == AppLanguage.en
                    ? AppLanguage.fil
                    : AppLanguage.en;
              },
              child: const Text('toggle'),
            ),
          ],
        ),
      ),
    );
  }
}

String _textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  testWidgets(
      'switching appLanguageProvider re-renders every label in place, no restart',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: _HealthLabelsHarness()));
    await tester.pumpAndSettle();

    // ── Starts English ──
    expect(_textOf(tester, 'chrome.behaviorLabel'),
        tr(AppLanguage.en, 'behaviorLabel'));
    expect(_textOf(tester, 'chrome.appetiteLabel'),
        tr(AppLanguage.en, 'appetiteLabel'));
    expect(_textOf(tester, 'chrome.physicalCondition'),
        tr(AppLanguage.en, 'physicalCondition'));
    expect(
        _textOf(tester, 'chrome.wasteLabel'), tr(AppLanguage.en, 'wasteLabel'));
    expect(_textOf(tester, 'chrome.notesOptional'),
        tr(AppLanguage.en, 'notesOptional'));
    expect(_textOf(tester, 'chrome.saveObservation'),
        tr(AppLanguage.en, 'saveObservation'));
    for (final o in kAppetiteOptions) {
      expect(_textOf(tester, 'option.appetite.${o.key}'), o.label);
    }
    expect(_textOf(tester, 'status.healthy'), contains('Healthy'));

    // ── Tap the toggle (same as the app's EN|FIL switch) — this is the
    // ONLY interaction between the two assertion blocks: no pumpWidget()
    // call, no screen rebuild from scratch, just a state change + one
    // pump to let the rebuild happen. ──
    await tester.tap(find.byKey(const Key('toggleLangBtn')));
    await tester.pump();

    // ── Now Filipino, same widget tree, same instances ──
    expect(_textOf(tester, 'chrome.behaviorLabel'),
        tr(AppLanguage.fil, 'behaviorLabel'));
    expect(_textOf(tester, 'chrome.appetiteLabel'),
        tr(AppLanguage.fil, 'appetiteLabel'));
    expect(_textOf(tester, 'chrome.physicalCondition'),
        tr(AppLanguage.fil, 'physicalCondition'));
    expect(_textOf(tester, 'chrome.wasteLabel'),
        tr(AppLanguage.fil, 'wasteLabel'));
    expect(_textOf(tester, 'chrome.notesOptional'),
        tr(AppLanguage.fil, 'notesOptional'));
    expect(_textOf(tester, 'chrome.saveObservation'),
        tr(AppLanguage.fil, 'saveObservation'));

    // Every appetite option specifically called out in the checklist.
    expect(_textOf(tester, 'option.appetite.normal'),
        healthOptionLabel(AppLanguage.fil, 'appetite', 'normal', ''));
    expect(_textOf(tester, 'option.appetite.eating_less'), 'Kaunting Kumakain');
    expect(
        _textOf(tester, 'option.appetite.no_appetite'), 'Walang Gana Kumain');
    expect(_textOf(tester, 'option.appetite.refusing'),
        healthOptionLabel(AppLanguage.fil, 'appetite', 'refusing', ''));

    // Status labels also switch (Healthy/Needs Monitoring/At Risk/Critical).
    expect(_textOf(tester, 'status.healthy'), isNot(contains('Healthy')));

    // ── Toggle back to English to confirm it round-trips both ways, not
    // just a one-shot flip. ──
    await tester.tap(find.byKey(const Key('toggleLangBtn')));
    await tester.pump();
    expect(_textOf(tester, 'chrome.behaviorLabel'),
        tr(AppLanguage.en, 'behaviorLabel'));
    expect(_textOf(tester, 'option.appetite.eating_less'), 'Eating Less');
  });
}
