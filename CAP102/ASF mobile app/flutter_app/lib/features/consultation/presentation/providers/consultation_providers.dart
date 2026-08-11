// ══════════════════════════════════════════════════════════════════════
// Riverpod state for the Expert Consultation feature. Submitting a
// request: (1) optionally uploads the photo, (2) saves the consultation
// locally + best-effort Supabase push (ConsultationRepository — always
// succeeds from the UI's perspective, even fully offline), then
// (3) fires the two Brevo emails (request -> admin, confirmation ->
// farmer) through EmailRepository, which itself never throws and queues
// on failure. A slow/failed email NEVER blocks the "request submitted"
// confirmation the farmer sees — matches spec item 11.
// ══════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../email/data/email_repository.dart';
import '../../../email/presentation/providers/email_providers.dart';
import '../../data/consultation_repository.dart';
import '../../domain/consultation_entry.dart';

final consultationRepositoryProvider =
    Provider<ConsultationRepository>((ref) => ConsultationRepository());

class ConsultationState {
  const ConsultationState({
    required this.history,
    this.isSubmitting = false,
    this.errorMessage,
    this.lastSubmitted,
  });

  final List<ConsultationEntry> history;
  final bool isSubmitting;
  final String? errorMessage;
  final ConsultationEntry? lastSubmitted;

  ConsultationState copyWith({
    List<ConsultationEntry>? history,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    ConsultationEntry? lastSubmitted,
    bool clearLastSubmitted = false,
  }) {
    return ConsultationState(
      history: history ?? this.history,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastSubmitted:
          clearLastSubmitted ? null : (lastSubmitted ?? this.lastSubmitted),
    );
  }
}

class ConsultationController
    extends StateNotifier<AsyncValue<ConsultationState>> {
  ConsultationController(this._repo, this._emailRepo, this._authRepo, this._uid)
      : super(const AsyncValue.loading()) {
    load();
  }

  final ConsultationRepository _repo;
  final EmailRepository _emailRepo;
  final AuthRepository _authRepo;
  final String _uid;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final history = await _repo.getConsultations(_uid);
      state = AsyncValue.data(ConsultationState(history: history));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<ConsultationEntry?> submit({
    required String farmerName,
    required String farmerEmail,
    String? pigBatch,
    double? currentWeight,
    required String issueCategory,
    required String problemDescription,
    String? localPhotoPath,
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitting) return null;
    if (farmerName.trim().isEmpty ||
        farmerEmail.trim().isEmpty ||
        problemDescription.trim().isEmpty) {
      state = AsyncValue.data(current.copyWith(
          errorMessage: 'Please fill in all required fields.'));
      return null;
    }
    state = AsyncValue.data(current.copyWith(
        isSubmitting: true, clearError: true, clearLastSubmitted: true));

    String? photoUrl;
    if (localPhotoPath != null) {
      photoUrl = await _repo.uploadConsultationPhoto(_uid, localPhotoPath);
      // Upload failure is not fatal — the request still gets submitted
      // without a photo (photoUrl stays null).
    }

    ConsultationEntry entry;
    try {
      entry = await _repo.submitConsultation(
        _uid,
        farmerName: farmerName.trim(),
        farmerEmail: farmerEmail.trim(),
        pigBatch: pigBatch?.trim().isEmpty == true ? null : pigBatch?.trim(),
        currentWeight: currentWeight,
        issueCategory: issueCategory,
        problemDescription: problemDescription.trim(),
        photoUrl: photoUrl,
      );
    } catch (e) {
      state = AsyncValue.data(current.copyWith(
          isSubmitting: false,
          errorMessage: 'Could not save your request. Please try again.'));
      return null;
    }

    await _authRepo.recordActivityLog(
      uid: _uid,
      actionType: 'consultation',
      description:
          'Submitted expert consultation request ${entry.referenceNumber}',
      action: 'CONSULTATION_SUBMIT',
      status: 'SUCCESS',
    );

    final submittedAtLabel =
        DateFormat('MMM d, yyyy • h:mm a').format(entry.createdAt);

    // Fire both emails without blocking the UI on their outcome — each
    // call already has its own retry+queue fallback (EmailRepository).
    unawaited(_emailRepo.sendConsultationRequest(_uid, data: {
      'referenceNumber': entry.referenceNumber,
      'farmerName': entry.farmerName,
      'farmerEmail': entry.farmerEmail,
      'pigBatch': entry.pigBatch,
      'currentWeight': entry.currentWeight,
      'issueCategory': entry.issueCategory,
      'problemDescription': entry.problemDescription,
      'photoUrl': entry.photoUrl,
      'submittedAt': submittedAtLabel,
    }));
    unawaited(_emailRepo.sendConsultationConfirmation(
      _uid,
      to: entry.farmerEmail,
      data: {
        'farmerName': entry.farmerName,
        'referenceNumber': entry.referenceNumber,
        'date': submittedAtLabel,
        'summary': '${entry.issueCategory} — ${entry.problemDescription}',
        'expectedResponseTime': '1-2 business days',
      },
    ));

    final refreshed = await _repo.getConsultations(_uid);
    state = AsyncValue.data(
        ConsultationState(history: refreshed, lastSubmitted: entry));
    return entry;
  }
}

final consultationControllerProvider = StateNotifierProvider.autoDispose
    .family<ConsultationController, AsyncValue<ConsultationState>, String>(
  (ref, uid) => ConsultationController(
    ref.watch(consultationRepositoryProvider),
    ref.watch(emailRepositoryProvider),
    ref.watch(authRepositoryProvider),
    uid,
  ),
);
