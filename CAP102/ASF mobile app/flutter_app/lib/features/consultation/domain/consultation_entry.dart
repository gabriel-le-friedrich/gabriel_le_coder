// ══════════════════════════════════════════════════════════════════════
// ASF — Expert Consultation domain model.
//
// A farmer-submitted request for help from an ATI (Agricultural Training
// Institute) expert. Mirrors public.consultations in
// supabase_schema_brevo.sql — keep both in sync.
// ══════════════════════════════════════════════════════════════════════

import 'dart:convert';

/// Fixed set of issue categories shown in the consultation form's dropdown.
/// Free-form categories were deliberately avoided so the admin-facing email
/// and any future triage/reporting can group requests reliably.
const List<String> kConsultationIssueCategories = [
  'Health / Disease Concern',
  'ASF Suspected Case',
  'Feeding / Nutrition',
  'Growth / Weight Concern',
  'Housing / Environment',
  'Breeding',
  'Other',
];

class ConsultationEntry {
  const ConsultationEntry({
    required this.id,
    required this.referenceNumber,
    required this.farmerName,
    required this.farmerEmail,
    required this.pigBatch,
    required this.currentWeight,
    required this.issueCategory,
    required this.problemDescription,
    required this.photoUrl,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String referenceNumber;
  final String farmerName;
  final String farmerEmail;
  final String? pigBatch;
  final double? currentWeight;
  final String issueCategory;
  final String problemDescription;
  final String? photoUrl;
  final String status; // pending | reviewed | resolved
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'referenceNumber': referenceNumber,
        'farmerName': farmerName,
        'farmerEmail': farmerEmail,
        'pigBatch': pigBatch,
        'currentWeight': currentWeight,
        'issueCategory': issueCategory,
        'problemDescription': problemDescription,
        'photoUrl': photoUrl,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ConsultationEntry.fromJson(Map<String, dynamic> json) =>
      ConsultationEntry(
        id: json['id'] as String,
        referenceNumber: json['referenceNumber'] as String? ?? '',
        farmerName: json['farmerName'] as String? ?? '',
        farmerEmail: json['farmerEmail'] as String? ?? '',
        pigBatch: json['pigBatch'] as String?,
        currentWeight: (json['currentWeight'] as num?)?.toDouble(),
        issueCategory: json['issueCategory'] as String? ?? '',
        problemDescription: json['problemDescription'] as String? ?? '',
        photoUrl: json['photoUrl'] as String?,
        status: json['status'] as String? ?? 'pending',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  /// From a SQLite `consultations` row (id/uid/data JSON/createdAt/...).
  /// Never throws — a corrupted row decodes to an empty-ish entry rather
  /// than blowing up the whole list, matching this app's established
  /// "one bad record can't break the list" defensive-parsing convention
  /// (see mapSafely / HealthRepository.getHealthLogs).
  factory ConsultationEntry.fromRow(Map<String, dynamic> row) {
    Map<String, dynamic> decoded = const {};
    final raw = row['data'];
    if (raw is String && raw.isNotEmpty) {
      try {
        decoded = (jsonDecode(raw) as Map).cast<String, dynamic>();
      } catch (_) {
        decoded = const {};
      }
    }
    return ConsultationEntry.fromJson({...decoded, 'id': row['id']});
  }
}
