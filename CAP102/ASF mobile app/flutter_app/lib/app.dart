import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/services/local_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/providers/settings_providers.dart';

/// Where a notification tap (local reminder OR FCM data message carrying a
/// `routeKey`) should land. Every reminder key funnels through here so both
/// notification systems share one tap-routing table.
String _routeForNotificationKey(String key) {
  switch (key) {
    case 'health':
    case 'vaccination':
    case 'medication':
      return AppRoutes.healthHub;
    case 'weighin':
    case 'photo':
      // Both weigh-in and weekly-photo reminders now land on the merged
      // Pig Growth tab (formerly two separate "Weight & ADG"/"Pig Growth"
      // destinations) — see app_router.dart's file header for the merge.
      return AppRoutes.pigs;
    case 'backup':
      return AppRoutes.expenses;
    case 'feeding':
    case 'marketDay':
    case 'productionDay':
    default:
      return AppRoutes.dashboard;
  }
}

/// Root widget. All auth/onboarding/dashboard routing decisions now live in
/// core/routing/app_router.dart's redirect() — this widget just wires the
/// GoRouter it builds into MaterialApp.router, plus a single app-lifetime
/// listener that turns notification taps (local reminders and FCM data
/// messages alike) into navigation.
class AsfApp extends ConsumerStatefulWidget {
  const AsfApp({super.key});

  @override
  ConsumerState<AsfApp> createState() => _AsfAppState();
}

class _AsfAppState extends ConsumerState<AsfApp> {
  StreamSubscription<String>? _tapSub;

  @override
  void initState() {
    super.initState();
    _tapSub = LocalNotificationService.tapEvents.stream.listen((key) {
      final router = ref.read(goRouterProvider);
      router.push(_routeForNotificationKey(key));
    });
  }

  @override
  void dispose() {
    _tapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    return MaterialApp.router(
      title: 'ASF',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
