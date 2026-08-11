// ══════════════════════════════════════════════════════════════════════
// ASF — Email Testing screen (spec item 13). Lets anyone with the app
// installed verify the Brevo integration end-to-end without needing to
// register a new account or submit a real consultation: four buttons,
// each firing one EmailRepository call, with the raw success/error/
// response shown right below so a failed Edge Function deploy or a wrong
// secret is obvious immediately instead of silently failing in the
// background.
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/email_models.dart';
import '../providers/email_providers.dart';

class EmailTestingScreen extends ConsumerStatefulWidget {
  const EmailTestingScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<EmailTestingScreen> createState() => _EmailTestingScreenState();
}

class _EmailTestingScreenState extends ConsumerState<EmailTestingScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController(text: 'Test Farmer');

  bool _busy = false;
  String? _lastAction;
  EmailSendResult? _lastResult;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _run(
      String label, Future<EmailSendResult> Function() action) async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _lastAction = label;
        _lastResult = const EmailSendResult(
            success: false,
            error: 'Enter a recipient email address above first.');
      });
      return;
    }
    setState(() {
      _busy = true;
      _lastAction = label;
      _lastResult = null;
    });
    final result = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final emailRepo = ref.watch(emailRepositoryProvider);
    final to = _emailController.text.trim();
    final name = _nameController.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Email Testing')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomCard(
              child: const Row(children: [
                Icon(Icons.science_outlined, color: AppColors.primaryGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Send real test emails through the Brevo integration. Use an inbox you can actually check.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            CustomTextField(
                controller: _emailController,
                label: 'Recipient Email',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            CustomTextField(
                controller: _nameController, label: 'Recipient Name'),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Send'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                CustomButton(
                  label: 'Send Test Email',
                  icon: Icons.bolt,
                  loading: _busy && _lastAction == 'Test Email',
                  onPressed: _busy
                      ? null
                      : () => _run(
                          'Test Email',
                          () => emailRepo.sendTestingEmail(widget.uid,
                              to: to, name: name)),
                ),
                CustomButton(
                  label: 'Send Welcome Email',
                  icon: Icons.waving_hand_outlined,
                  outlined: true,
                  loading: _busy && _lastAction == 'Welcome Email',
                  onPressed: _busy
                      ? null
                      : () => _run(
                          'Welcome Email',
                          () => emailRepo.sendWelcomeEmail(widget.uid,
                              to: to, name: name)),
                ),
                CustomButton(
                  label: 'Send Consultation Email',
                  icon: Icons.support_agent_outlined,
                  outlined: true,
                  loading: _busy && _lastAction == 'Consultation Email',
                  onPressed: _busy
                      ? null
                      : () => _run(
                            'Consultation Email',
                            () => emailRepo.sendConsultationConfirmation(
                                widget.uid,
                                to: to,
                                data: {
                                  'farmerName': name,
                                  'referenceNumber': 'ASF-TEST-000000',
                                  'date': DateTime.now().toIso8601String(),
                                  'summary':
                                      'This is a test consultation confirmation email sent from the Testing screen.',
                                  'expectedResponseTime': '1-2 business days',
                                }),
                          ),
                ),
                CustomButton(
                  label: 'Send Admin Notification',
                  icon: Icons.admin_panel_settings_outlined,
                  outlined: true,
                  loading: _busy && _lastAction == 'Admin Notification',
                  onPressed: _busy
                      ? null
                      : () => _run(
                            'Admin Notification',
                            () => emailRepo.sendAdminNotification(
                              widget.uid,
                              title: 'Test Admin Notification',
                              message:
                                  'This is a test admin notification sent from the Email Testing screen.',
                              category: 'test',
                            ),
                          ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_lastAction != null) ...[
              const SectionHeader(title: 'Result'),
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_lastAction!,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (_busy)
                      const Row(children: [
                        SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Sending...')
                      ])
                    else if (_lastResult != null) ...[
                      Row(children: [
                        Icon(
                          _lastResult!.success
                              ? Icons.check_circle
                              : (_lastResult!.queued
                                  ? Icons.schedule_send
                                  : Icons.error),
                          color: _lastResult!.success
                              ? Colors.green
                              : (_lastResult!.queued
                                  ? Colors.orange
                                  : Colors.red),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _lastResult!.success
                              ? 'Sent successfully'
                              : (_lastResult!.queued
                                  ? 'Failed — queued for automatic retry'
                                  : 'Failed'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ]),
                      if (_lastResult!.responseCode != null)
                        Text('HTTP status: ${_lastResult!.responseCode}',
                            style: const TextStyle(
                                fontSize: 12.5, color: Colors.black54)),
                      if (_lastResult!.error != null)
                        Text(_lastResult!.error!,
                            style: const TextStyle(
                                fontSize: 12.5, color: Colors.black54)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
