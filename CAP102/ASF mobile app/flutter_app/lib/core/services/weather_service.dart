import 'dart:convert';

import 'package:http/http.dart' as http;

// ══════════════════════════════════════════════════════════════════════
// A read-only, keyless weather lookup for the Dashboard hero's weather
// card — new functionality (per explicit user request), added as its own
// isolated service so it can never affect the app's real data path:
// nothing here touches Firebase, Supabase, or SQLite, and a failure or
// timeout here can only ever produce `null` (hidden weather card), never
// an error surfaced elsewhere on the Dashboard.
//
// Uses Open-Meteo (open-meteo.com) — free, no API key, no account, no
// request quota for this volume of use. Two calls per lookup:
//   1. Geocoding API: farmer's saved province name -> lat/lon.
//   2. Forecast API: lat/lon -> current temperature, humidity, weather code.
// ══════════════════════════════════════════════════════════════════════

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureC,
    required this.humidityPercent,
    required this.conditionLabel,
    required this.heatAlertLevel,
  });

  final double temperatureC;
  final int humidityPercent;
  final String conditionLabel;

  /// One of 'none' | 'moderate' | 'high' — see [heatAlertLevelFor].
  final String heatAlertLevel;
}

/// Heat-stress awareness thresholds for finisher pigs in a tropical
/// climate — pigs have no sweat glands and start showing measurable heat
/// stress (reduced feed intake, panting) well before temperatures most
/// people would call uncomfortable. These bands (None <30°C, Moderate
/// 30–32.9°C, High >=33°C ambient) are a general swine-husbandry rule of
/// thumb, not a certified meteorological heat-index — intentionally
/// conservative so the farmer gets an early nudge to check
/// ventilation/water rather than a late warning.
String heatAlertLevelFor(double temperatureC) {
  if (temperatureC >= 33) return 'high';
  if (temperatureC >= 30) return 'moderate';
  return 'none';
}

/// Maps Open-Meteo's WMO weather_code to a short farmer-facing label.
/// https://open-meteo.com/en/docs (WMO Weather interpretation codes).
String weatherConditionLabel(int code) {
  switch (code) {
    case 0:
      return 'Clear Sky';
    case 1:
      return 'Mostly Sunny';
    case 2:
      return 'Partly Cloudy';
    case 3:
      return 'Cloudy';
    case 45:
    case 48:
      return 'Foggy';
    case 51:
    case 53:
    case 55:
      return 'Light Rain';
    case 56:
    case 57:
      return 'Freezing Drizzle';
    case 61:
    case 63:
    case 65:
      return 'Rain';
    case 66:
    case 67:
      return 'Freezing Rain';
    case 71:
    case 73:
    case 75:
    case 77:
      return 'Snow';
    case 80:
    case 81:
    case 82:
      return 'Rain Showers';
    case 85:
    case 86:
      return 'Snow Showers';
    case 95:
      return 'Thunderstorm';
    case 96:
    case 99:
      return 'Thunderstorm w/ Hail';
    default:
      return 'Mostly Sunny';
  }
}

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _requestTimeout = Duration(seconds: 8);

  void dispose() => _client.close();

  /// Returns null on any failure (no network, province not found, bad
  /// response, timeout) — the hero header treats null as "hide the
  /// weather card," never as an error to surface to the farmer.
  Future<WeatherSnapshot?> fetchForProvince(String province) async {
    final trimmed = province.trim();
    if (trimmed.isEmpty) return null;
    try {
      final coords = await _geocode(trimmed);
      if (coords == null) return null;
      return await _fetchCurrent(coords.$1, coords.$2);
    } catch (_) {
      return null;
    }
  }

  Future<(double, double)?> _geocode(String province) async {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': '$province, Philippines',
      'count': '1',
      'language': 'en',
      'format': 'json',
    });
    final res = await _client.get(uri).timeout(_requestTimeout);
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    final lat = (first['latitude'] as num?)?.toDouble();
    final lon = (first['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    return (lat, lon);
  }

  Future<WeatherSnapshot?> _fetchCurrent(double lat, double lon) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current': 'temperature_2m,relative_humidity_2m,weather_code',
      'timezone': 'auto',
    });
    final res = await _client.get(uri).timeout(_requestTimeout);
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final current = body['current'] as Map<String, dynamic>?;
    if (current == null) return null;
    final temp = (current['temperature_2m'] as num?)?.toDouble();
    final humidity = (current['relative_humidity_2m'] as num?)?.toInt();
    final code = (current['weather_code'] as num?)?.toInt();
    if (temp == null || humidity == null) return null;
    return WeatherSnapshot(
      temperatureC: temp,
      humidityPercent: humidity,
      conditionLabel: weatherConditionLabel(code ?? -1),
      heatAlertLevel: heatAlertLevelFor(temp),
    );
  }
}
