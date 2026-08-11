import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/settings_strings.dart';
import '../providers/settings_providers.dart';

/// Freshly authored, same rationale as privacy_policy_screen.dart — the
/// legacy app only had a plain-text checkbox referencing Terms & Conditions
/// with no linked content. Not lawyer-reviewed.
class TermsOfServiceScreen extends ConsumerWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'termsOfService'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _Section(
            title: 'Acceptance of Terms',
            body:
                'By creating an account and using ASF, you agree to these Terms of Service and '
                'the accompanying Privacy Policy.',
          ),
          _Section(
            title: 'Purpose of the App',
            body:
                'ASF is a farm management tool intended to help you record and track swine '
                'finisher raising activity — weight, feeding, expenses, and health observations. '
                'Calculations shown in the app (ADG, FCR, ROI, projected profit, and similar) are '
                'estimates based on the data you enter and are provided for your own record-keeping; '
                'they are not veterinary, financial, or agricultural advice.',
          ),
          _Section(
            title: 'Your Responsibilities',
            body:
                'You are responsible for the accuracy of the information you enter and for '
                'keeping your account credentials secure. You agree not to use the app for any '
                'unlawful purpose.',
          ),
          _Section(
            title: 'Data & Offline Use',
            body:
                'The app is designed to keep working without an internet connection, storing your '
                'records locally and syncing them when a connection becomes available. You are '
                'responsible for keeping your device reasonably secure, since locally stored '
                'records remain on the device.',
          ),
          _Section(
            title: 'Changes to These Terms',
            body:
                'These terms may be updated as the app evolves. Continued use of the app after an '
                'update constitutes acceptance of the revised terms.',
          ),
          _Section(
            title: 'Contact',
            body:
                'Questions about these terms can be directed to the developer listed on the About '
                'page.',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
