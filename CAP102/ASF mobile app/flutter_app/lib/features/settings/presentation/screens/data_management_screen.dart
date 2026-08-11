import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../domain/settings_strings.dart';
import '../providers/settings_providers.dart';
import '../theme/settings_palette.dart';
import '../widgets/reset_progress_flow.dart';
import '../widgets/settings_widgets.dart';

/// Data Management — links to the real per-module CSV/PDF export screens
/// (Expenses, Health History) and the real Activity Log, plus the existing
/// Reset Progress danger action (unchanged 3-step confirm flow — see
/// reset_progress_flow.dart). Nothing here is a new export/reset
/// implementation; this screen only surfaces already-working
/// screens/actions one level deeper, per the redesign's requested
/// structure.
class DataManagementScreen extends ConsumerWidget {
  const DataManagementScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: SettingsPalette.background,
      appBar: AppBar(
        title: Text(tr(lang, 'dataManagementLabel'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: SettingsPalette.darkText)),
        backgroundColor: SettingsPalette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: SettingsPalette.darkText),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: settingsAnimatedChildren([
          Text(tr(lang, 'dataManagementIntro'),
              style: const TextStyle(
                  fontSize: 13.5,
                  color: SettingsPalette.grayText,
                  height: 1.4)),
          const SizedBox(height: 18),
          SettingsGroupCard(children: [
            SettingsTile(
              icon: Icons.receipt_long_outlined,
              title: tr(lang, 'expensesRecordsLabel'),
              subtitle: tr(lang, 'expensesRecordsSubtitle'),
              onTap: () => context.go(AppRoutes.expenses),
            ),
            SettingsTile(
              icon: Icons.monitor_heart_outlined,
              title: tr(lang, 'healthHistoryTitle'),
              subtitle: tr(lang, 'healthLogsExportSubtitle'),
              onTap: () => context.push(AppRoutes.health),
            ),
            SettingsTile(
              icon: Icons.history,
              title: tr(lang, 'activityLog'),
              subtitle: tr(lang, 'activityLogSubtitle'),
              onTap: () => context.push(AppRoutes.activityLog),
            ),
          ]),
          const SizedBox(height: 26),
          SettingsSectionLabel(tr(lang, 'dangerZoneLabel')),
          Container(
            decoration: settingsCardDecoration(color: SettingsPalette.lightRed),
            padding: settingsCardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: SettingsPalette.red, size: 20),
                    const SizedBox(width: 8),
                    Text(tr(lang, 'resetProgress'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: SettingsPalette.red)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(tr(lang, 'resetProgressSubtitle'),
                    style: const TextStyle(
                        fontSize: 12.5, color: SettingsPalette.darkText)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SettingsPalette.red,
                      side: const BorderSide(color: SettingsPalette.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => startResetProgressFlow(context, uid, lang),
                    child: Text(tr(lang, 'resetProgress'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
