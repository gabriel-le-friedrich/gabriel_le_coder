import 'package:flutter/material.dart';

import '../../../dashboard/presentation/widgets/dashboard_app_bar_actions.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';

// ══════════════════════════════════════════════════════════════════════
// Presentation-only palette for the redesigned Pig Growth module (Pig
// Growth Dashboard / Growth History / Calendar View / Add Pig). Shared by
// all four screens so the look stays consistent without copy-pasting the
// same color constants into each file — mirrors the same pattern already
// used by DashboardPalette for the Dashboard family of screens.
// ══════════════════════════════════════════════════════════════════════
class PigGrowthPalette {
  PigGrowthPalette._();

  // Aligned to the ASF app-wide design system spec (Primary/Secondary
  // Green, neutrals, semantic colors). darkText/grayText are named
  // "primary text"/"secondary text" in that spec but kept under their
  // original names here since every widget in this file already
  // references PigGrowthPalette.darkText/grayText — renaming the fields
  // would mean touching every call site for a cosmetic difference.
  // #6B7280 on this screen's #F7F9F6 background measures ~4.57:1,
  // clearing WCAG AA's 4.5:1 minimum for small text.
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
  static const success = Color(0xFF22C55E);
  static const card = Color(0xFFFFFFFF);
}

BoxDecoration pigGrowthCardDecoration(
    {Color color = PigGrowthPalette.card, double radius = 20}) {
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

const pigGrowthCardPadding = EdgeInsets.all(18);

const pigGrowthSectionTitleStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: PigGrowthPalette.grayText,
    letterSpacing: 0.4);

/// Staggered fade+slide entrance for top-level cards — same technique
/// already used by the redesigned Dashboard/Weight & ADG screens, kept
/// here so every Growth-module screen can share one copy.
class PigGrowthFadeSlideIn extends StatefulWidget {
  const PigGrowthFadeSlideIn(
      {super.key, required this.child, required this.delayMs});
  final Widget child;
  final int delayMs;

  @override
  State<PigGrowthFadeSlideIn> createState() => _PigGrowthFadeSlideInState();
}

class _PigGrowthFadeSlideInState extends State<PigGrowthFadeSlideIn>
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
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        ),
        child: widget.child,
      ),
    );
  }
}

List<Widget> pigGrowthAnimatedChildren(List<Widget> children) {
  return children.asMap().entries.map((e) {
    final i = e.key;
    final child = e.value;
    if (child is SizedBox) return child;
    return PigGrowthFadeSlideIn(delayMs: i * 60, child: child);
  }).toList();
}

/// Shared app bar for every Growth-module screen: hamburger drawer +
/// left-aligned title + PH|FIL/bell/avatar actions, matching the reference
/// design's "Shared Header" spec exactly. Reuses DashboardAppBarActions
/// rather than duplicating the language pill/bell/avatar in every screen.
/// [uid]/[fullName] feed the same shared actions widget the Dashboard and
/// Weight & ADG screens already use; [showDrawerButton] is false for
/// screens reached by pushing (Growth History, Calendar) rather than as a
/// bottom-nav tab, since those have a real back button instead of a drawer.
PreferredSizeWidget pigGrowthAppBar({
  required String title,
  required String uid,
  required String? fullName,
  bool showDrawerButton = true,
  AppLanguage lang = AppLanguage.en,
}) {
  return AppBar(
    backgroundColor: PigGrowthPalette.background,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleSpacing: showDrawerButton ? 4 : null,
    leading: showDrawerButton
        ? Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87),
              tooltip: tr(lang, 'openMenu'),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          )
        : null,
    title: Text(title,
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: Colors.black87)),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: DashboardAppBarActions(uid: uid, fullName: fullName),
      ),
    ],
  );
}
