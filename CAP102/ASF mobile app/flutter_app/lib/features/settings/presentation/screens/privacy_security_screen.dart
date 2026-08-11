import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../domain/settings_strings.dart';
import '../providers/settings_providers.dart';
import '../theme/settings_palette.dart';
import '../widgets/settings_widgets.dart';

/// Privacy & Security — the same honest Account Security summary shown on
/// Profile & Farm (Firebase Authentication + SQLite/Supabase storage; see
/// _AccountSecurityCard in profile_edit_screen.dart for the identical
/// claim), plus links to the existing Privacy Policy and Terms of Service
/// screens (unchanged routes/content). No new security features are
/// claimed here — this only groups already-true statements and existing
/// screens under one menu entry.
class PrivacySecurityScreen extends ConsumerWidget {
  const PrivacySecurityScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: SettingsPalette.background,
      appBar: AppBar(
        title: Text(tr(lang, 'privacySecurityLabel'),
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
          Container(
            decoration: settingsCardDecoration(),
            padding: settingsCardPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                      color: SettingsPalette.lightGreen,
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Icon(Icons.shield_outlined,
                      color: SettingsPalette.primaryGreen, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(lang, 'accountSecureTitle'),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: SettingsPalette.darkText)),
                      const SizedBox(height: 6),
                      Text(tr(lang, 'accountSecureBody'),
                          style: const TextStyle(
                              fontSize: 13,
                              color: SettingsPalette.grayText,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SettingsGroupCard(children: [
            SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: tr(lang, 'privacyPolicy'),
              onTap: () => context.push(AppRoutes.privacyPolicy),
            ),
            SettingsTile(
              icon: Icons.description_outlined,
              title: tr(lang, 'termsOfService'),
              onTap: () => context.push(AppRoutes.termsOfService),
            ),
          ]),
        ]),
      ),
    );
  }
}
