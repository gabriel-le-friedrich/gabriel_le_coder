import 'package:flutter/material.dart';

import '../theme/dashboard_palette.dart';

class _NavDestination {
  const _NavDestination(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// The 5 tabs the redesigned Dashboard shell shows in its floating bottom
/// nav — Dashboard/Tasks/Feeding/Pig Growth/Expense. The former separate
/// "Weight" and "Growth" tabs were merged into one unified "Pig Growth" tab
/// (see pig_list_screen.dart/pig_detail_screen.dart's file headers) since
/// they duplicated the same batch-level weight/ADG/FCR data. Order here MUST
/// match the branch order passed to StatefulShellRoute.indexedStack in
/// app_router.dart.
const _destinations = [
  _NavDestination(Icons.space_dashboard_rounded, 'Dashboard'),
  _NavDestination(Icons.checklist_rounded, 'Tasks'),
  _NavDestination(Icons.grass_rounded, 'Feeding'),
  _NavDestination(Icons.pets_rounded, 'Pig Growth'),
  _NavDestination(Icons.payments_rounded, 'Expense'),
];

/// A floating, rounded, pill-style bottom navigation bar — a purely visual
/// restyle of standard tab navigation. Selection state (currentIndex) and
/// the actual navigation action (onTap) are owned by the caller
/// (DashboardShellScaffold), which drives GoRouter's StatefulShellRoute;
/// this widget has no navigation logic of its own.
class DashboardBottomNav extends StatelessWidget {
  const DashboardBottomNav(
      {super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: DashboardPalette.card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: List.generate(_destinations.length, (i) {
              final dest = _destinations[i];
              final selected = i == currentIndex;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: dest.label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: selected
                                ? DashboardPalette.lightGreen
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            scale: selected ? 1.08 : 1.0,
                            child: Icon(
                              dest.icon,
                              size: 22,
                              color: selected
                                  ? DashboardPalette.darkGreen
                                  : DashboardPalette.textGray,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? DashboardPalette.darkGreen
                                : DashboardPalette.textGray,
                          ),
                          child: Text(dest.label),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
