import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════
// Presentation-only palette for the redesigned Dashboard family of screens
// (Dashboard / Tasks / Feeding / Growth Overview / Calendar). This is
// deliberately NOT a change to core/theme/app_theme.dart — AppTheme.light/
// dark drive every other screen in the app (Auth, Onboarding, Settings,
// Growth, Expenses, Health, Pigs) and this redesign pass is scoped to the
// Dashboard's own UI only, per the "only redesign the interface, don't
// touch anything else" instruction. Values below are the exact hex codes
// requested for the new dashboard look.
// ══════════════════════════════════════════════════════════════════════
class DashboardPalette {
  DashboardPalette._();

  static const primaryGreen = Color(0xFF4CAF50);
  static const darkGreen = Color(0xFF2E7D32);
  static const lightGreen = Color(0xFFE8F5E9);
  static const accentOrange = Color(0xFFFFB74D);
  static const warningRed = Color(0xFFEF5350);
  static const background = Color(0xFFF7F8FA);
  static const card = Color(0xFFFFFFFF);
  // Contrast fix: the original 0xFF8A8F98 measures ~3.2:1 against this
  // screen family's light backgrounds (#F7F8FA/#F8F9FA) — below WCAG AA's
  // 4.5:1 minimum for normal-size text, which is exactly what made labels
  // like "Growth Progress"/"ADG Trend"/"FCR Trend" read as washed-out gray
  // bordering on unreadable. This value keeps the same blue-gray hue, just
  // darkened enough to clear ~5.5:1.
  static const textGray = Color(0xFF5F6570);
}

/// Shared rounded-card decoration used across every redesigned Dashboard
/// widget, so spacing/radius/shadow stay consistent without copy-pasting a
/// BoxDecoration literal in every file.
BoxDecoration dashboardCardDecoration(
    {Color color = DashboardPalette.card, double radius = 20}) {
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

const dashboardCardPadding = EdgeInsets.all(18);
