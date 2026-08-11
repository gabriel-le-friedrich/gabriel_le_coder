import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/dashboard_palette.dart';
import 'dashboard_bottom_nav.dart';

/// Hosts the 5-tab StatefulShellRoute (Dashboard/Tasks/Feeding/Pig Growth/
/// Expense) behind one persistent floating bottom nav bar. Each branch keeps
/// its own Navigator/scroll position alive via IndexedStack (GoRouter's
/// StatefulShellRoute default), matching the mockup's native bottom-tab
/// feel. Screens reached by pushing OFF this shell (Settings, Health, Pig
/// sub-routes, Notifications, Activity Log, About/Privacy/Terms — all still
/// top-level GoRoutes, unchanged) correctly cover the whole shell, including
/// the nav bar, exactly like any normal full-screen push.
class DashboardShellScaffold extends StatelessWidget {
  const DashboardShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardPalette.background,
      body: navigationShell,
      bottomNavigationBar: DashboardBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          // Tapping the already-selected tab pops back to that branch's
          // root (standard bottom-nav behavior), same as tapping the
          // active tab in any Material bottom nav bar.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
