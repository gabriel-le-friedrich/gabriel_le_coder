import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/sync_engine_providers.dart';
import '../../domain/settings_strings.dart';
import '../providers/settings_providers.dart';
import '../theme/settings_palette.dart';
import '../widgets/settings_widgets.dart';

/// Synchronization — real connectivity state (connectivity_plus, the same
/// package SyncEngine.watchConnectivity already uses) plus a manual "Sync
/// Now" button that calls the exact same [SyncEngine.syncNow] every
/// repository's write path and the periodic/reconnect triggers already use
/// (see sync_engine.dart). No fabricated "last synced" timestamp or fake
/// progress — only the online/offline state and the outcome of a sync pass
/// actually run.
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key, required this.uid});
  final String uid;

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool? _online;
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(
          () => _online = results.any((r) => r != ConnectivityResult.none));
    });
  }

  Future<void> _checkInitial() async {
    final results = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() => _online = results.any((r) => r != ConnectivityResult.none));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    final lang = ref.read(appLanguageProvider);
    try {
      await ref.read(syncEngineProvider).syncNow(widget.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(lang, 'syncCompleteMessage'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(lang, 'syncFailedMessage'))));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final online = _online;

    return Scaffold(
      backgroundColor: SettingsPalette.background,
      appBar: AppBar(
        title: Text(tr(lang, 'synchronizationLabel'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: SettingsPalette.darkText)),
        backgroundColor: SettingsPalette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: SettingsPalette.darkText),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: settingsAnimatedChildren([
          Text(tr(lang, 'synchronizationScreenIntro'),
              style: const TextStyle(
                  fontSize: 13.5,
                  color: SettingsPalette.grayText,
                  height: 1.4)),
          const SizedBox(height: 18),
          Container(
            decoration: settingsCardDecoration(),
            padding: settingsCardPadding,
            child: Row(
              children: [
                Expanded(
                  child: Text(tr(lang, 'connectionStatusLabel'),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: SettingsPalette.darkText)),
                ),
                if (online == null)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  SettingsStatusChip(
                    label: tr(lang, online ? 'onlineStatus' : 'offlineStatus'),
                    foreground: online
                        ? SettingsPalette.success
                        : SettingsPalette.grayText,
                    background: online
                        ? SettingsPalette.lightGreen
                        : SettingsPalette.border,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: SettingsPalette.primaryGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              label: Text(_isSyncing
                  ? tr(lang, 'syncingLabel')
                  : tr(lang, 'syncNowButton')),
              onPressed: (online == false || _isSyncing) ? null : _syncNow,
            ),
          ),
        ]),
      ),
    );
  }
}
