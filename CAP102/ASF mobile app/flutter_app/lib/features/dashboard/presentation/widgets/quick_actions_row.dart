import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../theme/dashboard_palette.dart';

/// "Quick Actions" — five square shortcut buttons (Record Weight/Health
/// Check/Feeding Guide/Expenses/Pig Photos) from the 2026 premium-dashboard
/// mockup. Every button just navigates to an existing route the app already
/// has (the Health Monitor form, Feeding Guide, Expense & ROI). Record
/// Weight and Pig Photos both land on the merged Pig Growth tab now — Record
/// Weight/weigh-in history and weekly photo capture both live inside a
/// pig's own profile there (see pig_detail_screen.dart) — no new screen,
/// provider, or business logic is introduced here.
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key, required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.monitor_weight_rounded,
        label: tr(lang, 'recordWeightAction'),
        onTap: () => context.go(AppRoutes.pigs),
      ),
      _QuickAction(
        icon: Icons.health_and_safety_outlined,
        label: tr(lang, 'healthCheckAction'),
        // Health Monitor redesign — opens the independent Home hub
        // (Specific Pig / Overall Herd mode selection) instead of jumping
        // straight into the old flock-level form.
        onTap: () => context.push(AppRoutes.healthHub),
      ),
      _QuickAction(
        icon: Icons.grass_rounded,
        label: tr(lang, 'feedingGuideAction'),
        onTap: () => context.go(AppRoutes.feeding),
      ),
      _QuickAction(
        icon: Icons.payments_rounded,
        label: tr(lang, 'expensesAction'),
        onTap: () => context.go(AppRoutes.expenses),
      ),
      _QuickAction(
        icon: Icons.camera_alt_rounded,
        label: tr(lang, 'pigPhotosAction'),
        onTap: () => context.go(AppRoutes.pigs),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(lang, 'quickActionsTitle'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: actions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => actions[i],
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatefulWidget {
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 78,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: DashboardPalette.card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: DashboardPalette.lightGreen,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.icon,
                        size: 18, color: DashboardPalette.darkGreen),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600),
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
