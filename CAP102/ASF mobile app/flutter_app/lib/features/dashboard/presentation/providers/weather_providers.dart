import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/weather_service.dart';

final weatherServiceProvider = Provider<WeatherService>((ref) {
  final service = WeatherService();
  ref.onDispose(service.dispose);
  return service;
});

/// Current weather for the Dashboard hero's weather card, keyed by the
/// farmer's saved province. autoDispose (not kept alive) — a fresh look
/// each time the Dashboard is (re)built is fine for a "right now" reading,
/// and avoids holding a stale network result forever in memory. Returns
/// null on any failure; the hero header hides the card rather than
/// showing an error, since this is a nice-to-have, not core functionality.
final weatherProvider =
    FutureProvider.autoDispose.family<WeatherSnapshot?, String>(
  (ref, province) =>
      ref.watch(weatherServiceProvider).fetchForProvince(province),
);
