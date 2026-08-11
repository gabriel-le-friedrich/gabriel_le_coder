// ══════════════════════════════════════════════════════════════════════
// Batch-level anchor data (starting weight/date, pig count) that ADG/FCR/
// ROI/Growth% are computed from — see dashboard_calculations.dart's
// currentAdg/currentFcr/computeRoi/growthPercent, all of which take
// startWeight/startDate/numPigs rather than reading a pig directly.
//
// Historically this was ONLY ever populated by the "Set Up Your Pig"
// onboarding wizard (now removed — pigs are created solely through Pig
// Management's Add Pig form instead). DashboardRepository.getPigBatchProfile()
// now synthesizes this from the pig list's oldest entry when no explicit
// row exists, so existing onboarded users' real saved profile still loads
// unchanged, while new users get one derived live from their real pig data
// once they add a pig — never fabricated placeholder values. See that
// method's doc for the exact fallback rule.
// ══════════════════════════════════════════════════════════════════════

class PigBatchProfile {
  const PigBatchProfile({
    required this.pigName,
    required this.batchName,
    required this.numPigs,
    required this.startWeight,
    required this.startDate, // ISO yyyy-MM-dd, matching the web app's date-string convention
    required this.feedPrice,
  });

  final String pigName;
  final String batchName;
  final int numPigs;
  final double startWeight;
  final String startDate;
  final double feedPrice;

  PigBatchProfile copyWith({
    String? pigName,
    String? batchName,
    int? numPigs,
    double? startWeight,
    String? startDate,
    double? feedPrice,
  }) {
    return PigBatchProfile(
      pigName: pigName ?? this.pigName,
      batchName: batchName ?? this.batchName,
      numPigs: numPigs ?? this.numPigs,
      startWeight: startWeight ?? this.startWeight,
      startDate: startDate ?? this.startDate,
      feedPrice: feedPrice ?? this.feedPrice,
    );
  }

  Map<String, dynamic> toJson() => {
        'pigName': pigName,
        'batchName': batchName,
        'numPigs': numPigs,
        'startWeight': startWeight,
        'startDate': startDate,
        'feedPrice': feedPrice,
      };

  factory PigBatchProfile.fromJson(Map<String, dynamic> json) =>
      PigBatchProfile(
        pigName: (json['pigName'] as String?) ?? '',
        batchName: (json['batchName'] as String?) ?? '',
        numPigs: (json['numPigs'] as num?)?.toInt() ?? 1,
        startWeight: (json['startWeight'] as num?)?.toDouble() ?? 0,
        startDate: (json['startDate'] as String?) ?? '',
        feedPrice: (json['feedPrice'] as num?)?.toDouble() ?? 0,
      );
}
