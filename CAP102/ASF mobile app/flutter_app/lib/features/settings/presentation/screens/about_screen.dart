import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/asf_logo.dart';
import '../../domain/settings_strings.dart';
import '../providers/settings_providers.dart';

/// Ported verbatim from index.html's `.about-card` (lines 1137-1148):
/// name, description, version, developer, institution, campus.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'about'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                const AsfLogo(size: 80, borderRadius: 20),
                const SizedBox(height: 8),
                Text('ASF',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Administration for Swine Finisher',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr(lang, 'aboutDescription'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          _AboutRow(label: tr(lang, 'versionLabel'), value: 'v1.0'),
          _AboutRow(label: tr(lang, 'developerLabel'), value: 'PSAU 2026'),
          _AboutRow(
              label: tr(lang, 'institutionLabel'),
              value: 'Pampanga State Agricultural University'),
          _AboutRow(
              label: tr(lang, 'campusLabel'), value: 'Magalang, Pampanga'),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    // Institution's value ("Pampanga State Agricultural University") is long
    // enough to overflow a plain unconstrained Row on narrower phones or
    // with a bumped-up system font scale — wrapping it in Expanded lets it
    // wrap to a second line (right-aligned, matching the label/value
    // layout) instead of throwing a RenderFlex overflow.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
