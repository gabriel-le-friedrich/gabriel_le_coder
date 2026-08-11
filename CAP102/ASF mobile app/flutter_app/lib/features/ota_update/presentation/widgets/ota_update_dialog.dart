import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/ota_update.dart';
import '../providers/ota_update_providers.dart';

/// Ported from index.html's #update-modal (lines 1389-1401) — version
/// badge, notes (falls back to a generic message), Update Now / Later.
/// "Update Now" opens the APK's public URL externally (same as the
/// legacy `window.open(apkUrl, '_system')`) and lets Android's own
/// download manager + package installer take it from there — there is
/// no in-app download-progress UI in the legacy app either, so none is
/// invented here.
Future<void> showOtaUpdateDialog(
    BuildContext context, WidgetRef ref, AppRelease release) async {
  final current = await PackageInfo.fromPlatform()
      .then((i) => i.version)
      .catchError((_) => '1.0.0');
  if (!context.mounted) return;
  final lang = ref.read(appLanguageProvider);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(tr(lang, 'otaUpdateAvailable')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('v$current → v${release.version}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text((release.notes?.trim().isNotEmpty ?? false)
              ? release.notes!.trim()
              : tr(lang, 'otaDefaultNotes')),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await ref
                .read(otaUpdateRepositoryProvider)
                .dismiss(release.version);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text(tr(lang, 'otaLater')),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.download),
          label: Text(tr(lang, 'otaUpdateNow')),
          onPressed: () async {
            Navigator.pop(ctx);
            final uri = Uri.tryParse(release.apkUrl);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ],
    ),
  );
}
