import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/presentation/widgets/dashboard_app_bar_actions.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';

// ══════════════════════════════════════════════════════════════════════
// Presentation-only palette for the redesigned Expense & ROI screen —
// mirrors the same per-screen-family palette pattern already used by
// PigGrowthPalette/DashboardPalette (own color constants + card decoration
// + sync banner + fade-slide entrance + shared app bar helper), rather than
// reusing another screen's palette whose spec doesn't match this one
// (brown highlight card, green accent, no orange/red-poor-performance
// scheme). Font stays the app's current default (no new dependency) —
// see the file header note in expenses_screen.dart.
// ══════════════════════════════════════════════════════════════════════
class ExpensePalette {
  ExpensePalette._();

  static const primaryGreen = Color(0xFF4CAF50);
  static const brown = Color(0xFF7B3F00);
  static const background = Color(0xFFF7F8FA);
  static const card = Color(0xFFFFFFFF);
  static const darkText = Color(0xFF222222);
  // Contrast fix: 0xFF757575 measures ~4.36:1 against this screen's
  // #F7F8FA background — under WCAG AA's 4.5:1 minimum for the
  // 12.5px-bold section-title labels that use this color. 0xFF616161
  // (Material "grey 700") clears ~5.8:1. See growth_screen.dart's
  // identical fix for the same measured issue.
  static const grayText = Color(0xFF616161);
  static const border = Color(0xFFECECEC);
  static const red = Color(0xFFD32F2F);

  /// One color per ExpenseCategory (feed/medicine/vaccines/vitamins/
  /// transportation/labor/utilities/equipment/other), in enum order — used
  /// for both the breakdown progress bars and the recent-entry icons.
  /// Categories are whatever the real data contains (see
  /// categoryBreakdown()), not a fixed set of four — the mockup's sample
  /// data happened to only show four, but any of the app's nine categories
  /// gets a consistent color here.
  static const categoryColors = <Color>[
    Color(0xFF4CAF50), // feed — green
    Color(0xFFD32F2F), // medicine — red
    Color(0xFF9C27B0), // vaccines — purple
    Color(0xFF2196F3), // vitamins/supplements — blue
    Color(0xFF00897B), // transportation — teal
    Color(0xFF5D4037), // labor — brown
    Color(0xFFFFC107), // utilities — amber
    Color(0xFF607D8B), // equipment — blue-grey
    Color(0xFFFB8C00), // other — orange
  ];
}

BoxDecoration expenseCardDecoration(
    {Color color = ExpensePalette.card, double radius = 20}) {
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

const expenseCardPadding = EdgeInsets.all(18);

const expenseSectionTitleStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: ExpensePalette.grayText,
    letterSpacing: 0.4);

/// Static "Synced with mobile app" banner — same reassuring, always-on
/// indicator as the other redesigned screens (this app IS the mobile app),
/// not a live connectivity check.
class ExpenseSyncBanner extends ConsumerWidget {
  const ExpenseSyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC8E6C9))),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: ExpensePalette.primaryGreen, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(tr(lang, 'syncedWithMobileApp'),
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: ExpensePalette.primaryGreen)),
        ],
      ),
    );
  }
}

/// Staggered fade+slide card entrance — same technique already used by
/// every other redesigned screen, kept as a local copy per that
/// established pattern (each screen family owns its palette file).
class ExpenseFadeSlideIn extends StatefulWidget {
  const ExpenseFadeSlideIn(
      {super.key, required this.child, required this.delayMs});
  final Widget child;
  final int delayMs;

  @override
  State<ExpenseFadeSlideIn> createState() => _ExpenseFadeSlideInState();
}

class _ExpenseFadeSlideInState extends State<ExpenseFadeSlideIn>
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

List<Widget> expenseAnimatedChildren(List<Widget> children) {
  return children.asMap().entries.map((e) {
    final i = e.key;
    final child = e.value;
    if (child is SizedBox) return child;
    return ExpenseFadeSlideIn(delayMs: i * 60, child: child);
  }).toList();
}

/// Shared app bar: hamburger drawer + centered title + PH|FIL/bell/avatar +
/// an overflow menu for Export CSV/PDF (kept reachable per the user's
/// choice, just moved out of the pixel-perfect header row into a menu).
PreferredSizeWidget expenseAppBar({
  required String uid,
  required String? fullName,
  required VoidCallback onExportCsv,
  required VoidCallback onExportPdf,
  bool showNotificationBadge = false,
  AppLanguage lang = AppLanguage.en,
}) {
  return AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    leading: Builder(
      builder: (context) => IconButton(
        icon: const Icon(Icons.menu, color: Colors.black87),
        tooltip: tr(lang, 'openMenu'),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
    ),
    title: Text(tr(lang, 'expenseRoiTitle'),
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: Colors.black87)),
    actions: [
      DashboardAppBarActions(
          uid: uid,
          fullName: fullName,
          showNotificationBadge: showNotificationBadge),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.black87),
        onSelected: (v) {
          if (v == 'csv') onExportCsv();
          if (v == 'pdf') onExportPdf();
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'csv', child: Text(tr(lang, 'exportCsv'))),
          PopupMenuItem(value: 'pdf', child: Text(tr(lang, 'exportPdf'))),
        ],
      ),
      const SizedBox(width: 4),
    ],
  );
}
