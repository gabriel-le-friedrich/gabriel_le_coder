import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════
// Presentation-only palette for the redesigned Settings module (Settings
// menu / Profile & Farm / Notification Settings / Synchronization / Data
// Management / Offline Mode / Privacy & Security / Help & Support). Same
// pattern as DashboardPalette/ExpensePalette/PigGrowthPalette — one palette
// per redesigned screen family rather than a cross-feature import, and the
// exact hex values the ASF Settings redesign spec calls for (which happen
// to already match PigGrowthPalette's values 1:1, since both come from the
// same app-wide agricultural design spec).
// ══════════════════════════════════════════════════════════════════════
class SettingsPalette {
  SettingsPalette._();

  static const primaryGreen = Color(0xFF2E7D32);
  static const secondaryGreen = Color(0xFF43A047);
  static const lightGreen = Color(0xFFEAF7E6);
  static const darkText = Color(0xFF1F2937);
  static const grayText = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const background = Color(0xFFF7F9F6);
  static const orange = Color(0xFFF59E0B);
  static const lightOrange = Color(0xFFFEF3E2);
  static const red = Color(0xFFEF4444);
  static const lightRed = Color(0xFFFEECEC);
  static const success = Color(0xFF22C55E);
  static const card = Color(0xFFFFFFFF);
}

BoxDecoration settingsCardDecoration(
    {Color color = SettingsPalette.card, double radius = 20}) {
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

const settingsCardPadding = EdgeInsets.all(18);

const settingsSectionTitleStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: SettingsPalette.grayText,
    letterSpacing: 0.6);

/// Staggered fade+slide entrance for top-level cards — same technique
/// already used by every other redesigned screen family in this app
/// (PigGrowthFadeSlideIn/FadeSlideIn), kept as its own copy here so this
/// module doesn't reach across feature boundaries for a purely visual
/// helper.
class SettingsFadeSlideIn extends StatefulWidget {
  const SettingsFadeSlideIn(
      {super.key, required this.child, required this.delayMs});
  final Widget child;
  final int delayMs;

  @override
  State<SettingsFadeSlideIn> createState() => _SettingsFadeSlideInState();
}

class _SettingsFadeSlideInState extends State<SettingsFadeSlideIn>
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
            .animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
        child: widget.child,
      ),
    );
  }
}

List<Widget> settingsAnimatedChildren(List<Widget> children) {
  return children.asMap().entries.map((e) {
    final i = e.key;
    final child = e.value;
    if (child is SizedBox) return child;
    return SettingsFadeSlideIn(delayMs: i * 50, child: child);
  }).toList();
}
