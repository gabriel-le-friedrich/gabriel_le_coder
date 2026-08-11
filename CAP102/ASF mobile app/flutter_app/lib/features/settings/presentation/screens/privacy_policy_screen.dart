import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/settings_strings.dart';
import '../providers/settings_providers.dart';

/// The legacy web app has no dedicated Privacy Policy screen or text — only
/// a plain-text checkbox on registration referencing "Terms & Conditions
/// and Privacy Policy" with no linked content (index.html:1566-1567). This
/// is freshly authored, scoped to what this app actually collects and does
/// with it. It is NOT lawyer-reviewed — treat it as a starting draft to
/// have reviewed before shipping to real users.
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'privacyPolicy'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _Section(
            title: 'Information We Collect',
            body:
                'When you use ASF, we collect the information you provide directly: your name, '
                'phone number, email address, municipality/province, farm details, and the pig, '
                'growth, expense, and health records you enter. If you take photos of your pigs '
                'within the app, those photos are stored as well.',
          ),
          _Section(
            title: 'How We Use Your Information',
            body:
                'Your information is used solely to operate the app: authenticating your account, '
                'storing and syncing your farm records across your devices, calculating your '
                'dashboard figures (ADG, FCR, ROI, and similar), and sending the reminders you '
                'enable in Notification Settings. We do not sell your data or share it with '
                'advertisers.',
          ),
          _Section(
            title: 'Where Your Data Is Stored',
            body:
                'Your records are stored locally on your device (so the app keeps working '
                'offline) and are synced to secure cloud storage (Firebase Authentication for your '
                'account identity, Supabase for your farm records) when your device has an '
                'internet connection.',
          ),
          _Section(
            title: 'Your Choices',
            body:
                'You can review and edit your profile at any time from Settings > Profile, '
                'control which reminders you receive from Settings > Notifications, and request '
                'account deletion by contacting the developer using the details on the About page.',
          ),
          _Section(
            title: 'Contact',
            body:
                'Questions about this policy can be directed to the developer listed on the '
                'About page.',
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
