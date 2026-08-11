// ══════════════════════════════════════════════════════════════════════
// Health Monitoring domain.
//
// Behavior / Appetite / Waste stay single-select (one HealthOption key
// each). Physical Condition is now MULTIPLE select — a farmer can tick
// every symptom actually observed instead of being forced to pick just
// one — so its options are grouped by severity (Healthy Indicators /
// Needs Monitoring / At Risk / Critical) for the redesigned form's
// section headers, and HealthLogEntry.physical is a List<String> of keys
// rather than one key.
//
// Overall status is no longer just "the single highest tier selected" —
// see computeOverallHealthStatus() below for the full priority +
// threshold decision engine (agreed with the farmer app owner after two
// of the original worked examples turned out to contradict each other on
// what a single Critical-tier symptom should do).
// ══════════════════════════════════════════════════════════════════════

/// tier = severity level: 0 Healthy · 1 Needs Monitoring · 2 At Risk ·
/// 3 Critical.
class HealthOption {
  const HealthOption(
      {required this.key,
      required this.icon,
      required this.label,
      this.subtitle = '',
      required this.tier});
  final String key;
  final String icon;
  final String label;
  final String subtitle;
  final int tier;
}

const List<HealthOption> kBehaviorOptions = [
  HealthOption(
      key: 'normal',
      icon: '😊',
      label: 'Normal',
      subtitle: 'Bright & alert, active',
      tier: 0),
  HealthOption(key: 'less_active', icon: '🐖', label: 'Less Active', tier: 1),
  HealthOption(key: 'lethargic', icon: '😔', label: 'Lethargic', tier: 2),
  HealthOption(
      key: 'isolated', icon: '🐖', label: 'Isolated From Group', tier: 2),
  HealthOption(
      key: 'unable_stand', icon: '😫', label: 'Unable to Stand', tier: 3),
];

const List<HealthOption> kAppetiteOptions = [
  HealthOption(key: 'normal', icon: '😊', label: 'Eating Normally', tier: 0),
  HealthOption(key: 'eating_less', icon: '🍽', label: 'Eating Less', tier: 1),
  HealthOption(key: 'no_appetite', icon: '🚫', label: 'No Appetite', tier: 2),
  HealthOption(
      key: 'refusing', icon: '❌', label: 'Refusing Feed and Water', tier: 3),
];

/// Physical Condition — MULTIPLE select. Severity tiers below match the
/// "Healthy Indicators / Needs Monitoring / At Risk / Critical" grouping
/// agreed on for the redesign: a small number of named emergency symptoms
/// (see kEmergencySymptomKeys) always force the overall result to
/// Critical regardless of anything else selected; everything else here
/// only counts toward the tier-count + severity-score rules in
/// computeOverallHealthStatus().
const List<HealthOption> kPhysicalOptions = [
  // Healthy Indicators (tier 0)
  HealthOption(
      key: 'pinkish',
      icon: '🐷',
      label: 'Pinkish Skin',
      subtitle: 'Normal color',
      tier: 0),
  HealthOption(key: 'bright_eyes', icon: '👁', label: 'Bright Eyes', tier: 0),
  HealthOption(
      key: 'bruise_free',
      icon: '✅',
      label: 'Bruise Free',
      subtitle: 'No injuries',
      tier: 0),
  HealthOption(key: 'normal_nose', icon: '👃', label: 'Normal Nose', tier: 0),
  HealthOption(
      key: 'normal_breathing', icon: '🫁', label: 'Normal Breathing', tier: 0),
  HealthOption(
      key: 'normal_walking', icon: '🐖', label: 'Normal Walking', tier: 0),
  // Needs Monitoring (tier 1)
  HealthOption(key: 'watery_eyes', icon: '💧', label: 'Eye Gunk', tier: 1),
  HealthOption(key: 'sneezing', icon: '🤧', label: 'Sneezing', tier: 1),
  HealthOption(
      key: 'mild_nasal', icon: '🟡', label: 'Mild Nasal Discharge', tier: 1),
  HealthOption(
      key: 'minor_bruises', icon: '🟣', label: 'Minor Bruises', tier: 1),
  HealthOption(
      key: 'mild_lameness', icon: '🦵', label: 'Mild Lameness', tier: 1),
  HealthOption(key: 'coughing', icon: '😷', label: 'Coughing', tier: 1),
  HealthOption(
      key: 'labored_breathing',
      icon: '😮‍💨',
      label: 'Labored Breathing',
      tier: 1),
  // At Risk (tier 2)
  HealthOption(key: 'fever', icon: '🌡', label: 'Fever', tier: 2),
  HealthOption(key: 'wounds', icon: '🩹', label: 'Wounds', tier: 2),
  HealthOption(key: 'limping', icon: '🦶', label: 'Limping', tier: 2),
  HealthOption(
      key: 'swollen_joints', icon: '🦴', label: 'Swollen Joints', tier: 2),
  HealthOption(
      key: 'severe_lameness', icon: '🦵', label: 'Severe Lameness', tier: 2),
  HealthOption(
      key: 'severe_swelling',
      icon: '💧',
      label: 'Severe Body Swelling',
      tier: 2),
  // Critical (tier 3)
  HealthOption(
      key: 'severe_labored_breathing',
      icon: '🫁',
      label: 'Severe Labored Breathing',
      tier: 3),
  HealthOption(
      key: 'heavy_bleeding', icon: '🩸', label: 'Heavy Bleeding', tier: 3),
  HealthOption(
      key: 'unable_walk', icon: '🚫', label: 'Unable to Walk', tier: 3),
  HealthOption(key: 'high_fever', icon: '🌡', label: 'High Fever', tier: 3),
  HealthOption(key: 'collapse', icon: '😵', label: 'Collapse', tier: 3),
];

/// Physical options grouped for the redesigned form's section headers —
/// same list as kPhysicalOptions, just partitioned by tier so the UI can
/// render "Healthy Indicators" / "Needs Monitoring" / "At Risk" /
/// "Critical" sections without re-deriving the split at render time.
final List<HealthOption> kPhysicalHealthyGroup =
    kPhysicalOptions.where((o) => o.tier == 0).toList();
final List<HealthOption> kPhysicalMonitoringGroup =
    kPhysicalOptions.where((o) => o.tier == 1).toList();
final List<HealthOption> kPhysicalAtRiskGroup =
    kPhysicalOptions.where((o) => o.tier == 2).toList();
final List<HealthOption> kPhysicalCriticalGroup =
    kPhysicalOptions.where((o) => o.tier == 3).toList();

const List<HealthOption> kWasteOptions = [
  HealthOption(
      key: 'normal',
      icon: '✅',
      label: 'Normal',
      subtitle: 'Solid consistency',
      tier: 0),
  HealthOption(
      key: 'soft_stool', icon: '💩', label: 'Slightly Soft Stool', tier: 1),
  HealthOption(key: 'loose', icon: '⚠️', label: 'Loose/Watery Stool', tier: 2),
  HealthOption(
      key: 'bloody_diarrhea', icon: '🩸', label: 'Bloody Diarrhea', tier: 3),
  HealthOption(key: 'black_stool', icon: '⚫', label: 'Black Stool', tier: 3),
];

HealthOption? findHealthOption(List<HealthOption> opts, String key) {
  for (final o in opts) {
    if (o.key == key) return o;
  }
  return null;
}

enum HealthStatus { healthy, monitor, risk, critical }

class HealthStatusMeta {
  const HealthStatusMeta({required this.emoji, required this.label});
  final String emoji;
  final String label;
}

const Map<HealthStatus, HealthStatusMeta> kHealthStatusMeta = {
  HealthStatus.healthy: HealthStatusMeta(emoji: '🟢', label: 'Healthy'),
  HealthStatus.monitor:
      HealthStatusMeta(emoji: '🟡', label: 'Needs Monitoring'),
  HealthStatus.risk: HealthStatusMeta(emoji: '🟠', label: 'At Risk'),
  HealthStatus.critical: HealthStatusMeta(emoji: '🔴', label: 'Critical'),
};

String healthStatusKey(HealthStatus s) => s.name;

HealthStatus healthStatusFromKey(String key) {
  return HealthStatus.values
      .firstWhere((s) => s.name == key, orElse: () => HealthStatus.healthy);
}

/// Named "immediate emergency" symptoms — selecting ANY of these always
/// forces the overall result to Critical, full stop, no matter what else
/// is selected (matches the "a single life-threatening sign should never
/// be diluted by a pile of healthy observations" requirement). This is a
/// deliberately short, curated list — not simply "every tier-3 option" —
/// agreed on directly with the app owner.
const Set<String> kEmergencySymptomKeys = {
  'unable_stand', // Behavior
  'collapse', // Physical
  'unable_walk', // Physical
  'heavy_bleeding', // Physical
  'high_fever', // Physical
  'severe_labored_breathing', // Physical
};

/// Safety-net totals used only when the count-based rules below don't
/// already decide the result — e.g. many Needs-Monitoring-tier physical
/// symptoms piling up without ever reaching 2 discrete At-Risk items.
/// Deliberately generous defaults; tune if real-world logs show them
/// firing too eagerly (or not eagerly enough).
const int kAtRiskScoreThreshold = 8;
const int kCriticalScoreThreshold = 14;

class HealthAssessment {
  const HealthAssessment({
    required this.status,
    required this.severityScore,
    required this.symptomCount,
    required this.healthyCount,
    required this.monitorCount,
    required this.riskCount,
    required this.criticalCount,
    required this.hasEmergencySymptom,
    required this.reasons,
  });
  final HealthStatus status;
  final int severityScore;
  final int symptomCount;

  /// Per-severity-tier counts across everything selected (Behavior +
  /// Appetite + Waste + every ticked Physical symptom) — powers the
  /// "Severity Counts" breakdown and the Reason bullets below the status
  /// badge.
  final int healthyCount;
  final int monitorCount;
  final int riskCount;
  final int criticalCount;

  /// True when one of the named kEmergencySymptomKeys was selected — kept
  /// distinct from "any tier-3 symptom", since a general Critical-severity
  /// symptom (should more of those be added later) still only feeds the
  /// count/score rules below rather than triggering an immediate
  /// emergency by itself.
  final bool hasEmergencySymptom;

  /// Human-readable bullets explaining why this particular status was
  /// reached — shown under "Reason:" in the form and Health Summary.
  final List<String> reasons;
}

/// The full decision engine: looks at Behavior + Appetite + Waste (one
/// selection each) and every selected Physical symptom together, and
/// applies a priority-ordered set of rules — Critical checks first (so a
/// dangerous symptom can never be hidden by a majority of healthy
/// observations), then At Risk, then Needs Monitoring, with Healthy as
/// the narrow remaining case.
///
/// "Emergency" and "Critical" are deliberately separate concepts here:
/// hasEmergencySymptom (a short, named whitelist — Collapse, Unable to
/// Stand, Unable to Walk, Heavy Bleeding, High Fever, Severe Labored
/// Breathing) always forces Critical and is meant to be surfaced to the
/// farmer the instant one of those is ticked, not just after Save. Any
/// OTHER tier-3 ("Critical-severity") symptom only ever participates in
/// the count/score rules below — it can still land the result on
/// Critical (2+ of them, or 1 + 2 At-Risk symptoms, or the score
/// threshold), it just doesn't short-circuit everything by itself the way
/// a named emergency does.
HealthAssessment computeHealthAssessment({
  required String behavior,
  required String appetite,
  required List<String> physical,
  required String waste,
}) {
  final selected = <HealthOption>[];
  void add(List<HealthOption> opts, String key) {
    final o = findHealthOption(opts, key);
    if (o != null) selected.add(o);
  }

  add(kBehaviorOptions, behavior);
  add(kAppetiteOptions, appetite);
  add(kWasteOptions, waste);
  for (final key in physical) {
    add(kPhysicalOptions, key);
  }

  final healthyCount = selected.where((o) => o.tier == 0).length;
  final monitorCount = selected.where((o) => o.tier == 1).length;
  final riskCount = selected.where((o) => o.tier == 2).length;
  final criticalCount = selected.where((o) => o.tier == 3).length;
  final severityScore = selected.fold<int>(0, (sum, o) => sum + o.tier);

  final hasEmergencySymptom = kEmergencySymptomKeys.contains(behavior) ||
      physical.any(kEmergencySymptomKeys.contains);

  HealthStatus status;
  final reasons = <String>[];

  // 🔴 Critical
  if (hasEmergencySymptom) {
    status = HealthStatus.critical;
    reasons
        .add('🚨 Emergency symptom detected — requires immediate attention.');
  } else if (criticalCount >= 2) {
    status = HealthStatus.critical;
    reasons.add('$criticalCount Critical-severity symptoms detected.');
  } else if (criticalCount >= 1 && riskCount >= 2) {
    status = HealthStatus.critical;
    reasons.add(
        '1 Critical-severity symptom + $riskCount At Risk symptoms detected.');
  } else if (severityScore >= kCriticalScoreThreshold) {
    status = HealthStatus.critical;
    reasons.add(
        'Total severity score ($severityScore) reached the Critical threshold.');
  }
  // 🟠 At Risk — 2+ At Risk symptoms, OR any lone Critical-tier symptom
  // that didn't already qualify as a full Critical above (still floors at
  // least to At Risk rather than being silently diluted to Monitoring),
  // OR the total severity score alone is high enough.
  else if (riskCount >= 2 ||
      criticalCount >= 1 ||
      severityScore >= kAtRiskScoreThreshold) {
    status = HealthStatus.risk;
    if (riskCount > 0)
      reasons.add(
          '$riskCount At Risk symptom${riskCount == 1 ? '' : 's'} detected.');
    if (monitorCount > 0)
      reasons.add(
          '$monitorCount Needs Monitoring symptom${monitorCount == 1 ? '' : 's'} detected.');
    if (criticalCount > 0)
      reasons
          .add('1 Critical-severity symptom present (not an emergency type).');
    reasons.add('No emergency symptoms found.');
  }
  // 🟢 Healthy — no At Risk/Critical at all, healthy observations
  // outnumber Needs-Monitoring ones, and Needs Monitoring stays small.
  else if (riskCount == 0 &&
      criticalCount == 0 &&
      healthyCount > monitorCount &&
      monitorCount <= 2) {
    status = HealthStatus.healthy;
    reasons.add(
        '$healthyCount healthy indicator${healthyCount == 1 ? '' : 's'} selected.');
    if (monitorCount > 0)
      reasons.add(
          '$monitorCount Needs Monitoring symptom${monitorCount == 1 ? '' : 's'} — within normal range.');
    reasons.add('No At Risk or Critical symptoms found.');
  }
  // 🟡 Needs Monitoring — the remaining catch-all.
  else {
    status = HealthStatus.monitor;
    reasons.add(
        '$monitorCount Needs Monitoring symptom${monitorCount == 1 ? '' : 's'} detected.');
    if (healthyCount > 0)
      reasons.add(
          '$healthyCount healthy indicator${healthyCount == 1 ? '' : 's'} also selected.');
    reasons.add('No At Risk or Critical symptoms found.');
  }

  return HealthAssessment(
    status: status,
    severityScore: severityScore,
    symptomCount: selected.length,
    healthyCount: healthyCount,
    monitorCount: monitorCount,
    riskCount: riskCount,
    criticalCount: criticalCount,
    hasEmergencySymptom: hasEmergencySymptom,
    reasons: reasons,
  );
}

/// Back-compat convenience — just the status, for call sites that don't
/// need the score/count breakdown.
HealthStatus computeHealthStatus({
  required String behavior,
  required String appetite,
  required List<String> physical,
  required String waste,
}) {
  return computeHealthAssessment(
          behavior: behavior,
          appetite: appetite,
          physical: physical,
          waste: waste)
      .status;
}

class HealthRecommendation {
  const HealthRecommendation({required this.title, required this.body});
  final String title;
  final List<String> body;
}

/// The main, always-shown recommendation block — driven purely by the
/// final overall status, matching the "Smart Recommendations" copy
/// agreed on for the redesign.
HealthRecommendation computeStatusRecommendation(HealthStatus status) {
  switch (status) {
    case HealthStatus.healthy:
      return const HealthRecommendation(
        title: '✅ Pig appears healthy.',
        body: ['Continue normal feeding and routine monitoring.'],
      );
    case HealthStatus.monitor:
      return const HealthRecommendation(
        title: '🟡 Observe the pig closely.',
        body: [
          'Repeat another health assessment tomorrow.',
          'Watch food and water intake.',
        ],
      );
    case HealthStatus.risk:
      return const HealthRecommendation(
        title: '🟠 Pig shows concerning symptoms.',
        body: [
          'Separate from healthy pigs.',
          'Increase monitoring.',
          'Consider contacting a veterinarian.',
        ],
      );
    case HealthStatus.critical:
      return const HealthRecommendation(
        title: '🔴 Pig requires immediate veterinary attention.',
        body: [
          'Isolate immediately.',
          'Avoid transporting.',
          'Begin emergency care.',
        ],
      );
  }
}

/// Supplementary contextual tip — shown ALONGSIDE (not instead of) the
/// status recommendation above when Loose/Watery waste is paired with any
/// reduced appetite. Unchanged logic from the original single-select
/// form, just kept as a secondary callout in the redesign.
HealthRecommendation? computeDigestiveTip(
    {required String appetite, required String waste}) {
  final appTier = findHealthOption(kAppetiteOptions, appetite)?.tier ?? 0;
  if (waste == 'loose' && appTier >= 1) {
    return const HealthRecommendation(
      title: '⚠️ Possible Digestive Problem',
      body: [
        'Ensure clean drinking water.',
        'Reduce feed by 20%.',
        'Monitor hydration.',
        'Observe for the next 24 hours.',
        'Consult a veterinarian if symptoms persist.',
      ],
    );
  }
  return null;
}

/// One saved health observation. `physical` is now a list of every
/// symptom key the farmer selected (was a single key) — fromJson accepts
/// either a JSON array (current shape) or a single legacy string (any
/// observation saved before this redesign), so old logs keep rendering
/// correctly instead of erroring out.
class HealthLogEntry {
  const HealthLogEntry({
    required this.id,
    required this.day,
    required this.date,
    required this.time,
    required this.timestamp,
    required this.behavior,
    required this.appetite,
    required this.physical,
    required this.waste,
    this.notes = '',
    required this.status,
    this.severityScore = 0,
    this.healthyCount = 0,
    this.monitorCount = 0,
    this.riskCount = 0,
    this.criticalCount = 0,
    this.batchName = '',
    this.pigName = '',
    this.assessedBy = '',
    this.pigId,
    this.sessionId,
    String? updatedAt,
  }) : _updatedAt = updatedAt;

  final int id;
  final int day;
  final String date; // display string, e.g. "July 20, 2026"
  final String time; // display string, e.g. "8:15 AM"
  final String
      timestamp; // ISO 8601 — the real ordering key (see getLatestHealthLog())
  final String behavior;
  final String appetite;
  final List<String> physical;
  final String waste;
  final String notes;
  final HealthStatus status;
  final int severityScore;

  /// Snapshot of HealthAssessment's per-tier counts at save time — stored
  /// (not just recomputed live) so historical logs keep their original
  /// breakdown even if a future update re-tiers an option, and so
  /// analytics/trend features can read counts directly without
  /// recomputing from raw keys.
  final int healthyCount;
  final int monitorCount;
  final int riskCount;
  final int criticalCount;

  /// Snapshot of the batch/pig identity at the moment this was saved (from
  /// PigBatchProfile) — this app monitors health at the flock/batch level
  /// rather than per-individual-pig, so these are traceability metadata,
  /// not a "which pig is this about" selector.
  final String batchName;
  final String pigName;

  /// Optional free-text name of whoever performed the assessment —
  /// defaults to the signed-in farmer's profile name but is editable.
  final String assessedBy;

  /// Which real pig (Pig.id) this specific check belongs to — added for the
  /// Health Monitor redesign's "Specific Pig" / "Overall Herd" modes. Null
  /// on every log saved before this field existed (the app previously only
  /// tracked health at the flock/batch level — see batchName/pigName above)
  /// and on any future flock-level check a farmer chooses not to attribute
  /// to one pig. Never backfilled/guessed for old rows.
  final String? pigId;

  /// Groups the individual per-pig [HealthLogEntry] rows created together
  /// during one "Overall Herd" run, purely for aggregating a Herd Health
  /// Summary afterward — this is metadata only, never a substitute record.
  /// Each pig in a herd run still gets its own real, independently valid
  /// HealthLogEntry; nothing is ever stored against a fake "herd pig".
  final String? sessionId;
  final String? _updatedAt;

  String get updatedAt => _updatedAt ?? timestamp;

  /// Every selected physical symptom's display label, comma-joined — for
  /// list rows, CSV/PDF export, and search.
  String get physicalLabel {
    if (physical.isEmpty) return '—';
    return physical
        .map((k) => findHealthOption(kPhysicalOptions, k)?.label ?? k)
        .join(', ');
  }

  HealthRecommendation get statusRecommendation =>
      computeStatusRecommendation(status);
  HealthRecommendation? get digestiveTip =>
      computeDigestiveTip(appetite: appetite, waste: waste);

  HealthLogEntry copyWith({
    String? behavior,
    String? appetite,
    List<String>? physical,
    String? waste,
    String? notes,
    HealthStatus? status,
    int? severityScore,
    int? healthyCount,
    int? monitorCount,
    int? riskCount,
    int? criticalCount,
    String? batchName,
    String? pigName,
    String? assessedBy,
    String? pigId,
    String? sessionId,
    String? updatedAt,
  }) {
    return HealthLogEntry(
      id: id,
      day: day,
      date: date,
      time: time,
      timestamp: timestamp,
      behavior: behavior ?? this.behavior,
      appetite: appetite ?? this.appetite,
      physical: physical ?? this.physical,
      waste: waste ?? this.waste,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      severityScore: severityScore ?? this.severityScore,
      healthyCount: healthyCount ?? this.healthyCount,
      monitorCount: monitorCount ?? this.monitorCount,
      riskCount: riskCount ?? this.riskCount,
      criticalCount: criticalCount ?? this.criticalCount,
      batchName: batchName ?? this.batchName,
      pigName: pigName ?? this.pigName,
      assessedBy: assessedBy ?? this.assessedBy,
      pigId: pigId ?? this.pigId,
      sessionId: sessionId ?? this.sessionId,
      updatedAt: updatedAt ?? _updatedAt,
    );
  }

  static List<String> _parsePhysical(dynamic raw) {
    if (raw == null) return const ['pinkish'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) return raw.isEmpty ? const [] : [raw];
    return const [];
  }

  factory HealthLogEntry.fromJson(Map<String, dynamic> json) => HealthLogEntry(
        id: (json['id'] as num?)?.toInt() ?? 0,
        day: (json['day'] as num?)?.toInt() ?? 1,
        date: (json['date'] as String?) ?? '',
        time: (json['time'] as String?) ?? '',
        timestamp:
            (json['timestamp'] as String?) ?? DateTime.now().toIso8601String(),
        behavior: (json['behavior'] as String?) ?? 'normal',
        appetite: (json['appetite'] as String?) ?? 'normal',
        physical: _parsePhysical(json['physical']),
        waste: (json['waste'] as String?) ?? 'normal',
        notes: (json['notes'] as String?) ?? '',
        status: healthStatusFromKey((json['status'] as String?) ?? 'healthy'),
        severityScore: (json['severityScore'] as num?)?.toInt() ?? 0,
        healthyCount: (json['healthyCount'] as num?)?.toInt() ?? 0,
        monitorCount: (json['monitorCount'] as num?)?.toInt() ?? 0,
        riskCount: (json['riskCount'] as num?)?.toInt() ?? 0,
        criticalCount: (json['criticalCount'] as num?)?.toInt() ?? 0,
        batchName: (json['batchName'] as String?) ?? '',
        pigName: (json['pigName'] as String?) ?? '',
        assessedBy: (json['assessedBy'] as String?) ?? '',
        pigId: json['pigId'] as String?,
        sessionId: json['sessionId'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        'date': date,
        'time': time,
        'timestamp': timestamp,
        'behavior': behavior,
        'appetite': appetite,
        'physical': physical,
        'waste': waste,
        'notes': notes,
        'status': healthStatusKey(status),
        'severityScore': severityScore,
        'healthyCount': healthyCount,
        'monitorCount': monitorCount,
        'riskCount': riskCount,
        'criticalCount': criticalCount,
        'batchName': batchName,
        'pigName': pigName,
        'assessedBy': assessedBy,
        'pigId': pigId,
        'sessionId': sessionId,
        'updatedAt': updatedAt,
      };
}

/// Thrown by [HealthRepository.addHealthLog]/[updateHealthLog] when a
/// constructed entry fails [validateHealthLogEntry] — surfaced to the
/// Health Form's existing save try/catch the same way any other save
/// failure is, so no new UI is needed to reject invalid data.
class InvalidHealthLogEntryException implements Exception {
  InvalidHealthLogEntryException(this.reason);
  final String reason;
  @override
  String toString() => 'InvalidHealthLogEntryException: $reason';
}

/// Defense-in-depth validation gate, checked right before a [HealthLogEntry]
/// is persisted. Everything here is already guaranteed by construction in
/// the normal add/edit flow (day comes from a clamped production-day
/// counter, severity counts come from [computeHealthAssessment], status is
/// a real [HealthStatus] enum member rather than a raw string) — but
/// validating explicitly at the write boundary means a bug anywhere
/// upstream can never actually persist a corrupted row. This is the write-
/// side mirror of the read-side principle [HealthRepository.getHealthLogs]
/// already applies: reject/skip invalid data rather than storing or
/// loading it. Returns null when [entry] is valid, otherwise a short,
/// human-readable reason.
String? validateHealthLogEntry(HealthLogEntry entry) {
  if (entry.day <= 0) return 'Production day must be positive.';
  if (entry.timestamp.isEmpty || DateTime.tryParse(entry.timestamp) == null) {
    return 'Timestamp is invalid.';
  }
  if (entry.severityScore < 0 ||
      entry.healthyCount < 0 ||
      entry.monitorCount < 0 ||
      entry.riskCount < 0 ||
      entry.criticalCount < 0) {
    return 'Severity counts must be non-negative.';
  }
  if (entry.behavior.trim().isEmpty ||
      entry.appetite.trim().isEmpty ||
      entry.waste.trim().isEmpty) {
    return 'Required fields (behavior, appetite, waste) must be present.';
  }
  if (entry.physical.toSet().length != entry.physical.length) {
    return 'Physical symptom list contains duplicate entries.';
  }
  // entry.status is typed as HealthStatus (a Dart enum), not a raw string,
  // so an out-of-range value can't actually reach this point through the
  // normal save flow — checked anyway for explicit defense-in-depth.
  if (!HealthStatus.values.contains(entry.status))
    return 'Status is not a recognized health status.';
  return null;
}
