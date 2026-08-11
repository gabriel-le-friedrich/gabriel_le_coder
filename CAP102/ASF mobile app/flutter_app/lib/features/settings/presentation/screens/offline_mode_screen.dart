import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/settings_strings.dart';
import '../providers/settings_providers.dart';
import '../theme/settings_palette.dart';
import '../widgets/settings_widgets.dart';

/// Offline Mode — real connectivity state (same connectivity_plus source as
/// SyncScreen) plus an honest explanation of what already works offline
/// today: every write (weigh-ins, feeding, health checks, expenses) is
/// saved to SQLite first and pushed to Supabase automatically once a
/// connection returns (see SyncEngine.syncNow/watchConnectivity). No
/// "offline mode" toggle exists to switch — offline-first is how the app
/// always behaves — so this screen only surfaces the current connection
/// state and explains that behavior, rather than fabricating a switch that
/// would do nothing.
class OfflineModeScreen extends ConsumerStatefulWidget {
  const OfflineModeScreen({super.key, required this.uid});
  final String uid;

  @override
  ConsumerState<OfflineModeScreen> createState() => _OfflineModeScreenState();
}

class _OfflineModeScreenState extends ConsumerState<OfflineModeScreen> {
  bool? _online;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then((results) {
      if (!mounted) return;
      setState(
          () => _online = results.any((r) => r != ConnectivityResult.none));
    });
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(
          () => _online = results.any((r) => r != ConnectivityResult.none));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final online = _online;

    return Scaffold(
      backgroundColor: SettingsPalette.background,
      appBar: AppBar(
        title: Text(tr(lang, 'offlineModeLabel'),
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
          Container(
            decoration: settingsCardDecoration(),
            padding: settingsCardPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                      color: SettingsPalette.lightGreen,
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Icon(Icons.wifi_off_rounded,
                      color: SettingsPalette.primaryGreen, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(lang, 'offlineModeExplainTitle'),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: SettingsPalette.darkText)),
                      const SizedBox(height: 6),
                      Text(tr(lang, 'offlineModeExplainBody'),
                          style: const TextStyle(
                              fontSize: 13,
                              color: SettingsPalette.grayText,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
