import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../theme/dashboard_palette.dart';

/// The three right-side app bar controls from the mockup: a PH|FIL language
/// pill, a notification bell, and a profile avatar. All three reuse
/// existing state/providers rather than inventing new ones:
///  - the language pill reads/writes appLanguageProvider via applyLanguage(),
///    the exact same function the Settings > Language picker already calls.
///  - the bell pushes the existing Notification Settings route (no fake
///    unread-count badge is shown — this app has no unread/inbox concept for
///    local reminders, so a badge here would just be invented data).
///  - the avatar shows the signed-in farmer's real initial and opens
///    Settings, same destination the old AppBar's settings icon used.
class DashboardAppBarActions extends ConsumerWidget {
  const DashboardAppBarActions(
      {super.key,
      required this.uid,
      required this.fullName,
      this.showNotificationBadge = false});

  final String uid;
  final String? fullName;
  // Off by default everywhere (unchanged behavior for Dashboard/Weight &
  // ADG/Pig Growth) — only the Expense & ROI screen turns this on, and only
  // when it has a real signal to show (an expense logged today), never an
  // invented unread count. See expenses_screen.dart's _hasTodayExpense.
  final bool showNotificationBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final initial = (fullName ?? '').trim().isNotEmpty
        ? fullName!.trim()[0].toUpperCase()
        : 'F';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LanguagePill(uid: uid, lang: lang),
        const SizedBox(width: 8),
        _CircleIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: tr(lang, 'notifications'),
          showBadge: showNotificationBadge,
          onTap: () => context.push(AppRoutes.notificationSettings),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: tr(lang, 'openProfileTooltip'),
          child: GestureDetector(
            onTap: () => context.push(AppRoutes.settings),
            // 36x36 visual avatar sits inside this 48x48 tap target so the
            // touch area meets the accessibility minimum without changing
            // how large the avatar itself looks in the app bar.
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: DashboardPalette.primaryGreen,
                  child: Text(initial,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguagePill extends ConsumerWidget {
  const _LanguagePill({required this.uid, required this.lang});
  final String uid;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: tr(lang, 'switchLanguageTooltip'),
      value: lang == AppLanguage.fil ? 'Filipino' : 'English',
      child: GestureDetector(
        onTap: () => _showLanguageSheet(context, ref),
        // Constrained to at least 48x48 so the small pill still has a full
        // accessible/touch-friendly tap area, without stretching its visual
        // size in the app bar.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: DashboardPalette.lightGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                lang == AppLanguage.fil ? 'PH | FIL' : 'PH | EN',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DashboardPalette.darkGreen),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tr(lang, 'selectLanguage'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            RadioGroup<AppLanguage>(
              groupValue: lang,
              onChanged: (v) async {
                if (v == null) return;
                Navigator.pop(ctx);
                await applyLanguage(ref, uid, v);
              },
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
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.showBadge = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DashboardPalette.background,
      shape: const CircleBorder(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(icon, color: DashboardPalette.darkGreen),
            tooltip: tooltip,
            onPressed: onTap,
          ),
          if (showBadge)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5)),
              ),
            ),
        ],
      ),
    );
  }
}
