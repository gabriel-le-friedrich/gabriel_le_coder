// ══════════════════════════════════════════════════════════════════════
// Unit tests for the Notifications module's translation layer
// (reminderTitle/reminderDescription/reminderTranslationCoverageGaps in
// settings_strings.dart), added to close the "Notifications module has
// zero tr() calls" gap found during the production-readiness audit.
//
// Mirrors test/health_translation_test.dart's structure and intent: guards
// against a future new ReminderTypeDef (a new reminder type added to
// reminder_types.dart) silently rendering in English under the Filipino
// UI language with no error anywhere.
//
// Pure-Dart, no widgets — fast, no device/emulator needed.
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:asf_flutter/features/notifications/domain/reminder_types.dart';
import 'package:asf_flutter/features/settings/domain/app_language.dart';
import 'package:asf_flutter/features/settings/domain/settings_strings.dart';

void main() {
  group('kReminderTypes — data-source sanity', () {
    test(
        'has exactly 9 reminder types, each with a non-empty key/title/description',
        () {
      expect(kReminderTypes.length, 9);
      for (final def in kReminderTypes) {
        expect(def.key, isNotEmpty);
        expect(def.title, isNotEmpty);
        expect(def.description, isNotEmpty);
      }
    });

    test('every key is unique (never reused across types)', () {
      final keys = kReminderTypes.map((d) => d.key).toList();
      expect(keys.toSet().length, keys.length,
          reason: 'Duplicate reminder key would collide in prefs storage');
    });
  });

  group(
      'reminderTranslationCoverageGaps — every reminder type has a Filipino entry',
      () {
    test('reports zero gaps across title and description', () {
      final gaps = reminderTranslationCoverageGaps();
      expect(
        gaps,
        isEmpty,
        reason:
            'Every ReminderTypeDef.key in reminder_types.dart must have a matching '
            'Filipino title/description entry in settings_strings.dart, or it silently renders '
            'in English under the Filipino UI language. Missing: $gaps',
      );
    });

    test(
        'every reminder type round-trips through reminderTitle/reminderDescription',
        () {
      for (final def in kReminderTypes) {
        final filTitle = reminderTitle(AppLanguage.fil, def.key, def.title);
        final filDesc =
            reminderDescription(AppLanguage.fil, def.key, def.description);
        expect(filTitle, isNotEmpty,
            reason: '${def.key} produced an empty Filipino title');
        expect(filDesc, isNotEmpty,
            reason: '${def.key} produced an empty Filipino description');
      }
    });
  });

  group(
      'reminderTitle/reminderDescription — English always returns the canonical fallback unchanged',
      () {
    test('English never reads from the Filipino dictionaries', () {
      for (final def in kReminderTypes) {
        expect(reminderTitle(AppLanguage.en, def.key, def.title), def.title);
        expect(reminderDescription(AppLanguage.en, def.key, def.description),
            def.description);
      }
    });

    test('an unrecognized key falls back to the given text, never throws', () {
      expect(reminderTitle(AppLanguage.fil, 'nonexistent', 'Fallback Title'),
          'Fallback Title');
      expect(
          reminderDescription(
              AppLanguage.fil, 'nonexistent', 'Fallback Description'),
          'Fallback Description');
    });
  });

  group('tr() — screen chrome keys used by notification_settings_screen.dart',
      () {
    // Sanity check that every key the Notification Settings screen actually
    // calls tr() with resolves to a non-fallback, non-empty string in both
    // languages — catches a typo'd key silently rendering as the raw key
    // string itself.
    const usedKeys = [
      'notifications',
      'allNotifications',
      'allNotificationsSubtitle',
      'discardChangesTitle',
      'discardChangesBody',
      'keepEditing',
      'discardChangesButton',
      'resetToDefaults',
      'resetToDefaultsTitle',
      'resetToDefaultsBody',
      'reset',
      'couldNotLoadNotificationSettings',
      'nextReminderPrefix',
      'cancel',
      'retry',
      'save',
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
