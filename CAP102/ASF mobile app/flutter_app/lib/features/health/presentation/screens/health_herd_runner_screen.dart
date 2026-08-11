import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pigs/domain/pig.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/health_calculations.dart';
import 'health_form_screen.dart';
import 'health_herd_summary_screen.dart';

// ══════════════════════════════════════════════════════════════════════
// "Overall Herd" mode, step 3 — walks the farmer through the SAME
// HealthFormScreen once per selected real pig, one after another, sharing
// one [sessionId] purely as grouping metadata. Every save is a real,
// independent HealthLogEntry for that specific pig — see
// health_calculations.dart's doc on HealthLogEntry.sessionId: this never
// substitutes a single fake "herd" record for the individual checks.
// When the last pig is saved, hands the collected entries to
// HealthHerdSummaryScreen (a pure aggregation view, no new score).
// ══════════════════════════════════════════════════════════════════════
class HealthHerdRunnerScreen extends ConsumerStatefulWidget {
  const HealthHerdRunnerScreen({super.key, required this.pigs});
  final List<Pig> pigs;

  @override
  ConsumerState<HealthHerdRunnerScreen> createState() =>
      _HealthHerdRunnerScreenState();
}

class _HealthHerdRunnerScreenState
    extends ConsumerState<HealthHerdRunnerScreen> {
  late final String _sessionId =
      'herd_${DateTime.now().millisecondsSinceEpoch}';
  int _index = 0;
  final List<HealthLogEntry> _collected = [];

  void _handleSaved(HealthLogEntry saved) {
    _collected.add(saved);
    if (_index + 1 < widget.pigs.length) {
      setState(() => _index++);
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => HealthHerdSummaryScreen(entries: List.of(_collected)),
      ));
    }
  }

  Future<void> _confirmExit() async {
    final lang = ref.read(appLanguageProvider);
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(lang, 'herdExitConfirmTitle')),
        content: Text(
            '${tr(lang, 'herdExitConfirmBody')} (${_collected.length}/${widget.pigs.length} ${tr(lang, 'pigsMonitoredLabel')})'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr(lang, 'cancel'))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr(lang, 'exitHerdCheckButton'))),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final pig = widget.pigs[_index];
    final progressLabel =
        '${tr(lang, 'pigOfLabel')} ${_index + 1} ${tr(lang, 'ofLabel')} ${widget.pigs.length}';
    return PopScope(
      canPop: _index == 0 && _collected.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmExit();
      },
      child: HealthFormScreen(
        key: ValueKey('herd_step_${pig.id}'),
        pigId: pig.id,
        pigName: pig.name,
        sessionId: _sessionId,
        herdProgressLabel: progressLabel,
        onSavedInHerdFlow: _handleSaved,
      ),
    );
  }
}
