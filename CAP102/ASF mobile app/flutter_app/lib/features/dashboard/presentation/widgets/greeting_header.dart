import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/app_router.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../domain/dashboard_calculations.dart';
import '../../presentation/providers/dashboard_providers.dart';
import '../theme/dashboard_palette.dart';

/// Greeting word (Morning/Afternoon/Evening) derived from the device's real
/// current time — not hardcoded. Shared between [GreetingHeader] and
/// [DashboardHeroHeader] (the new illustrated hero, which now renders the
/// actual "Good Morning, {Farmer} 👋" line) so there's exactly one place
/// that decides which greeting word to show.
String dashboardGreetingWord(AppLanguage lang) {
  final hour = DateTime.now().hour;
  if (hour < 12) return tr(lang, 'goodMorning');
  if (hour < 18) return tr(lang, 'goodAfternoon');
  return tr(lang, 'goodEvening');
}

/// "Day X of 120 · <today's real date>" + Calendar/Log Today pill buttons —
/// plus, when [showGreetingLine] is true (the default, used by any other
/// caller), the "Good Morning, {Farmer} 👋" line above it. The redesigned
/// Dashboard now shows that greeting inside the new illustrated hero header
/// instead (see DashboardHeroHeader), so it passes showGreetingLine: false
/// here to avoid showing it twice — everything else (day counter, retry-name
/// affordance, Calendar/Log Today pills, the exact confirm-then-advanceDay()
/// flow) is unchanged. The date is derived from the device's real current
/// time — not hardcoded — same honesty bar as every other value on this
/// screen. "Log Today" is the exact same confirm-then-advanceDay() flow the
/// old bottom-of-page button used (DashboardController.advanceDay, the
/// all-tasks-done gate, the same confirmation dialog copy). No new business
/// logic: everything here reads DashboardData/DashboardController, which
/// this redesign does not touch.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader(
      {super.key,
      required this.firstName,
      required this.data,
      required this.onAdvance,
      required this.lang,
      this.onRetryName,
      this.showGreetingLine = true});

  final String? firstName;
  final DashboardData data;
  final Future<bool> Function() onAdvance;
  final AppLanguage lang;

  /// P2 fix: previously, if the profile fetch that supplies [firstName]
  /// failed (not "no name saved" — an actual fetch error, e.g. a network
  /// blip right after login), the Dashboard just rendered with
  /// firstName: null forever, with no way for the user to recover short of
  /// force-closing the app. That's what produced "Good Morning, Farmer 👋"
  /// for a real, already-logged-in user. When this is non-null, a null
  /// [firstName] renders as a tappable "Farmer" with a small refresh icon
  /// that calls this to retry the fetch, instead of a silent dead end.
  final VoidCallback? onRetryName;

  /// See class doc — false on the redesigned Dashboard, where
  /// DashboardHeroHeader already shows this line inside the illustrated
  /// hero.
  final bool showGreetingLine;

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('MMMM d, yyyy').format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showGreetingLine) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    '${dashboardGreetingWord(lang)}, ${firstName ?? tr(lang, 'farmerFallback')} 👋',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ),
                if (firstName == null && onRetryName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Semantics(
                      button: true,
                      label: tr(lang, 'retryLoadingNameLabel'),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onRetryName,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.refresh_rounded,
                              size: 20, color: DashboardPalette.textGray),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Text(
            data.cycleComplete
                ? '${tr(lang, 'cycleCompleteLabel')} · $today'
                : '${tr(lang, 'dayLabel')} ${data.currentDay} ${tr(lang, 'ofLabel')} $kMaxProductionDay · $today',
            style:
                const TextStyle(fontSize: 13, color: DashboardPalette.textGray),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _PillButton(
                icon: Icons.calendar_month_rounded,
                label: tr(lang, 'calendarPillLabel'),
                filled: false,
                onTap: () => context.push(AppRoutes.calendar),
              ),
              const SizedBox(width: 10),
              if (!data.cycleComplete)
                Expanded(
                  child: _PillButton(
                    icon: Icons.add_rounded,
                    label: tr(lang, 'logTodayLabel'),
                    filled: true,
                    onTap: () => _confirmAdvance(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAdvance(BuildContext context) async {
    // C8 fix: previously a plain SnackBar with no path forward — the user
    // saw "Complete tasks first!" and had to independently know to go find
    // the Tasks screen themselves. Now offers "Go to Tasks" directly.
    if (!data.allTasksDone) {
      final goToTasks = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr(lang, 'completeTasksFirstSnackbar')),
          content: Text(tr(lang, 'incompleteTasksDialogBody')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr(lang, 'cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr(lang, 'goToTasks'))),
          ],
        ),
      );
      if (goToTasks == true && context.mounted) context.push(AppRoutes.tasks);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            '${tr(lang, 'dayLabel')} ${data.currentDay} ${tr(lang, 'completeExclaim')}'),
        content:
            Text('${tr(lang, 'proceedToDayPrefix')} ${data.currentDay + 1}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr(lang, 'cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
                '${tr(lang, 'proceedToDayPrefix')} ${data.currentDay + 1} →'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onAdvance();
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton(
      {required this.icon,
      required this.label,
      required this.filled,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: filled ? DashboardPalette.primaryGreen : DashboardPalette.card,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: filled ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 18,
                      color:
                          filled ? Colors.white : DashboardPalette.darkGreen),
                  const SizedBox(width: 8),
                  // Flexible+ellipsis (not a bare Text) — this button sits
                  // next to the fixed-width Calendar pill inside an outer
                  // Row where this one is the Expanded side. On narrow
                  // phones the Calendar pill's own intrinsic width can
                  // leave this Expanded slot narrower than "Log Today"'s
                  // natural width, which without this wrap overflowed the
                  // RenderFlex on the right (caught by
                  // test/dashboard_responsive_test.dart's small/medium
                  // viewport sweep) instead of gracefully truncating.
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color:
                            filled ? Colors.white : DashboardPalette.darkGreen,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
