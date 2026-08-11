import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

// ══════════════════════════════════════════════════════════════════════
// Shared, presentation-only Flutter widgets used across every screen.
// None of these widgets know about Riverpod providers, repositories, or
// sync — every one of them takes plain data via constructor parameters
// and fires plain VoidCallback/ValueChanged callbacks, exactly like the
// screen-specific widgets they're replacing (_SummaryCard, _MiniStat,
// etc.) already did. Screens keep 100% of their existing provider wiring
// and business logic; only the widget tree underneath changes to read
// from this shared library instead of re-declaring near-identical
// Container/BoxDecoration/Text trees per screen.
// ══════════════════════════════════════════════════════════════════════

/// General-purpose rounded card — the base every other card below is
/// built on. Use directly for simple content; use StatCard/InfoCard/
/// ChartCard/ProgressCard for their specific shapes.
class CustomCard extends StatelessWidget {
  const CustomCard({
    super.key,
    required this.child,
    this.padding = appCardPadding,
    this.radius = AppRadius.card,
    this.color = AppColors.card,
    this.semanticsLabel,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: appCardDecoration(color: color, radius: radius),
      padding: padding,
      child: child,
    );
    if (semanticsLabel == null) return card;
    return Semantics(
        label: semanticsLabel,
        container: true,
        child: ExcludeSemantics(child: card));
  }
}

/// A single hero statistic tile — icon badge, label, big value, colored
/// caption. This is the generalized form of Dashboard's `_SummaryCard`:
/// same overflow-safe SingleChildScrollView + maxLines/ellipsis approach
/// (kept deliberately, since that's what fixed the real BOTTOM OVERFLOWED
/// reports on-device at large accessibility font scales), same
/// accessibility Semantics wrapping — just usable from any screen instead
/// of being private to the Dashboard file.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.caption,
    required this.captionColor,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final String caption;
  final Color captionColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value, $caption',
      container: true,
      child: Container(
        decoration: appCardDecoration(),
        padding: appCardPadding,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(AppRadius.chip)),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 8),
                Text(label,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(caption,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: captionColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A slim label/value row card — the generalized form of Dashboard's
/// `_MiniStat` (used there for FCR/Growth%), usable anywhere a compact
/// "label ... value" strip is needed.
class InfoCard extends StatelessWidget {
  const InfoCard(
      {super.key,
      required this.label,
      required this.value,
      this.valueColor = AppColors.textPrimary});
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      container: true,
      child: Container(
        decoration: appCardDecoration(radius: AppRadius.cardSmall),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flexible+ellipsis on the label (not a bare Text) — this
              // card is used inside a half-width Expanded slot (e.g.
              // Dashboard's FCR/Growth % row), where a longer label
              // (translated Filipino text is often longer than the
              // English original) plus the value could exceed the
              // available width and overflow the RenderFlex on the right.
              // Caught by test/dashboard_responsive_test.dart's small-phone
              // sweep in both English and Filipino.
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: valueColor)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card with a header row (title + optional "Full tracker →" style link)
/// and arbitrary body content below — the generalized shape of Weight
/// Progress / Growth Timeline / any card that pairs a section header with
/// a chart or list.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary))),
              if (actionLabel != null)
                Semantics(
                  button: true,
                  label: actionLabel,
                  child: InkWell(
                    onTap: onAction,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Text(actionLabel!,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryGreen)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// A labeled progress bar with a trailing badge/percentage — the
/// generalized shape of Today's Tasks' "0/10" progress bar and every
/// other status-bar-with-percentage across the app (health severity,
/// growth %, feed completion, etc).
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.title,
    required this.progress,
    this.badgeText,
    this.badgeColor = AppColors.lightGreen,
    this.badgeTextColor = AppColors.darkGreen,
    this.barColor = AppColors.primaryGreen,
    this.semanticsLabel,
    this.semanticsValue,
  });

  final String title;
  final double progress; // 0.0–1.0
  final String? badgeText;
  final Color badgeColor;
  final Color badgeTextColor;
  final Color barColor;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            if (badgeText != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(AppRadius.chip)),
                child: Text(badgeText!,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          label: semanticsLabel ?? title,
          value: semanticsValue ?? '${(progress * 100).round()}%',
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: AppColors.background,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small colored pill used for statuses ("Healthy"/"At Risk"/"Active"/
/// "Sold"/etc) — one shared implementation instead of each screen
/// building its own status chip inline.
class StatusChip extends StatelessWidget {
  const StatusChip(
      {super.key, required this.label, required this.color, this.background});
  final String label;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// A left-aligned section title with the app's standard 22px/bold style —
/// use above any group of cards that needs a heading (e.g. "Recent
/// Entries", "Vet Contacts", "Weekly Photos").
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.sectionTitle.copyWith(fontSize: 18)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Standard filled primary button — 48dp min height, 14px radius, matches
/// every FilledButton already used for Save/Log Today/View All actions.
/// Shows a small spinner in place of its label when [loading] is true,
/// and announces the loading state via a live Semantics region — same
/// pattern already applied to every Save button in the accessibility pass.
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
    this.icon,
    this.backgroundColor = AppColors.primaryGreen,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? loadingLabel;
  final IconData? icon;
  final Color backgroundColor;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                color: outlined ? backgroundColor : Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8)
              ],
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          );

    final button = outlined
        ? OutlinedButton(
            onPressed: loading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: backgroundColor,
              side: BorderSide(color: backgroundColor),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
            child: child,
          )
        : FilledButton(
            onPressed: loading ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: backgroundColor,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
            child: child,
          );

    return Semantics(
      button: true,
      label: loading ? (loadingLabel ?? label) : label,
      liveRegion: loading,
      child: button,
    );
  }
}

/// Standard text input field — filled, 12px rounded border, matching the
/// app's InputDecorationTheme. A thin wrapper so form screens can share
/// one call site for label/hint/validator/focus wiring instead of
/// repeating the same TextFormField configuration.
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Shows a standard centered dialog with a title, message, and
/// Cancel/Confirm actions — consolidates the Confirm-before-destructive-
/// action dialogs (delete pig, delete expense, call veterinarian, etc.)
/// used throughout the app into one call site.
Future<bool> showCustomConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel)),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor:
                  destructive ? AppColors.danger : AppColors.primaryGreen),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
