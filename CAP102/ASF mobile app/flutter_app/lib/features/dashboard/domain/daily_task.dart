// ══════════════════════════════════════════════════════════════════════
// The 10 daily tasks (TASK_DEFS in index.html) — same ids, titles,
// subtitles, AM/PM period, and lock rules (tasks 2/6/8 require today's
// Health Monitor behavior/physical observation; task 10 requires 2, 6, 8
// done first). The Health Monitor screen itself is a later slice, so
// isBehaviorLoggedToday/isPhysicalLoggedToday below will honestly report
// "not logged" (keeping 2/6/8/10 locked) until that slice exists — this is
// correct, not a bug: those tasks genuinely can't be completed without it.
// ══════════════════════════════════════════════════════════════════════

class DailyTaskDef {
  const DailyTaskDef(
      {required this.id,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.period});
  final String id;
  final String icon;
  final String title;
  final String subtitle;
  final String period; // 'am' | 'pm'
}

const List<DailyTaskDef> kDailyTaskDefs = [
  DailyTaskDef(
      id: '1',
      icon: '🧹',
      title: '1. Biosecurity & Environment',
      subtitle:
          'Clean inside/outside. Ensure footbath and sanitizer are ready.',
      period: 'am'),
  DailyTaskDef(
      id: '2',
      icon: '🩺',
      title: '2. Vitality Inspection',
      subtitle: 'Check if animals are active and not lethargic before feeding.',
      period: 'am'),
  DailyTaskDef(
      id: '3',
      icon: '🌾',
      title: '3. AM Feeding',
      subtitle: 'Feed set amount in clean troughs. Time: 7:30–8:00 AM.',
      period: 'am'),
  DailyTaskDef(
      id: '4',
      icon: '💧',
      title: '4. Water System Check',
      subtitle: 'Ensure clean water and steady flow in drinkers.',
      period: 'am'),
  DailyTaskDef(
      id: '5',
      icon: '🧼',
      title: '5. Pen Cleaning & Inspection',
      subtitle: 'Clean the pen. Inspect for non-eaters or weak appetite.',
      period: 'am'),
  DailyTaskDef(
      id: '6',
      icon: '🤧',
      title: '6. Respiratory Check',
      subtitle: 'Listen for coughing or signs of colds/sneezing.',
      period: 'am'),
  DailyTaskDef(
      id: '7',
      icon: '💩',
      title: '7. Waste Inspection',
      subtitle: 'Check stool condition (consistency and color).',
      period: 'am'),
  DailyTaskDef(
      id: '8',
      icon: '🌡️',
      title: '8. Temp & Ventilation',
      subtitle: 'Monitor for 26–27°C and ensure good air circulation.',
      period: 'am'),
  DailyTaskDef(
      id: '9',
      icon: '🌾',
      title: '9. PM Feeding & Dry Clean',
      subtitle: 'Feed set amount. Dry clean pen (avoid using water).',
      period: 'pm'),
  DailyTaskDef(
      id: '10',
      icon: '📝',
      title: '10. Record Daily Logs',
      subtitle: 'Log environment and health. Contact vet for issues.',
      period: 'pm'),
];

/// Returns null when task [id] is unlocked, or a user-facing lock message
/// when it's still locked. [tasksToday] is today's {taskId: done} map so
/// task 10 can check whether 2/6/8 are all done. Matches taskLockMessage()
/// in index.html exactly.
String? taskLockMessage({
  required String id,
  required Map<String, bool> tasksToday,
  required bool behaviorLoggedToday,
  required bool physicalLoggedToday,
}) {
  if (id == '2') {
    return behaviorLoggedToday
        ? null
        : "Complete today's Behavior observation in the Health Monitor to unlock this task.";
  }
  if (id == '6' || id == '8') {
    return physicalLoggedToday
        ? null
        : "Complete today's Physical observation in the Health Monitor to unlock this task.";
  }
  if (id == '10') {
    final req = ['2', '6', '8'];
    final allDone = req.every((r) => tasksToday[r] == true);
    return allDone
        ? null
        : 'Complete Vitality Inspection, Respiratory Check, and Temp & Ventilation before recording today\'s daily logs.';
  }
  return null;
}
