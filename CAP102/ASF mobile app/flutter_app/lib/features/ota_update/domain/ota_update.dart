/// Ported from auth-main.js's compareVersions()/getRunningAppVersion() —
/// a custom dot-separated numeric compare (NOT real semver: no
/// pre-release/build-metadata handling), matching the legacy app exactly
/// rather than swapping in a stricter comparator it never used.
class AppRelease {
  const AppRelease({required this.version, required this.apkUrl, this.notes});

  final String version;
  final String apkUrl;
  final String? notes;
}

int compareVersions(String a, String b) {
  final pa = a.split('.').map((n) => int.tryParse(n) ?? 0).toList();
  final pb = b.split('.').map((n) => int.tryParse(n) ?? 0).toList();
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final da = i < pa.length ? pa[i] : 0;
    final db = i < pb.length ? pb[i] : 0;
    if (da != db) return da - db;
  }
  return 0;
}
