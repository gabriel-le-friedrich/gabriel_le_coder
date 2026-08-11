import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../domain/settings_strings.dart';
import '../providers/settings_providers.dart';
import '../theme/settings_palette.dart';
import '../widgets/settings_widgets.dart';

/// Help & Support — links to the existing Expert Consultation feature
/// (unchanged screen/route). "About" (app version/developer info) stays a
/// direct top-level tile in the main Settings screen per the requested
/// final structure, so it isn't duplicated here.
class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: SettingsPalette.background,
      appBar: AppBar(
        title: Text(tr(lang, 'helpSupportLabel'),
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
          Text(tr(lang, 'helpSupportIntro'),
              style: const TextStyle(
                  fontSize: 13.5,
                  color: SettingsPalette.grayText,
                  height: 1.4)),
          const SizedBox(height: 18),
          SettingsGroupCard(children: [
            SettingsTile(
              icon: Icons.support_agent_outlined,
              title: tr(lang, 'expertConsultation'),
              subtitle: tr(lang, 'expertConsultationSubtitle'),
              onTap: () => context.push(AppRoutes.expertConsultation),
            ),
          ]),
        ]),
      ),
    );
  }
}
