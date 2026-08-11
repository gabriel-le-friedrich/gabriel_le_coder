import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../growth/presentation/providers/growth_providers.dart';
import '../../../pigs/domain/pig.dart';
import '../../../pigs/domain/weekly_pig_image.dart';
import '../../../pigs/presentation/providers/pig_providers.dart';
import '../../../pigs/presentation/screens/pig_detail_screen.dart'
    show kTotalCycleWeeks;
import '../../domain/app_language.dart';
import '../../domain/settings_strings.dart';
import '../providers/settings_providers.dart';
import '../theme/settings_palette.dart';
import '../widgets/settings_widgets.dart';

/// Settings — redesigned as the farmer's account & farm control center.
///
/// Every value shown here comes from real, already-existing data:
/// fullName/profileImage/farmerType/verified from userProfileProvider (the
/// same provider the Dashboard greeting/app bar/Drawer already read — see
/// auth_providers.dart), Total/Active Pigs + Average Weight from
/// pigListProvider/allWeeklyImagesProvider/growthControllerProvider (the
/// exact same providers and aggregation pig_list_screen.dart's Growth
/// Overview card already uses — duplicated here rather than imported since
/// those helpers are file-private there, same "duplicate a small private
/// helper across files" convention used throughout this app). Nothing here
/// is invented: the Farm Summary section simply doesn't render if there are
/// no pigs yet, rather than showing zeros.
///
/// Language/Theme/Notifications/Logout/Reset Progress all call the exact
/// same controllers/repositories the previous plain-ListTile version of
/// this screen called — only the presentation changed. Activity Log, the
/// Reset Progress danger action, Privacy Policy, and Terms of Service moved
/// one tap deeper (into Data Management / Privacy & Security respectively)
/// to match the requested final structure, but every route still exists
/// and still works. Expert Consultation moved into the new Help & Support
/// screen. Email Testing (a Brevo QA/dev tool, not farmer-facing) keeps its
/// route but no longer has a menu tile, per explicit product decision.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final profileAsync = ref.watch(userProfileProvider(uid));
    final profile = profileAsync.valueOrNull;
    final fullName = (profile?['fullName'] as String?)?.trim() ?? '';
    final farmerType = (profile?['farmerType'] as String?)?.trim();
    final profileImage = profile?['profileImage'] as String?;
    final verified = profile?['verified'] as bool? ?? true;

    final pigsAsync = ref.watch(pigListProvider(uid));
    final imagesAsync = ref.watch(allWeeklyImagesProvider(uid));
    final growthAsync = ref.watch(growthControllerProvider(uid));
    final pigs = pigsAsync.valueOrNull ?? const <Pig>[];
    final hasPigs = pigsAsync.hasValue && pigs.isNotEmpty;

    return Scaffold(
      backgroundColor: SettingsPalette.background,
      appBar: AppBar(
        backgroundColor: SettingsPalette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: SettingsPalette.darkText),
        actions: [
          _HeaderIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: tr(lang, 'notifications'),
            onTap: () => context.push(AppRoutes.notificationSettings),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SettingsAvatar(
                imagePath: profileImage, displayName: fullName, radius: 18),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: profileAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : profileAsync.hasError
                ? _ErrorState(
                    lang: lang,
                    onRetry: () => ref.invalidate(userProfileProvider(uid)))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                    children: settingsAnimatedChildren([
                      Text(tr(lang, 'settings'),
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: SettingsPalette.darkText)),
                      const SizedBox(height: 4),
                      Text(tr(lang, 'settingsHeaderSubtitle'),
                          style: const TextStyle(
                              fontSize: 13, color: SettingsPalette.grayText)),
                      const SizedBox(height: 18),
                      _FarmerProfileCard(
                        fullName: fullName,
                        farmerType: farmerType,
                        profileImage: profileImage,
                        verified: verified,
                        lang: lang,
                        onTap: () => context.push(AppRoutes.profileEdit),
                      ),
                      if (hasPigs) ...[
                        const SizedBox(height: 16),
                        _FarmStatsCard(
                          pigs: pigs,
                          images: imagesAsync.valueOrNull ?? const {},
                          currentWeight: growthAsync.valueOrNull?.currentWeight,
                          lang: lang,
                        ),
                      ],
                      const SizedBox(height: 22),
                      SettingsSectionLabel(tr(lang, 'accountSectionTitle')),
                      SettingsGroupCard(children: [
                        SettingsTile(
                          icon: Icons.person_outline,
                          title: tr(lang, 'profileFarmLabel'),
                          subtitle: tr(lang, 'profileFarmSubtitle'),
                          onTap: () => context.push(AppRoutes.profileEdit),
                        ),
                        SettingsTile(
                          icon: Icons.notifications_outlined,
                          title: tr(lang, 'notifications'),
                          subtitle: tr(lang, 'notificationsSubtitle'),
                          onTap: () =>
                              context.push(AppRoutes.notificationSettings),
                        ),
                        SettingsTile(
                          icon: Icons.language,
                          title: tr(lang, 'language'),
                          trailing: SettingsValueTrailing(value: lang.label),
                          onTap: () => _showLanguagePicker(context, ref, lang),
                        ),
                        SettingsTile(
                          icon: Icons.palette_outlined,
                          title: tr(lang, 'theme'),
                          trailing: SettingsValueTrailing(
                              value: _themeModeLabel(lang, themeMode)),
                          onTap: () =>
                              _showThemePicker(context, ref, lang, themeMode),
                        ),
                      ]),
                      const SizedBox(height: 22),
                      SettingsSectionLabel(tr(lang, 'dataSyncSectionTitle')),
                      SettingsGroupCard(children: [
                        SettingsTile(
                          icon: Icons.cloud_sync_outlined,
                          title: tr(lang, 'synchronizationLabel'),
                          subtitle: tr(lang, 'synchronizationSubtitle'),
                          onTap: () => context.push(AppRoutes.synchronization),
                        ),
                        SettingsTile(
                          icon: Icons.storage_outlined,
                          title: tr(lang, 'dataManagementLabel'),
                          subtitle: tr(lang, 'dataManagementSubtitle'),
                          onTap: () => context.push(AppRoutes.dataManagement),
                        ),
                        SettingsTile(
                          icon: Icons.wifi_off_outlined,
                          title: tr(lang, 'offlineModeLabel'),
                          subtitle: tr(lang, 'offlineModeSubtitle'),
                          onTap: () => context.push(AppRoutes.offlineMode),
                        ),
                      ]),
                      const SizedBox(height: 22),
                      SettingsSectionLabel(
                          tr(lang, 'securitySupportSectionTitle')),
                      SettingsGroupCard(children: [
                        SettingsTile(
                          icon: Icons.shield_outlined,
                          title: tr(lang, 'privacySecurityLabel'),
                          subtitle: tr(lang, 'privacySecuritySubtitle'),
                          onTap: () => context.push(AppRoutes.privacySecurity),
                        ),
                        SettingsTile(
                          icon: Icons.help_outline,
                          title: tr(lang, 'helpSupportLabel'),
                          subtitle: tr(lang, 'helpSupportSubtitle'),
                          onTap: () => context.push(AppRoutes.helpSupport),
                        ),
                        SettingsTile(
                          icon: Icons.info_outline,
                          title: tr(lang, 'about'),
                          subtitle: tr(lang, 'aboutSubtitle'),
                          onTap: () => context.push(AppRoutes.about),
                        ),
                      ]),
                      const SizedBox(height: 26),
                      _LogoutButton(
                        label: tr(lang, 'logout'),
                        onTap: () => _confirmLogout(context, ref, lang),
                      ),
                    ]),
                  ),
      ),
    );
  }

  String _themeModeLabel(AppLanguage lang, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return tr(lang, 'light');
      case ThemeMode.dark:
        return tr(lang, 'dark');
      case ThemeMode.system:
        return tr(lang, 'system');
    }
  }

  Future<void> _showLanguagePicker(
      BuildContext context, WidgetRef ref, AppLanguage current) async {
    final selected = await showDialog<AppLanguage>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr(current, 'selectLanguage')),
        children: [
          RadioGroup<AppLanguage>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AppLanguage.values
                  .map((l) => RadioListTile<AppLanguage>(
                      value: l, title: Text(l.label)))
                  .toList(),
            ),
          ),
        ],
      ),
    );
    if (selected != null && selected != current) {
      await applyLanguage(ref, uid, selected);
    }
  }

  Future<void> _showThemePicker(BuildContext context, WidgetRef ref,
      AppLanguage lang, ThemeMode current) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr(lang, 'selectTheme')),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                    value: ThemeMode.light, title: Text(tr(lang, 'light'))),
                RadioListTile<ThemeMode>(
                    value: ThemeMode.dark, title: Text(tr(lang, 'dark'))),
                RadioListTile<ThemeMode>(
                    value: ThemeMode.system, title: Text(tr(lang, 'system'))),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected != null && selected != current) {
      await applyThemeMode(ref, uid, selected);
    }
  }

  Future<void> _confirmLogout(
      BuildContext context, WidgetRef ref, AppLanguage lang) async {
    final confirmed = await showCustomConfirmDialog(
      context,
      title: tr(lang, 'logoutConfirmTitle'),
      message: tr(lang, 'logoutConfirmBody'),
      confirmLabel: tr(lang, 'logout'),
      cancelLabel: tr(lang, 'cancel'),
    );
    if (confirmed) {
      await ref.read(authFlowControllerProvider.notifier).logout();
    }
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SettingsPalette.card,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: SettingsPalette.primaryGreen),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}

/// Premium profile card — real farmer photo (never a pig photo; see
/// SettingsAvatar's doc), real name, real role (farmerType, same label
/// function the Drawer footer already uses), and a real Active Account
/// status chip from the profile's own `verified` flag.
class _FarmerProfileCard extends StatelessWidget {
  const _FarmerProfileCard({
    required this.fullName,
    required this.farmerType,
    required this.profileImage,
    required this.verified,
    required this.lang,
    required this.onTap,
  });
  final String fullName;
  final String? farmerType;
  final String? profileImage;
  final bool verified;
  final AppLanguage lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = fullName.isEmpty ? '—' : fullName;
    final roleLabel = farmerTypeLabel(
        lang,
        (farmerType == null || farmerType!.isEmpty)
            ? 'Backyard Raiser'
            : farmerType!);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: settingsCardDecoration(),
        padding: settingsCardPadding,
        child: Row(
          children: [
            SettingsAvatar(
                imagePath: profileImage, displayName: fullName, radius: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: SettingsPalette.darkText)),
                  const SizedBox(height: 2),
                  Text(roleLabel,
                      style: const TextStyle(
                          fontSize: 13, color: SettingsPalette.grayText)),
                  const SizedBox(height: 8),
                  SettingsStatusChip(
                    label: verified
                        ? tr(lang, 'activeAccountStatus')
                        : tr(lang, 'statusInProgress'),
                    foreground: verified
                        ? SettingsPalette.primaryGreen
                        : SettingsPalette.orange,
                    background: verified
                        ? SettingsPalette.lightGreen
                        : SettingsPalette.lightOrange,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: SettingsPalette.grayText),
          ],
        ),
      ),
    );
  }
}

/// Farm Summary — Total Pigs / Active Pigs / Average Weight / Weeks
/// Recorded, computed from the exact same real data (pigListProvider,
/// allWeeklyImagesProvider, growthControllerProvider.currentWeight) and the
/// same aggregation pig_list_screen.dart's Growth Overview card already
/// uses. Only rendered by the caller when there is at least one pig — no
/// zeroed-out placeholder card for a brand new account.
class _FarmStatsCard extends StatelessWidget {
  const _FarmStatsCard({
    required this.pigs,
    required this.images,
    required this.currentWeight,
    required this.lang,
  });
  final List<Pig> pigs;
  final Map<String, List<WeeklyPigImage>> images;
  final double? currentWeight;
  final AppLanguage lang;

  int _completedWeeksForPig(List<WeeklyPigImage> imgs) =>
      imgs.map((i) => i.weekNumber).toSet().length;

  int _activePigsCount() => pigs
      .where((p) =>
          _completedWeeksForPig(images[p.id] ?? const []) < kTotalCycleWeeks)
      .length;

  int _totalDistinctWeeksRecorded() {
    final weeks = <int>{};
    for (final list in images.values) {
      for (final img in list) {
        weeks.add(img.weekNumber);
      }
    }
    return weeks.length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: settingsCardDecoration(),
      padding: settingsCardPadding,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 2.6,
        children: [
          _StatItem(
              icon: Icons.pets,
              value: '${pigs.length}',
              label: tr(lang, 'totalPigsLabel')),
          _StatItem(
              icon: Icons.favorite_border,
              value: '${_activePigsCount()}',
              label: tr(lang, 'activePigsLabel')),
          _StatItem(
              icon: Icons.monitor_weight_outlined,
              value: currentWeight == null
                  ? '—'
                  : '${currentWeight!.toStringAsFixed(1)} kg',
              label: tr(lang, 'averageWeightLabel')),
          _StatItem(
              icon: Icons.calendar_month,
              value: '${_totalDistinctWeeksRecorded()}',
              label: tr(lang, 'weeksRecordedCaption')),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem(
      {required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: SettingsPalette.lightGreen,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 17, color: SettingsPalette.primaryGreen),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: SettingsPalette.darkText)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: SettingsPalette.grayText,
                      letterSpacing: 0.2)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Professional destructive-action button — red text/icon on a very light
/// red background, per spec. Calls the exact same confirm-dialog + logout
/// path the previous plain ListTile version used.
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: SettingsPalette.lightRed,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout, color: SettingsPalette.red, size: 19),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        color: SettingsPalette.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.lang, required this.onRetry});
  final AppLanguage lang;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr(lang, 'unableToLoadProfileMessage'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: SettingsPalette.grayText)),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: SettingsPalette.primaryGreen),
              onPressed: onRetry,
              child: Text(tr(lang, 'retry')),
            ),
          ],
        ),
      ),
    );
  }
}
