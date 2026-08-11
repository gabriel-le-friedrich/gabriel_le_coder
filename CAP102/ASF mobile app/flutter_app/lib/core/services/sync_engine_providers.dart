import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/expenses/data/expenses_repository.dart';
import '../../features/health/data/health_repository.dart';
import '../../features/pigs/data/pig_repository.dart';
import 'sync_engine.dart';

final syncEngineProvider = Provider<SyncEngine>((ref) => SyncEngine());

/// Watched once from the Dashboard route (see app_router.dart's
/// _DashboardRoute), same bootstrap pattern as notificationBootstrapProvider
/// and settingsBootstrapProvider: runs one resync pass immediately (covers
/// "app was offline last session, now it's online"), then keeps a
/// connectivity listener alive for the rest of this Dashboard session so a
/// mid-session reconnect (e.g. walking back into Wi-Fi range) triggers
/// another pass automatically.
///
/// Logging system audit fix #3: also starts [SyncEngine.startPeriodicSync]
/// here, so a third trigger (a 25-minute timer, inside the 20-30 minute
/// target window) runs alongside the existing two without replacing
/// either. `ref.onDispose` already tears this provider down on logout
/// (leaving the Dashboard route removes the last watcher of this
/// `autoDispose` provider), so `stopPeriodicSync()` runs then — and the
/// next login re-watches this same provider, which calls
/// `startPeriodicSync()` again, so the timer resumes automatically with no
/// extra login/logout plumbing.
final syncEngineBootstrapProvider =
    FutureProvider.autoDispose.family<void, String>((ref, uid) async {
  final engine = ref.watch(syncEngineProvider);
  await engine.syncNow(uid);
  engine.startPeriodicSync(uid);
  final StreamSubscription subscription = engine.watchConnectivity(uid);
  ref.onDispose(() {
    subscription.cancel();
    engine.stopPeriodicSync();
  });
});

/// Watched once from the Dashboard route, same as syncEngineBootstrapProvider
/// above — but this is the missing *other* direction. Every repository's
/// getX() only ever reads local SQLite, which starts out completely empty
/// on a fresh install/reinstall, even for an account that already has
/// pigs/expenses/health logs/weigh-ins recorded in the cloud from a
/// different phone. syncEngineBootstrapProvider only ever pushes
/// local->cloud (see SyncEngine's file header), so a brand-new device
/// never had a way to pull that existing data down — which is exactly
/// what "my data didn't show up after switching phones" was caused by.
/// Each pullXFromCloudIfEmpty() below is a no-op the moment local data
/// exists, so this is safe to watch on every Dashboard load, not just the
/// very first one.
final pullMissingDataBootstrapProvider =
    FutureProvider.autoDispose.family<void, String>((ref, uid) async {
  await Future.wait([
    ExpensesRepository().pullFromCloudIfEmpty(uid),
    PigRepository().pullPigsFromCloudIfEmpty(uid),
    HealthRepository().pullFromCloudIfEmpty(uid),
    DashboardRepository().pullWeightLogsFromCloudIfEmpty(uid),
  ]);
});
