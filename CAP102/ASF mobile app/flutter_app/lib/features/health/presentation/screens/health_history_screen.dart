import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../pigs/presentation/providers/pig_providers.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/health_calculations.dart';
import '../../domain/health_export.dart';
import '../../domain/health_status_colors.dart';
import '../providers/health_providers.dart';

/// Quick date-range filters — in addition to the exact-date picker, so a
/// farmer can jump straight to "what happened this week" without knowing
/// the specific date. Mutually exclusive with the exact-date picker:
/// picking one clears the other.
enum _QuickRange { today, week, month }

/// Health History — newest first, with search, a single-day filter,
/// Today/This Week/This Month quick filters, status filter chips, and
/// (Health Monitor redesign) a Specific Pig / All Monitored Pigs filter,
/// matching renderHealthLogsList()/renderHealthFilterRow() in index.html.
/// Read/write only through HealthRepository (via health_providers.dart);
/// delete requires confirmation, matching confirmDeleteHealthLog().
class HealthHistoryScreen extends ConsumerStatefulWidget {
  const HealthHistoryScreen({super.key, this.initialStatusFilter});

  /// Health Monitor redesign — lets the Herd Health Summary's "Review
  /// Critical Pigs" / "Review At-Risk Pigs" actions land here pre-filtered
  /// to that status, instead of dumping the farmer on an unfiltered list.
  final HealthStatus? initialStatusFilter;

  @override
  ConsumerState<HealthHistoryScreen> createState() =>
      _HealthHistoryScreenState();
}

class _HealthHistoryScreenState extends ConsumerState<HealthHistoryScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  HealthStatus? _statusFilter; // null = all
  DateTime? _dateFilter;
  _QuickRange? _quickRange; // null = no quick range applied

  /// Health Monitor redesign — null = "All Monitored Pigs" (every entry,
  /// including legacy flock-level rows with no pigId). Set to a real
  /// [Pig.id] to see only that pig's checks.
  String? _pigFilter;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatusFilter;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final logsAsync = ref.watch(healthLogsProvider(uid));
    final pigsAsync = ref.watch(pigListProvider(uid));
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tr(lang, 'healthHistoryTitle')),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined),
            tooltip: tr(lang, 'exportCsv'),
            onPressed: () async {
              final logs = _filtered(logsAsync.valueOrNull ?? []);
              await shareHealthCsv(logs);
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: tr(lang, 'exportPdf'),
            onPressed: () async {
              final logs = _filtered(logsAsync.valueOrNull ?? []);
              await shareHealthPdf(logs);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/health/new'),
        icon: const Icon(Icons.add),
        label: Text(tr(lang, 'logHealth')),
      ),
      body: logsAsync.when(
        data: (logs) {
          final filtered = _filtered(logs);
          return Column(
            children: [
              if (kDebugMode) _SkippedRecordsNotice(uid: uid, lang: lang),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: tr(lang, 'searchNotesHint'),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) =>
                      setState(() => _search = v.trim().toLowerCase()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _statusChip(null, tr(lang, 'allChip')),
                      for (final s in HealthStatus.values)
                        _statusChip(s,
                            '${kHealthStatusMeta[s]!.emoji} ${healthStatusLabel(lang, s)}'),
                    ],
                  ),
                ),
              ),
              if ((pigsAsync.valueOrNull ?? const []).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _pigChip(null, tr(lang, 'allMonitoredPigsLabel')),
                        for (final pig in pigsAsync.valueOrNull!)
                          _pigChip(pig.id, pig.name),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _quickRangeChip(_QuickRange.today, tr(lang, 'todayChip')),
                      _quickRangeChip(
                          _QuickRange.week, tr(lang, 'thisWeekChip')),
                      _quickRangeChip(
                          _QuickRange.month, tr(lang, 'thisMonthChip')),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_dateFilter == null
                            ? tr(lang, 'customDate')
                            : _dateFilter!.toIso8601String().split('T').first),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dateFilter ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              _dateFilter = picked;
                              _quickRange = null;
                            });
                          }
                        },
                      ),
                      if (_dateFilter != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: tr(lang, 'clearCustomDateFilter'),
                          onPressed: () => setState(() => _dateFilter = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(tr(lang, 'noHealthObsYet')))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => FadeSlideIn(
                          delayMs: i < 8 ? i * 40 : 0,
                          child: _HealthLogCard(
                            entry: filtered[i],
                            lang: lang,
                            onEdit: () =>
                                context.push('/health/new', extra: filtered[i]),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryGreen)),
          ),
        ),
        error: (error, stackTrace) {
          if (kDebugMode)
            debugPrint('HealthHistoryScreen: $error\n$stackTrace');
          return _HealthMonitorErrorView(
              lang: lang,
              onRetry: () => ref.invalidate(healthLogsProvider(uid)));
        },
      ),
    );
  }

  Widget _statusChip(HealthStatus? status, String label) {
    final selected = _statusFilter == status;
    final color = status == null ? null : kHealthStatusColor[status];
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label,
            style: TextStyle(
                color: selected && color != null ? Colors.white : null)),
        selected: selected,
        selectedColor: color,
        onSelected: (_) => setState(() => _statusFilter = status),
      ),
    );
  }

  Widget _pigChip(String? pigId, String label) {
    final selected = _pigFilter == pigId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: pigId == null ? null : const Icon(Icons.pets, size: 15),
        label: Text(label, overflow: TextOverflow.ellipsis),
        selected: selected,
        onSelected: (_) => setState(() => _pigFilter = pigId),
      ),
    );
  }

  Widget _quickRangeChip(_QuickRange range, String label) {
    final selected = _quickRange == range;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() {
          _quickRange = selected ? null : range;
          _dateFilter = null;
        }),
      ),
    );
  }

  List<HealthLogEntry> _filtered(List<HealthLogEntry> logs) {
    var result = [...logs]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (_statusFilter != null) {
      result = result.where((h) => h.status == _statusFilter).toList();
    }
    if (_pigFilter != null) {
      // Legacy flock-level rows (pigId == null) are intentionally excluded
      // once a specific pig is chosen — they were never attributed to this
      // pig and must never be mis-attributed to it now.
      result = result.where((h) => h.pigId == _pigFilter).toList();
    }
    if (_dateFilter != null) {
      final target = _dateFilter!.toIso8601String().split('T').first;
      result = result.where((h) => h.date == target).toList();
    }
    if (_quickRange != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      DateTime rangeStart;
      switch (_quickRange!) {
        case _QuickRange.today:
          rangeStart = today;
          break;
        case _QuickRange.week:
          rangeStart = today.subtract(Duration(days: today.weekday - 1));
          break;
        case _QuickRange.month:
          rangeStart = DateTime(today.year, today.month, 1);
          break;
      }
      result = result.where((h) {
        final parsed = DateTime.tryParse(h.date);
        if (parsed == null) return false;
        return !parsed.isBefore(rangeStart) &&
            !parsed.isAfter(today.add(const Duration(days: 1)));
      }).toList();
    }
    if (_search.isNotEmpty) {
      result = result.where((h) {
        final haystack = [
          h.notes,
          findHealthOption(kBehaviorOptions, h.behavior)?.label ?? '',
          findHealthOption(kAppetiteOptions, h.appetite)?.label ?? '',
          h.physicalLabel,
          findHealthOption(kWasteOptions, h.waste)?.label ?? '',
        ].join(' ').toLowerCase();
        return haystack.contains(_search);
      }).toList();
    }
    return result;
  }
}

/// Debug-build-only notice shown when [HealthRepository.getHealthLogs]'s
/// most recent read had to skip one or more corrupted records — item 5 of
/// the data-integrity pass. Deliberately gated on [kDebugMode] at the call
/// site (not just here) so this never renders, and the underlying provider
/// is never even watched, in a release build.
class _SkippedRecordsNotice extends ConsumerWidget {
  const _SkippedRecordsNotice({required this.uid, required this.lang});
  final String uid;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skipped =
        ref.watch(healthLogsSkippedCountProvider(uid)).valueOrNull ?? 0;
    if (skipped == 0) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.bug_report_outlined, size: 16, color: Colors.brown),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(lang, 'skippedRecordsNotice'),
              style: const TextStyle(fontSize: 11.5, color: Colors.brown),
            ),
          ),
        ],
      ),
    );
  }
}

/// Graceful fallback for the (now rare — see HealthRepository
/// .getHealthLogs's per-entry try/catch) case where loading Health Logs
/// still fails outright, e.g. the underlying SQLite read itself throwing.
/// Gives the farmer a way forward instead of a blank/frozen screen: retry
/// the same load, or back out to the Dashboard.
class _HealthMonitorErrorView extends StatelessWidget {
  const _HealthMonitorErrorView({required this.onRetry, required this.lang});
  final VoidCallback onRetry;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(tr(lang, 'healthMonitorErrorTitle'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              tr(lang, 'healthMonitorErrorBody'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomButton(
                  label: tr(lang, 'goBack'),
                  outlined: true,
                  onPressed: () => Navigator.of(context).canPop()
                      ? Navigator.of(context).pop()
                      : context.go(AppRoutes.dashboard),
                ),
                const SizedBox(width: 12),
                CustomButton(label: tr(lang, 'retry'), onPressed: onRetry),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Filipino-aware equivalent of HealthLogEntry.physicalLabel — that getter
/// stays English/canonical (used by CSV/PDF export), so this is the
/// display-only translation for the History card, comma-joining every
/// selected symptom's healthOptionLabel() instead of its raw .label.
String _translatedPhysicalLabel(AppLanguage lang, HealthLogEntry entry) {
  if (entry.physical.isEmpty) return '—';
  return entry.physical
      .map((k) => healthOptionLabel(lang, 'physical', k,
          findHealthOption(kPhysicalOptions, k)?.label ?? k))
      .join(', ');
}

class _HealthLogCard extends StatelessWidget {
  const _HealthLogCard(
      {required this.entry, required this.lang, required this.onEdit});
  final HealthLogEntry entry;
  final AppLanguage lang;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final meta = kHealthStatusMeta[entry.status]!;
    final beh = findHealthOption(kBehaviorOptions, entry.behavior);
    final app = findHealthOption(kAppetiteOptions, entry.appetite);
    final waste = findHealthOption(kWasteOptions, entry.waste);
    final rec = entry.statusRecommendation;
    final digestiveTip = entry.digestiveTip;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: appCardDecoration(radius: AppRadius.cardSmall),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DayBadge(day: entry.day, date: entry.date, time: entry.time),
                Chip(
                  label: Text(
                      '${meta.emoji} ${healthStatusLabel(lang, entry.status)}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  backgroundColor: kHealthStatusColor[entry.status],
                  side: BorderSide.none,
                ),
              ],
            ),
            if (entry.batchName.isNotEmpty ||
                entry.pigName.isNotEmpty ||
                entry.assessedBy.isNotEmpty ||
                entry.pigId == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    // Health Monitor redesign — a pre-redesign flock-level
                    // entry has no pigId; label it explicitly rather than
                    // silently showing nothing, so it's never confused with
                    // (or hidden by) a Specific Pig filter.
                    if (entry.pigId == null &&
                        entry.pigName.isEmpty &&
                        entry.batchName.isEmpty)
                      '${tr(lang, 'pigLabel')}: ${tr(lang, 'unassignedLabel')}',
                    if (entry.batchName.isNotEmpty)
                      '${tr(lang, 'batchLabel')}: ${entry.batchName}',
                    if (entry.pigName.isNotEmpty)
                      '${tr(lang, 'pigLabel')}: ${entry.pigName}',
                    if (entry.assessedBy.isNotEmpty)
                      '${tr(lang, 'assessedByLabel')}: ${entry.assessedBy}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '🧠 ${tr(lang, 'behaviorLabel')}: ${beh != null ? '${beh.icon} ${healthOptionLabel(lang, 'behavior', beh.key, beh.label)}' : entry.behavior}',
            ),
            Text(
              '🍽 ${tr(lang, 'appetiteLabel')}: ${app != null ? '${app.icon} ${healthOptionLabel(lang, 'appetite', app.key, app.label)}' : entry.appetite}',
            ),
            Text(
              '🩺 ${tr(lang, 'physicalLabel')}: ${_translatedPhysicalLabel(lang, entry)}',
            ),
            Text(
              '💩 ${tr(lang, 'wasteLabel')}: ${waste != null ? '${waste.icon} ${healthOptionLabel(lang, 'waste', waste.key, waste.label)}' : entry.waste}',
            ),
            if (entry.notes.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('📝 ${entry.notes}')),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rec.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                  ...rec.body.map((b) =>
                      Text('• $b', style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
            if (digestiveTip != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(digestiveTip.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    ...digestiveTip.body.map((b) =>
                        Text('• $b', style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Bug A9 fix: Delete was removed entirely — health log
                // entries are an audit trail of what was actually observed
                // on a given production day and must stay immutable once
                // created (no delete button/action anywhere in this app).
                // Edit is kept (unaffected by this bug report).
                TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(tr(lang, 'edit'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A distinct, prominent badge for the production day — not just inline
/// text — matching the mockup ("Day 15 / July 20, 2026 / 8:03 AM") so the
/// day-of-production is the first thing a farmer notices on each entry.
class _DayBadge extends StatelessWidget {
  const _DayBadge({required this.day, required this.date, required this.time});
  final int day;
  final String date;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Day $day',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(date,
              style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
          Text(time,
              style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
        ],
      ),
    );
  }
}
