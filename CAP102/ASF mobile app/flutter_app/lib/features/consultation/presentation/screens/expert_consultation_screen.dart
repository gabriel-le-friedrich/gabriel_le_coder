// ══════════════════════════════════════════════════════════════════════
// ASF — Expert Consultation screen ("Expert Connection"). Farmer-facing
// form: Name, Email, Pig Batch, Current Weight, Issue Category, Problem
// Description, optional Photo. On submit, ConsultationController saves
// the request (offline-safe) and fires the admin + confirmation emails.
// ══════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/image_compression_service.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/consultation_entry.dart';
import '../providers/consultation_providers.dart';

class ExpertConsultationScreen extends ConsumerStatefulWidget {
  const ExpertConsultationScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<ExpertConsultationScreen> createState() =>
      _ExpertConsultationScreenState();
}

class _ExpertConsultationScreenState
    extends ConsumerState<ExpertConsultationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _pigBatchController = TextEditingController();
  final _weightController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _issueCategory = kConsultationIssueCategories.first;
  String? _photoPath;
  bool _prefilled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _pigBatchController.dispose();
    _weightController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _prefillFromProfile(Map<String, dynamic>? profile) {
    if (_prefilled || profile == null) return;
    _prefilled = true;
    _nameController.text = (profile['fullName'] as String?) ??
        (profile['full_name'] as String?) ??
        '';
    _emailController.text = (profile['email'] as String?) ?? '';
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 1280, maxHeight: 1280);
    if (picked == null) return;
    final compressed = await ImageCompressionService.compressToPath(
      sourcePath: picked.path,
      subfolder: 'consultation_photos',
      fileName: 'consult_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    if (!mounted) return;
    setState(() => _photoPath = compressed);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final controller =
        ref.read(consultationControllerProvider(widget.uid).notifier);
    final weightText = _weightController.text.trim();
    final entry = await controller.submit(
      farmerName: _nameController.text,
      farmerEmail: _emailController.text,
      pigBatch: _pigBatchController.text,
      currentWeight: weightText.isEmpty ? null : double.tryParse(weightText),
      issueCategory: _issueCategory,
      problemDescription: _descriptionController.text,
      localPhotoPath: _photoPath,
    );
    if (!mounted || entry == null) return;
    _showConfirmationDialog(entry);
  }

  void _showConfirmationDialog(ConsultationEntry entry) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle,
            color: AppColors.primaryGreen, size: 40),
        title: const Text('Request Submitted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Your consultation request has been sent. A confirmation email is on its way to you.'),
            const SizedBox(height: 12),
            Text('Reference #: ${entry.referenceNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const Text('Expected response: 1-2 business days',
                style: TextStyle(fontSize: 12.5, color: Colors.black54)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
    setState(() {
      _pigBatchController.clear();
      _weightController.clear();
      _descriptionController.clear();
      _photoPath = null;
      _issueCategory = kConsultationIssueCategories.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider(widget.uid));
    profileAsync.whenData(_prefillFromProfile);
    final state = ref.watch(consultationControllerProvider(widget.uid));
    final isSubmitting = state.valueOrNull?.isSubmitting ?? false;
    final errorMessage = state.valueOrNull?.errorMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('Expert Consultation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.support_agent, color: AppColors.primaryGreen),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Need help with a pig health, feeding, or growth issue? Reach out to an ATI agricultural expert.',
                          style: TextStyle(fontSize: 13.5),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Your Information'),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _nameController,
                label: 'Name',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Consultation Details'),
              const SizedBox(height: 8),
              CustomTextField(
                  controller: _pigBatchController,
                  label: 'Pig Batch (optional)',
                  hint: 'e.g. Batch 2 - Weaner pigs'),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _weightController,
                label: 'Current Weight (kg, optional)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return double.tryParse(v.trim()) == null
                      ? 'Enter a valid number'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _issueCategory,
                decoration: InputDecoration(
                    labelText: 'Issue Category',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
                items: kConsultationIssueCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _issueCategory = v ?? _issueCategory),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _descriptionController,
                label: 'Problem Description',
                hint: 'Describe what you\'re observing in detail',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please describe the issue'
                    : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: Icon(
                    _photoPath == null
                        ? Icons.add_a_photo_outlined
                        : Icons.check_circle,
                    size: 18),
                label: Text(_photoPath == null
                    ? 'Attach Photo (optional)'
                    : 'Photo attached'),
              ),
              if (_photoPath != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_photoPath!),
                      height: 140, fit: BoxFit.cover),
                ),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              CustomButton(
                label: 'Submit Request',
                icon: Icons.send,
                loading: isSubmitting,
                loadingLabel: 'Submitting...',
                onPressed: isSubmitting ? null : _submit,
              ),
              const SizedBox(height: 32),
              const SectionHeader(title: 'Your Past Requests'),
              const SizedBox(height: 8),
              ...?state.valueOrNull?.history.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CustomCard(
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              color: AppColors.primaryGreen, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.issueCategory,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5)),
                                Text(c.referenceNumber,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ),
                          StatusChip(
                              label: c.status,
                              color: c.status == 'resolved'
                                  ? AppColors.primaryGreen
                                  : Colors.orange),
                        ],
                      ),
                    ),
                  )),
              if ((state.valueOrNull?.history.isEmpty ?? true))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No consultation requests yet.',
                      style: TextStyle(color: Colors.black54, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
