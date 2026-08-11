import 'package:flutter/material.dart';

import '../../domain/health_calculations.dart';
import '../../domain/health_status_colors.dart';
import '../theme/health_monitor_palette.dart';

// ══════════════════════════════════════════════════════════════════════
// Shared building blocks for the redesigned Health Monitor module —
// reused by the Home hub, Specific Pig picker, Overall Herd flow, and
// Herd Health Summary so the "grouped white card" look stays identical
// everywhere instead of being hand-built per screen. Purely
// presentational: every widget here just renders whatever data/callbacks
// its caller passes in — no health logic lives here.
// ══════════════════════════════════════════════════════════════════════

class HealthSectionLabel extends StatelessWidget {
  const HealthSectionLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(label, style: healthSectionTitleStyle),
    );
  }
}

/// One of the four "Today's Overview" tiles — Healthy / Needs Monitoring /
/// At Risk / Critical / Not Yet Checked, real counts only, never a
/// hardcoded example value.
class HealthOverviewTile extends StatelessWidget {
  const HealthOverviewTile({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    this.icon,
  });
  final String label;
  final int count;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: healthCardDecoration(radius: 14),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
          ] else
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(height: 6),
          Text('$count',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: HealthMonitorPalette.grayText)),
        ],
      ),
    );
  }
}

/// Small status pill using the app's one true [kHealthStatusColor] set —
/// never a second, redeclared color for the same status.
class HealthStatusChip extends StatelessWidget {
  const HealthStatusChip({super.key, required this.status, this.dense = false});
  final HealthStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = kHealthStatusColor[status]!;
    final meta = kHealthStatusMeta[status]!;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(meta.label,
              style: TextStyle(
                  fontSize: dense ? 10.5 : 11.5,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

/// Large mode-selection card ("Specific Pig" / "Overall Herd") — selected
/// state gets a green border/tint/check, matching the redesign spec.
class MonitoringModeCard extends StatelessWidget {
  const MonitoringModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? HealthMonitorPalette.lightGreen : HealthMonitorPalette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? HealthMonitorPalette.primaryGreen : HealthMonitorPalette.border,
              width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon,
                    size: 28,
                    color: selected
                        ? HealthMonitorPalette.primaryGreen
                        : HealthMonitorPalette.grayText),
                if (selected)
                  const Icon(Icons.check_circle,
                      color: HealthMonitorPalette.primaryGreen, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: HealthMonitorPalette.darkText)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11.5, color: HealthMonitorPalette.grayText)),
          ],
        ),
      ),
    );
  }
}

/// One selectable pig row — search-result / checkbox-list styling shared
/// by the Specific Pig picker (single-select) and the Overall Herd picker
/// (multi-select), so both flows look identical apart from the
/// leading control.
class PigPickerTile extends StatelessWidget {
  const PigPickerTile({
    super.key,
    required this.imageWidget,
    required this.name,
    required this.pigId,
    required this.breed,
    required this.selected,
    required this.onTap,
    this.trailing,
  });
  final Widget imageWidget;
  final String name;
  final String pigId;
  final String breed;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? HealthMonitorPalette.lightGreen : HealthMonitorPalette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? HealthMonitorPalette.primaryGreen : HealthMonitorPalette.border,
              width: selected ? 1.4 : 1),
        ),
        child: Row(
          children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 44, height: 44, child: imageWidget)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: HealthMonitorPalette.darkText)),
                  const SizedBox(height: 2),
                  Text('$pigId · $breed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: HealthMonitorPalette.grayText)),
                ],
              ),
            ),
            trailing ??
                (selected
                    ? const Icon(Icons.check_circle,
                        color: HealthMonitorPalette.primaryGreen, size: 22)
                    : const Icon(Icons.radio_button_unchecked,
                        color: HealthMonitorPalette.border, size: 22)),
          ],
        ),
      ),
    );
  }
}
