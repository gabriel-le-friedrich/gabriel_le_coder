import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════
// Canonical, app-wide Material 3 design tokens — colors, radii, spacing,
// text styles, and the shared card/shadow language every redesigned
// screen (Dashboard, Expenses, Pig Growth, and now the rest of the app)
// should read from. This does NOT replace core/theme/app_theme.dart
// (which still drives Flutter's ColorScheme/ThemeData for things like
// default button/input theming) — it is the single source of truth for
// the specific hex values used by every hand-built card/chip/button in
// the redesigned screens, so DashboardPalette/ExpensePalette/
// PigGrowthPalette (and any screen still using ad-hoc literals) can all
// point at the same values instead of each re-declaring slightly
// different near-duplicates.
//
// Values below are exactly the palette specified for the app's Material 3
// redesign: primary green #43A047, light green #E8F5E9, accent orange
// #F9A825, blue #42A5F5, background #FAFAFA, cards white, primary text
// #212121, secondary text #757575, success #4CAF50.
// ══════════════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  static const primaryGreen = Color(0xFF43A047);
  static const darkGreen = Color(0xFF2E7D32);
  static const lightGreen = Color(0xFFE8F5E9);
  static const accentOrange = Color(0xFFF9A825);
  static const blue = Color(0xFF42A5F5);
  static const success = Color(0xFF4CAF50);
  static const warningRed = Color(0xFFEF5350);
  static const danger = Color(0xFFD32F2F);

  // Auth-screen "premium farm hero" palette (login/register/forgot-password/
  // OTP redesign) — accentLime/highlightGold are new; darkGreen/primaryGreen
  // above already match the spec's primary/secondary green exactly, so they
  // are reused rather than duplicated.
  static const accentLime = Color(0xFF8BC34A);
  static const highlightGold = Color(0xFFF4B400);
  static const authBackground = Color(0xFFF8FAF6);

  static const background = Color(0xFFFAFAFA);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFECECEC);

  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
}

/// Corner radii used consistently across every redesigned card/button —
/// 18-20px for cards (per spec), 12-14px for buttons/pills/inputs.
class AppRadius {
  AppRadius._();

  static const card = 20.0;
  static const cardSmall = 16.0;
  static const button = 14.0;
  static const pill = 20.0;
  static const chip = 12.0;
}

/// Spacing scale — 16-20px margins, 16px internal padding, 12px between
/// stacked cards, per spec.
class AppSpacing {
  AppSpacing._();

  static const screenMargin = 16.0;
  static const cardPadding = 18.0;
  static const cardGap = 12.0;
  static const sectionGap = 20.0;
}

/// Type scale: Title 32, Section titles 22, Card values 28, Labels 12-13 —
/// matching the spec's typography hierarchy. Uses the system font (no new
/// font dependency), consistent with how the rest of the app is built.
class AppTextStyles {
  AppTextStyles._();

  static const title = TextStyle(
      fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static const sectionTitle = TextStyle(
      fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static const cardValue = TextStyle(
      fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static const label = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
      letterSpacing: 0.3);
  static const body = TextStyle(fontSize: 14, color: AppColors.textPrimary);
  static const caption =
      TextStyle(fontSize: 11.5, color: AppColors.textSecondary);
}

/// Shared rounded-card decoration — soft shadow, no heavy borders, minimal
/// elevation. The one decoration every StatCard/InfoCard/ChartCard/etc.
/// below (and any screen migrating to them) should use, so "soft shadows,
/// rounded cards, spacious padding" reads identically everywhere.
BoxDecoration appCardDecoration(
    {Color color = AppColors.card,
    double radius = AppRadius.card,
    bool withBorder = false}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: withBorder ? Border.all(color: AppColors.border) : null,
    boxShadow: [
      BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6)),
    ],
  );
}

const appCardPadding = EdgeInsets.all(AppSpacing.cardPadding);

/// Staggered fade+slide card entrance — the same technique already used
/// independently by DashboardPalette/ExpensePalette/PigGrowthPalette,
/// consolidated into one shared implementation so future screens don't
/// need to re-copy the AnimationController boilerplate.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.delayMs = 0});
  final Widget child;
  final int delayMs;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
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

/// Applies a staggered [FadeSlideIn] to a list of children (skipping bare
/// SizedBox spacers) — same helper pattern as expenseAnimatedChildren(),
/// generalized for reuse by any screen.
List<Widget> withStaggeredEntrance(List<Widget> children, {int stepMs = 60}) {
  return children.asMap().entries.map((e) {
    final i = e.key;
    final child = e.value;
    if (child is SizedBox) return child;
    return FadeSlideIn(delayMs: i * stepMs, child: child);
  }).toList();
}

/// Shared shimmer skeleton block — a soft pulsing rounded rectangle used as
/// a loading placeholder in place of a bare CircularProgressIndicator.
/// Originally built as a private `_ShimmerBlock` inside
/// growth_overview_screen.dart; promoted here so any screen's loading
/// state can show a content-shaped skeleton instead of a spinner, without
/// re-declaring the same AnimationController boilerplate.
class ShimmerBlock extends StatefulWidget {
  const ShimmerBlock(
      {super.key, required this.height, this.radius = AppRadius.card});
  final double height;
  final double radius;

  @override
  State<ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0xFFEDEDED), const Color(0xFFF7F7F7),
              _controller.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A ready-made vertical stack of [ShimmerBlock]s — the common shape of a
/// "few cards stacked" loading skeleton, so screens can drop in one widget
/// instead of hand-building a Column of shimmer blocks each time.
class ShimmerListSkeleton extends StatelessWidget {
  const ShimmerListSkeleton({
    super.key,
    this.count = 4,
    this.itemHeight = 96,
    this.gap = AppSpacing.cardGap,
    this.padding = const EdgeInsets.all(AppSpacing.screenMargin),
  });

  final int count;
  final double itemHeight;
  final double gap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        for (var i = 0; i < count; i++) ...[
          ShimmerBlock(height: itemHeight),
          if (i != count - 1) SizedBox(height: gap),
        ],
      ],
    );
  }
}

/// The "Synced with mobile app" banner shown at the top of every
/// redesigned screen — a static reassurance indicator (this app IS the
/// mobile app), not a live connectivity check. Consolidates the
/// independent copies in DashboardPalette/ExpensePalette/etc.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key, this.label = 'Synced with mobile app'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.primaryGreen, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Flexible(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen))),
        ],
      ),
    );
  }
}
