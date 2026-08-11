import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ota_update_repository.dart';
import '../../domain/ota_update.dart';

final otaUpdateRepositoryProvider =
    Provider<OtaUpdateRepository>((ref) => OtaUpdateRepository());

/// Watched once from the Dashboard screen — which, unlike the legacy web
/// app's fixed 2.5s boot timer, is only ever reachable AFTER auth has
/// resolved (see app_router.dart's redirect()). That gives this a stronger
/// "never interrupts auth" guarantee than the timing-only approach the
/// legacy checker relies on.
final otaUpdateCheckProvider = FutureProvider.autoDispose<AppRelease?>((ref) {
  return ref.watch(otaUpdateRepositoryProvider).checkForUpdate();
});
