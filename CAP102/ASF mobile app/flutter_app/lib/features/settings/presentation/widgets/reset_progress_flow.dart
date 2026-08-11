import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/reset_repository.dart';
import '../../domain/app_language.dart';
import '../../domain/settings_strings.dart';

// ══════════════════════════════════════════════════════════════════════
// C10's three-step Reset Progress flow — extracted out of settings_screen.
// dart (unchanged logic) so both the main Settings screen's "Danger Zone"
// entry point and the new Data Management screen can trigger the exact
// same confirm -> type-to-confirm -> cancelable-countdown -> resetProgress()
// sequence, without duplicating ~140 lines of dialog code in two files.
// ══════════════════════════════════════════════════════════════════════

/// (1) a plain warning dialog explaining exactly what is and isn't wiped,
/// (2) a type-to-confirm step ("type RESET") so a stray double-tap can
/// never trigger this, (3) a cancelable 15-second countdown as the final
/// safety net before [ResetRepository.resetProgress] actually runs. Any
/// step's Cancel stops the whole flow with no side effects.
Future<void> startResetProgressFlow(
    BuildContext context, String uid, AppLanguage lang) async {
  final warned = await showCustomConfirmDialog(
    context,
    title: tr(lang, 'resetProgressWarningTitle'),
    message: tr(lang, 'resetProgressWarningBody'),
    confirmLabel: tr(lang, 'resetProgress'),
    cancelLabel: tr(lang, 'cancel'),
    destructive: true,
  );
  if (!warned || !context.mounted) return;

  final typedOk = await _showTypeToConfirm(context, lang);
  if (!typedOk || !context.mounted) return;

  final proceeded = await _showCancelableCountdown(context, lang);
  if (!proceeded || !context.mounted) return;

  try {
    await ResetRepository().resetProgress(uid);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(lang, 'resetProgressDone'))));
      context.go(AppRoutes.dashboard);
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(lang, 'resetProgressFailed'))));
    }
  }
}

Future<bool> _showTypeToConfirm(BuildContext context, AppLanguage lang) async {
  final ctrl = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final matches = ctrl.text.trim().toUpperCase() == 'RESET';
        return AlertDialog(
          title: Text(tr(lang, 'resetProgressTypeConfirmTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(lang, 'resetProgressTypeConfirmBody')),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                    hintText: tr(lang, 'resetProgressTypeConfirmHint'),
                    border: const OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr(lang, 'cancel'))),
            FilledButton(
              onPressed: matches ? () => Navigator.pop(ctx, true) : null,
              child: Text(tr(lang, 'resetProgress')),
            ),
          ],
        );
      },
    ),
  );
  return result ?? false;
}

Future<bool> _showCancelableCountdown(
    BuildContext context, AppLanguage lang) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _CountdownDialog(lang: lang),
  );
  return result ?? false;
}

/// Cancelable 15-second countdown (C10) — the last safety net before
/// ResetRepository.resetProgress() actually deletes anything. Ticks down
/// once a second; Cancel pops `false` at any point and stops the timer;
/// reaching 0 pops `true` and lets startResetProgressFlow proceed.
class _CountdownDialog extends StatefulWidget {
  const _CountdownDialog({required this.lang});
  final AppLanguage lang;

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  int _secondsLeft = 15;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          '${tr(widget.lang, 'resetProgressCountdownTitle')} $_secondsLeft'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr(widget.lang, 'resetProgressCountdownBody')),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _secondsLeft / 15),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(false);
          },
          child: Text(tr(widget.lang, 'cancel')),
        ),
      ],
    );
  }
}
