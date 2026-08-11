import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/activity_log_entry.dart';
import '../../domain/activity_log_export.dart';
import '../providers/activity_log_providers.dart';

/// Read-only history of every logged action in the app — newest first,
/// with search, a date-range filter, and action-type chips. Nothing here
/// can edit or delete a row: the log is immutable by design (see
/// AuthRepository.recordActivityLog / activity_logs' insert-only RLS).
class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  String _search = '';
  String _typeFilter = 'All';
  DateTimeRange? _dateRange;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(activityLogsProvider(widget.uid));
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(lang, 'activityLogTitle')),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share),
            tooltip: tr(lang, 'exportCsv'),
            onPressed: _exporting
                ? null
                : () async {
                    final logs = logsAsync.valueOrNull;
                    if (logs == null || logs.isEmpty) return;
                    setState(() => _exporting = true);
                    try {
                      await shareActivityLogCsv(_applyFilters(logs));
                    } finally {
                      if (mounted) setState(() => _exporting = false);
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: tr(lang, 'refreshTooltip'),
            onPressed: () => ref.invalidate(activityLogsProvider(widget.uid)),
          ),
        ],
      ),
      body: logsAsync.when(
        data: (logs) {
          final filtered = _applyFilters(logs);
          final types = <String>{
            'All',
            ...logs.map((l) => l.actionType).where((t) => t.isNotEmpty)
          };
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: tr(lang, 'searchDescriptionHint'),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: types.map((t) {
                            final selected = t == _typeFilter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                    t == 'All' ? tr(lang, 'allFilter') : t),
                                selected: selected,
                                onSelected: (_) =>
                                    setState(() => _typeFilter = t),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.date_range,
                          color: _dateRange != null
                              ? Theme.of(context).colorScheme.primary
                              : null),
                      tooltip: tr(lang, 'filterByDateTooltip'),
                      onPressed: () async {
                        final now = DateTime.now();
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(now.year - 2),
                          lastDate: now,
                          initialDateRange: _dateRange,
                        );
                        if (range != null) setState(() => _dateRange = range);
                      },
                    ),
                    if (_dateRange != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: tr(lang, 'clearDateFilterTooltip'),
                        onPressed: () => setState(() => _dateRange = null),
                      ),
                  ],
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(tr(lang, 'noActivityFound')))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) =>
                            _LogTile(entry: filtered[i], lang: lang),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text(tr(lang, 'couldNotLoadActivityLog'))),
      ),
    );
  }

  List<ActivityLogEntry> _applyFilters(List<ActivityLogEntry> logs) {
    return logs.where((log) {
      if (_typeFilter != 'All' && log.actionType != _typeFilter) return false;
      if (_search.trim().isNotEmpty &&
          !log.description
              .toLowerCase()
              .contains(_search.trim().toLowerCase())) {
        return false;
      }
      if (_dateRange != null) {
        final day = DateTime(
            log.createdAt.year, log.createdAt.month, log.createdAt.day);
        final start = DateTime(_dateRange!.start.year, _dateRange!.start.month,
            _dateRange!.start.day);
        final end = DateTime(
            _dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
        if (day.isBefore(start) || day.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry, required this.lang});

  final ActivityLogEntry entry;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy · h:mm a');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading:
            CircleAvatar(child: Icon(_iconFor(entry.actionType), size: 18)),
        title: Text(entry.description),
        subtitle: Text('${fmt.format(entry.createdAt)} · ${entry.actionType}'),
        trailing: entry.synced
            ? null
            : Tooltip(
                message: tr(lang, 'notYetSyncedTooltip'),
                child: Icon(Icons.cloud_off,
                    size: 16, color: Theme.of(context).colorScheme.outline)),
      ),
    );
  }

  IconData _iconFor(String actionType) {
    switch (actionType) {
      case 'auth':
        return Icons.login;
      case 'settings':
        return Icons.settings_outlined;
      case 'notifications':
        return Icons.notifications_outlined;
      case 'health':
        return Icons.health_and_safety_outlined;
      case 'expenses':
        return Icons.payments_outlined;
      case 'growth':
        return Icons.show_chart;
      case 'pigs':
        return Icons.pets;
      default:
        return Icons.circle_notifications_outlined;
    }
  }
}
