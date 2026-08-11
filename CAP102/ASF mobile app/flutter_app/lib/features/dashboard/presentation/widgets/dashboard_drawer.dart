import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../theme/dashboard_palette.dart';

/// The hamburger-menu Drawer for the Dashboard screen.
///
/// Rebuilt to use ONLY Flutter's standard Material Drawer contract —
/// Scaffold.drawer + Drawer + SafeArea + the framework's own default
/// slide-in animation. There is no Transform/AnimatedContainer/manual
/// offset anywhere in this file: the Drawer overlays the screen and
/// animates in on its own, which is what already keeps the AppBar (owned
/// by dashboard_screen.dart's Scaffold, a sibling of this Drawer — never a
/// parent/child of it) completely fixed while this slides over the content.
///
/// Content below is grouped into MAIN / RECORDS / ACCOUNT sections plus a
/// profile footer, matching the requested reference layout. Every item
/// still points at the exact same route it did before this restructure
/// (Activity Log / Log Out — not present in the reference list — were kept
/// under ACCOUNT rather than dropped, since the Activity Log Viewer would
/// otherwise lose its only entry point; Notifications was left out here
/// since the AppBar bell already covers it). The former separate "Weight &
/// ADG" and "Pig Growth" (growth-overview) items were merged into one Pig
/// Growth entry in MAIN, and the old ACCOUNT "My Pigs" item was removed as
/// redundant with it — both used to point at overlapping/duplicate screens,
/// now consolidated into the single Pig Growth module. No other navigation
/// logic, provider, or business logic changed.
class DashboardDrawer extends ConsumerWidget {
  const DashboardDrawer({super.key, required this.uid, required this.fullName});

  final String uid;
  final String? fullName;

  static const _maxWidth = 320.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = (screenWidth * 0.8).clamp(0.0, _maxWidth);
    final currentLocation = GoRouterState.of(context).uri.toString();
    final profileAsync = ref.watch(userProfileProvider(uid));
    final farmerType =
        (profileAsync.valueOrNull?['farmerType'] as String?)?.trim();
    final displayName =
        (fullName ?? '').trim().isEmpty ? 'Farmer' : fullName!.trim();
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'F';
    final lang = ref.watch(appLanguageProvider);

    return Drawer(
      width: drawerWidth,
      backgroundColor: DashboardPalette.card,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DrawerHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _SectionLabel(tr(lang, 'navSectionMain')),
                  _DrawerItem(
                    icon: Icons.space_dashboard_rounded,
                    label: tr(lang, 'navDashboard'),
                    selected: currentLocation == AppRoutes.dashboard,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.dashboard);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.checklist_rounded,
                    label: tr(lang, 'navDailyTasks'),
                    selected: currentLocation == AppRoutes.tasks,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.tasks);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.grass_rounded,
                    label: tr(lang, 'navFeedingGuide'),
                    selected: currentLocation == AppRoutes.feeding,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.feeding);
                    },
                  ),
                  _DrawerItem(
                    // Health Monitor redesign — the two previous entries
                    // ("Health Monitor" -> the daily observation form,
                    // "Health Logs" -> the history list) are merged into
                    // ONE entry that opens the new independent Health
                    // Monitor Home hub (Today's Overview + Specific Pig /
                    // Overall Herd mode selector). The hub itself exposes a
                    // "View History" action for what "Health Logs" used to
                    // open directly, and the daily-observation form is
                    // still reachable from inside the hub's mode flows.
                    // Health Monitor is deliberately its own top-level
                    // Drawer entry, never nested under Pig Growth.
                    icon: Icons.health_and_safety_outlined,
                    label: tr(lang, 'healthMonitorNavLabel'),
                    selected: currentLocation == AppRoutes.healthHub,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.healthHub);
                    },
                  ),
                  _DrawerItem(
                    // Merged Pig Growth module — replaces what used to be
                    // two separate drawer entries ("Weight & ADG" and "Pig
                    // Growth", the latter actually opening the batch-level
                    // Growth Overview screen). Both are now one unified
                    // screen at AppRoutes.pigs; see pig_list_screen.dart /
                    // pig_detail_screen.dart's file headers for why.
                    icon: Icons.pets_rounded,
                    label: tr(lang, 'navPigGrowth'),
                    selected: currentLocation.startsWith(AppRoutes.pigs),
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.pigs);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.payments_rounded,
                    label: tr(lang, 'navExpenseRoi'),
                    selected: currentLocation == AppRoutes.expenses,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.expenses);
                    },
                  ),
                  _SectionLabel(tr(lang, 'navSectionRecords')),
                  _DrawerItem(
                    icon: Icons.phone_in_talk_outlined,
                    label: tr(lang, 'navVetContacts'),
                    selected: currentLocation == AppRoutes.vetContacts,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.vetContacts);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.calendar_month_rounded,
                    label: tr(lang, 'navCalendar'),
                    selected: currentLocation == AppRoutes.calendar,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.calendar);
                    },
                  ),
                  _SectionLabel(tr(lang, 'navSectionAccount')),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: tr(lang, 'navSettings'),
                    selected: currentLocation == AppRoutes.settings,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.settings);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.history_rounded,
                    label: tr(lang, 'navActivityLog'),
                    selected: currentLocation == AppRoutes.activityLog,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.activityLog);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.logout,
                    label: tr(lang, 'navLogOut'),
                    color: DashboardPalette.warningRed,
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(authFlowControllerProvider.notifier).logout();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _DrawerFooter(
                initial: initial,
                name: displayName,
                role: farmerTypeLabel(
                    lang,
                    (farmerType == null || farmerType.isEmpty)
                        ? 'Backyard Raiser'
                        : farmerType)),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: DashboardPalette.darkGreen,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🐷 ASF',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          SizedBox(height: 4),
          Text('Swine Finisher',
              style: TextStyle(fontSize: 13, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: DashboardPalette.textGray),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.selected = false,
      this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : (color ?? DashboardPalette.textGray);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: selected ? DashboardPalette.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon,
                        size: 22,
                        color: color != null && !selected ? color : fg),
                    const SizedBox(width: 16),
                    Text(
                      label,
                      style: TextStyle(
                        color: color != null && !selected ? color : fg,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter(
      {required this.initial, required this.name, required this.role});
  final String initial;
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Semantics(
            label: 'Profile photo: $name, $role',
            image: true,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: DashboardPalette.primaryGreen,
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis),
                Text(role,
                    style: const TextStyle(
                        color: DashboardPalette.textGray, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
