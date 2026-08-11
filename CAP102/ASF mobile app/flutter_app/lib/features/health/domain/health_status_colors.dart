// ══════════════════════════════════════════════════════════════════════
// Centralized Health Status colors — EXACT hex values agreed with the
// farmer app owner, so a status always reads the same color everywhere
// it appears: the status badge, severity bar, History cards, Dashboard
// summaries, and PDF/CSV exports. Any screen that colors a HealthStatus
// should read from here rather than defining its own palette.
//
//   🟢 Healthy         #4CAF50
//   🟡 Needs Monitoring #FFC107
//   🟠 At Risk          #FF9800
//   🔴 Critical         #F44336
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import 'health_calculations.dart';

const Map<HealthStatus, Color> kHealthStatusColor = {
  HealthStatus.healthy: Color(0xFF4CAF50),
  HealthStatus.monitor: Color(0xFFFFC107),
  HealthStatus.risk: Color(0xFFFF9800),
  HealthStatus.critical: Color(0xFFF44336),
};

/// Same values as raw ARGB ints, for contexts that can't (or shouldn't)
/// depend on Flutter's Color type — e.g. building a `pw.PdfColor` for PDF
/// export (see health_export.dart) without importing package:flutter there.
const Map<HealthStatus, int> kHealthStatusColorValue = {
  HealthStatus.healthy: 0xFF4CAF50,
  HealthStatus.monitor: 0xFFFFC107,
  HealthStatus.risk: 0xFFFF9800,
  HealthStatus.critical: 0xFFF44336,
};
