import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/settings_palette.dart';

// ══════════════════════════════════════════════════════════════════════
// Shared building blocks for the redesigned Settings module — reused by
// the main Settings screen, Profile & Farm, Synchronization, Data
// Management, Offline Mode, Privacy & Security, and Help & Support screens
// so the "grouped card of tappable rows" look stays identical everywhere
// instead of being hand-built per screen. Purely presentational: every
// widget here just renders whatever data/callbacks its caller passes in.
// ══════════════════════════════════════════════════════════════════════

/// Uppercase gray section label — ACCOUNT / DATA & SYNCHRONIZATION /
/// SECURITY & SUPPORT.
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(label, style: settingsSectionTitleStyle),
    );
  }
}

/// A rounded white card that groups a list of [SettingsTile]s with a thin
/// divider between each — the "Profile & Farm / Notifications / Language /
/// Appearance" style grouping from the spec, so callers just pass tiles
/// instead of hand-wiring dividers/padding per section.
class SettingsGroupCard extends StatelessWidget {
  const SettingsGroupCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: settingsCardDecoration(radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, indent: 18, endIndent: 18),
          ],
        ],
      ),
    );
  }
}

/// One tappable settings row — icon in a tinted circle, title, optional
/// description, and either a trailing value chip/text or a plain chevron.
/// Meets the ~48px minimum touch target called for by the spec.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconColor,
    this.iconBackground,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final Color? iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = iconColor ?? SettingsPalette.primaryGreen;
    final bg = iconBackground ?? SettingsPalette.lightGreen;
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title. $subtitle',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 19, color: fg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: iconColor ?? SettingsPalette.darkText)),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: SettingsPalette.grayText)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing ??
                    const Icon(Icons.chevron_right,
                        color: SettingsPalette.grayText, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The small green "current value" pill used for Language/Appearance rows
/// (e.g. "English", "System"), paired with a chevron.
class SettingsValueTrailing extends StatelessWidget {
  const SettingsValueTrailing({super.key, required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: SettingsPalette.lightGreen,
              borderRadius: BorderRadius.circular(20)),
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SettingsPalette.primaryGreen)),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right,
            color: SettingsPalette.grayText, size: 22),
      ],
    );
  }
}

/// Small status pill — "Active Account", "Online"/"Offline", etc. [dot]
/// controls whether a small colored dot precedes the label.
class SettingsStatusChip extends StatelessWidget {
  const SettingsStatusChip({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    this.dot = true,
  });
  final String label;
  final Color foreground;
  final Color background;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: foreground, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: foreground)),
        ],
      ),
    );
  }
}

/// The farmer's real profile photo (local file or remote URL, matching how
/// _ProfileAvatar in profile_edit_screen.dart already resolves the same
/// [imagePath] value) or an initials circle when none exists yet — used by
/// the Settings header, Farmer Profile Card, and the Profile & Farm header.
/// This NEVER reads pig data; [imagePath]/[displayName] always come from the
/// authenticated user's own profile (userProfileProvider/ProfileFormState).
class SettingsAvatar extends StatelessWidget {
  const SettingsAvatar({
    super.key,
    required this.imagePath,
    required this.displayName,
    this.radius = 22,
  });
  final String? imagePath;
  final String displayName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    ImageProvider? provider;
    final path = imagePath;
    if (path != null && path.isNotEmpty) {
      provider =
          path.startsWith('http') ? NetworkImage(path) : FileImage(File(path));
    }
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'F';
    return CircleAvatar(
      radius: radius,
      backgroundColor: SettingsPalette.primaryGreen,
      backgroundImage: provider,
      child: provider == null
          ? Text(initial,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.8))
          : null,
    );
  }
}
