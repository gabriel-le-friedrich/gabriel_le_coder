import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════
// Presentation-only palette for the redesigned Health Monitor module
// (Home hub / Specific Pig / Overall Herd flows). Same one-palette-per-
// redesigned-screen-family pattern as SettingsPalette/PigGrowthPalette —
// matches the ASF Health Monitor redesign spec's exact hex values.
//
// Status colors (Healthy/Needs Monitoring/At Risk/Critical) are
// deliberately NOT redeclared here — they come from
// health_status_colors.dart's kHealthStatusColor, the single source of
// truth already used by the History screen, Dashboard, and PDF/CSV
// export. Reusing it (rather than a second, slightly different set of
// hex values) keeps a status the same color everywhere it appears.
// ══════════════════════════════════════════════════════════════════════
class HealthMonitorPalette {
  HealthMonitorPalette._();

  static const primaryGreen = Color(0xFF2E7D32);
  static const secondaryGreen = Color(0xFF43A047);
  static const lightGreen = Color(0xFFEAF7E6);
  static const darkText = Color(0xFF1F2937);
  static const grayText = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const background = Color(0xFFF7F9F6);
  static const card = Color(0xFFFFFFFF);
}

BoxDecoration healthCardDecoration(
    {Color color = HealthMonitorPalette.card, double radius = 18}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6)),
    ],
  );
}

const healthCardPadding = EdgeInsets.all(16);

const healthSectionTitleStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: HealthMonitorPalette.grayText,
    letterSpacing: 0.6);

/// Staggered fade+slide entrance — same technique as every other
/// redesigned screen family in this app (SettingsFadeSlideIn,
/// PigGrowthFadeSlideIn), kept as its own copy so this module doesn't
/// reach across feature boundaries for a purely visual helper.
class HealthFadeSlideIn extends StatefulWidget {
  const HealthFadeSlideIn({super.key, required this.child, required this.delayMs});
  final Widget child;
  final int delayMs;

  @override
  State<HealthFadeSlideIn> createState() => _HealthFadeSlideInState();
}

class _HealthFadeSlideInState extends State<HealthFadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
        child: widget.child,
      ),
    );
  }
}

List<Widget> healthAnimatedChildren(List<Widget> children) {
  return children.asMap().entries.map((e) {
    final i = e.key;
    final child = e.value;
    if (child is SizedBox) return child;
    return HealthFadeSlideIn(delayMs: i * 50, child: child);
  }).toList();
}
