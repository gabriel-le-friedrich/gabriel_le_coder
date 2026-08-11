import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../settings/presentation/theme/settings_palette.dart';
import '../../../settings/presentation/widgets/settings_widgets.dart';
import '../../domain/notification_prefs.dart';
import '../../domain/reminder_types.dart';
import '../providers/notification_providers.dart';

/// Notification Settings — master switch, then every real reminder type
/// (kReminderTypes — unchanged; see reminder_types.dart) grouped under two
/// honest headers using the type's own existing `isCritical` flag: Health
/// Check and Market Day (the two the domain model already marks critical)
/// under "Alert Notifications", the other seven under "Reminder
/// Notifications". No "Quiet Hours" toggle here — this app has no
/// do-not-disturb window in its scheduling logic today, and a switch with
/// no backend behind it would be fake UI, so it's intentionally omitted
/// rather than added as a no-op (see the Settings redesign plan).
///
/// Edits remain draft-only until Save; leaving with unsaved changes still
/// prompts the same discard-changes dialog. Restyled to SettingsPalette —
/// no change to NotificationSettingsController/notification_prefs.dart.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final stateAsync = ref.watch(notificationSettingsControllerProvider(uid));
    final controller =
        ref.read(notificationSettingsControllerProvider(uid).notifier);
    final lang = ref.watch(appLanguageProvider);

    ref.listen(notificationSettingsControllerProvider(uid), (previous, next) {
      final data = next.valueOrNull;
      if (data == null) return;
      if (data.message != null &&
          data.message != previous?.valueOrNull?.message) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(data.message!)));
        controller.clearMessages();
      }
      if (data.errorMessage != null &&
          data.errorMessage != previous?.valueOrNull?.errorMessage) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(data.errorMessage!)));
      }
    });

    final alertTypes = kReminderTypes.where((r) => r.isCritical).toList();
    final reminderTypes = kReminderTypes.where((r) => !r.isCritical).toList();

    return PopScope(
      canPop: !(stateAsync.valueOrNull?.hasUnsavedChanges ?? false),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final data = stateAsync.valueOrNull;
        if (data == null) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tr(lang, 'discardChangesTitle')),
            content: Text(tr(lang, 'discardChangesBody')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr(lang, 'keepEditing'))),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(tr(lang, 'discardChangesButton'))),
            ],
          ),
        );
        if (discard == true) {
          controller.discardChanges();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: SettingsPalette.background,
        appBar: AppBar(
          title: Text(tr(lang, 'notifications'),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: SettingsPalette.darkText)),
          backgroundColor: SettingsPalette.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: SettingsPalette.darkText),
        ),
        body: stateAsync.when(
          data: (data) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: settingsAnimatedChildren([
              Container(
                decoration: settingsCardDecoration(radius: 18),
                padding: settingsCardPadding,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(lang, 'allNotifications'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: SettingsPalette.darkText)),
                  subtitle: Text(tr(lang, 'allNotificationsSubtitle'),
                      style: const TextStyle(
                          fontSize: 11.5, color: SettingsPalette.grayText)),
                  value: data.draft.masterEnabled,
                  activeThumbColor: SettingsPalette.primaryGreen,
                  onChanged: controller.toggleMaster,
                ),
              ),
              const SizedBox(height: 18),
              if (alertTypes.isNotEmpty) ...[
                SettingsSectionLabel(tr(lang, 'alertNotificationsTitle')),
                for (final def in alertTypes)
                  _ReminderCard(
                    def: def,
                    pref: data.draft.prefFor(def.key),
                    masterEnabled: data.draft.masterEnabled,
                    lang: lang,
                    onToggle: (v) => controller.toggleReminder(def.key, v),
                    onTimeChanged: (h, m) =>
                        controller.updateTime(def.key, h, m),
                    onWeekdayChanged: (w) =>
                        controller.updateWeekday(def.key, w),
                  ),
                const SizedBox(height: 10),
              ],
              if (reminderTypes.isNotEmpty) ...[
                SettingsSectionLabel(tr(lang, 'reminderNotificationsTitle')),
                for (final def in reminderTypes)
                  _ReminderCard(
                    def: def,
                    pref: data.draft.prefFor(def.key),
                    masterEnabled: data.draft.masterEnabled,
                    lang: lang,
                    onToggle: (v) => controller.toggleReminder(def.key, v),
                    onTimeChanged: (h, m) =>
                        controller.updateTime(def.key, h, m),
                    onWeekdayChanged: (w) =>
                        controller.updateWeekday(def.key, w),
                  ),
              ],
              const SizedBox(height: 12),
              CustomButton(
                label: tr(lang, 'resetToDefaults'),
                icon: Icons.restore,
                outlined: true,
                onPressed: data.isSaving
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            title: Text(tr(lang, 'resetToDefaultsTitle')),
                            content: Text(tr(lang, 'resetToDefaultsBody')),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(tr(lang, 'cancel'))),
                              FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor:
                                          SettingsPalette.primaryGreen),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(tr(lang, 'reset'))),
                            ],
                          ),
                        );
                        if (confirmed == true)
                          await controller.resetToDefaults();
                      },
              ),
            ]),
          ),
          loading: () => const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      SettingsPalette.primaryGreen)),
            ),
          ),
          error: (_, __) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr(lang, 'couldNotLoadNotificationSettings'),
                    style: const TextStyle(color: SettingsPalette.darkText)),
                const SizedBox(height: 12),
                CustomButton(
                    label: tr(lang, 'retry'), onPressed: controller.load),
              ],
            ),
          ),
        ),
        bottomNavigationBar: stateAsync.valueOrNull == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CustomButton(
                    label: tr(lang, 'save'),
                    loading: stateAsync.valueOrNull!.isSaving,
                    onPressed: (stateAsync.valueOrNull!.hasUnsavedChanges &&
                            !stateAsync.valueOrNull!.isSaving)
                        ? controller.save
                        : null,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.def,
    required this.pref,
    required this.masterEnabled,
    required this.lang,
    required this.onToggle,
    required this.onTimeChanged,
    required this.onWeekdayChanged,
  });

  final ReminderTypeDef def;
  final ReminderPref pref;
  final bool masterEnabled;
  final AppLanguage lang;
  final void Function(bool) onToggle;
  final void Function(int hour, int minute) onTimeChanged;
  final void Function(int weekday) onWeekdayChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: settingsCardDecoration(radius: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text(reminderTitle(lang, def.key, def.title),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: SettingsPalette.darkText)),
              subtitle: Text(
                  reminderDescription(lang, def.key, def.description),
                  style: const TextStyle(
                      fontSize: 11.5, color: SettingsPalette.grayText)),
              value: pref.enabled,
              activeThumbColor: SettingsPalette.primaryGreen,
              onChanged: masterEnabled ? onToggle : null,
            ),
            if (pref.enabled && masterEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(pref.timeLabel),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime:
                              TimeOfDay(hour: pref.hour, minute: pref.minute),
                        );
                        if (picked != null)
                          onTimeChanged(picked.hour, picked.minute);
                      },
                    ),
                    if (def.repeat == ReminderRepeat.weekly)
                      DropdownButton<int>(
                        value: pref.weekday ??
                            def.defaultWeekday ??
                            DateTime.monday,
                        items: List.generate(7, (i) => i + 1)
                            .map((w) => DropdownMenuItem(
                                value: w, child: Text(kWeekdayShortNames[w])))
                            .toList(),
                        onChanged: (w) {
                          if (w != null) onWeekdayChanged(w);
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
