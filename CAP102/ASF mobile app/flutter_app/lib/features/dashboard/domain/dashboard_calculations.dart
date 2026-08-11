// ══════════════════════════════════════════════════════════════════════
// Pure calculation functions — Flutter port of the "OFFICIAL ATI FARM
// ADMINISTRATION MANUAL FORMULAS" block in index.html. No DB access here;
// everything takes already-loaded data in and returns a number/null, so
// these are trivially unit-testable and match the web app's formulas
// exactly (comments below are copied from there for the same reasoning).
// ══════════════════════════════════════════════════════════════════════

const int kMaxProductionDay = 120;
const double kMarketPricePerKg = 191.51;

/// The SINGLE reusable "which production week is this day in" formula.
/// Production day advances only via the manual "Proceed to Next Day"
/// counter (getCurrentDay()/advanceDay() in DashboardRepository) — this
/// stays date-independent on purpose (see computeProductionDayFallback's
/// doc and the project decision to keep week/day progression decoupled
/// from the calendar, so a farmer who misses logging in on a real day
/// never gets silently skipped ahead). Every screen that needs "what week
/// is it right now" (Dashboard weight card, Growth screen, the weekly
/// photo unlock gate) must call this instead of re-deriving the formula,
/// so there is exactly one definition to ever change.
int weekNumberForDay(int day) => ((day - 1) ~/ 7) + 1;

const int adgTargetMin = 600; // g/day — lower bound of "Healthy"
const int adgTargetMax = 700; // g/day — upper bound of "Healthy"
const int adgBelowMin = 500; // g/day — lower bound of "Below Target"

/// A single point in the batch's weight timeline. The Day-1 baseline entry
/// seeded by Onboarding has isOfficial=false (it's a starting point, not a
/// weigh-in); every entry added through the Growth module's "Add Weekly
/// Weigh-in" action has isOfficial=true — this is the exact flag that backs
/// hasRecordedWeighIn()/the Starting Weight lock, and distinguishes a real
/// weigh-in from the seed row when checking for a duplicate in the same
/// production week. weekNumber is persisted (not just derived) so historical
/// points keep the week they were actually recorded in even if the formula
/// here ever changes.
class WeightLogEntry {
  const WeightLogEntry({
    required this.day,
    required this.weight,
    required this.date,
    int? weekNumber,
    this.notes = '',
    this.isOfficial = false,
  }) : _weekNumber = weekNumber;

  final int day;
  final double weight;
  final String date; // yyyy-MM-dd
  final String notes;
  final bool isOfficial;
  final int? _weekNumber;

  /// Production week — matches totalWeeksInCycle()'s numbering elsewhere
  /// (ceil(day/7), 1-indexed). Falls back to a derived value for any entry
  /// (e.g. the Day-1 seed) that predates this field.
  int get weekNumber => _weekNumber ?? (((day - 1) ~/ 7) + 1);

  WeightLogEntry copyWith({double? weight, String? date, String? notes}) =>
      WeightLogEntry(
        day: day,
        weight: weight ?? this.weight,
        date: date ?? this.date,
        weekNumber: _weekNumber,
        notes: notes ?? this.notes,
        isOfficial: isOfficial,
      );

  factory WeightLogEntry.fromJson(Map<String, dynamic> json) => WeightLogEntry(
        day: (json['day'] as num?)?.toInt() ?? 0,
        weight: (json['weight'] as num?)?.toDouble() ?? 0,
        date: (json['date'] as String?) ?? '',
        weekNumber: (json['weekNumber'] as num?)?.toInt(),
        notes: (json['notes'] as String?) ?? '',
        isOfficial: json['isOfficial'] == true,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'weight': weight,
        'date': date,
        'weekNumber': weekNumber,
        'notes': notes,
        'isOfficial': isOfficial,
      };
}

class FeedLogEntry {
  const FeedLogEntry(
      {required this.day, required this.date, required this.feedKg});
  final int day;
  final String date;
  final double feedKg;

  factory FeedLogEntry.fromJson(Map<String, dynamic> json) => FeedLogEntry(
        day: (json['day'] as num?)?.toInt() ?? 0,
        date: (json['date'] as String?) ?? '',
        feedKg: (json['feedKg'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'day': day, 'date': date, 'feedKg': feedKg};
}

class ExpenseEntry {
  const ExpenseEntry({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    this.note = '',
    this.firebaseUid = '',
    String? createdAt,
    String? updatedAt,
  })  : _createdAt = createdAt,
        _updatedAt = updatedAt;

  final int id;
  final String category;
  final String description;
  final double amount;
  final String date;
  final String note;
  final String firebaseUid;
  final String? _createdAt;
  final String? _updatedAt;

  String get createdAt => _createdAt ?? date;
  String get updatedAt => _updatedAt ?? createdAt;

  ExpenseEntry copyWith({
    String? category,
    String? description,
    double? amount,
    String? date,
    String? note,
    String? updatedAt,
  }) {
    return ExpenseEntry(
      id: id,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      firebaseUid: firebaseUid,
      createdAt: _createdAt,
      updatedAt: updatedAt ?? _updatedAt,
    );
  }

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) => ExpenseEntry(
        id: (json['id'] as num?)?.toInt() ?? 0,
        category: (json['category'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        date: (json['date'] as String?) ?? '',
        note: (json['note'] as String?) ?? '',
        firebaseUid: (json['firebaseUid'] as String?) ?? '',
        createdAt: json['createdAt'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'description': description,
        'amount': amount,
        'date': date,
        'note': note,
        'firebaseUid': firebaseUid,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

/// Growth stage the ATI manual bands pigs into by live weight — also
/// determines the daily feed allowance auto-recorded when a day is advanced.
class PigStage {
  const PigStage(
      {required this.key,
      required this.name,
      required this.range,
      required this.feedKgPerDay});
  final String key;
  final String name;
  final String range;
  final double feedKgPerDay;
}

PigStage stageForWeight(double weight) {
  if (weight < 80)
    return const PigStage(
        key: 'early',
        name: 'Early Finisher',
        range: '60–80 kg',
        feedKgPerDay: 2.5);
  if (weight < 100)
    return const PigStage(
        key: 'mid',
        name: 'Mid Finisher',
        range: '80–100 kg',
        feedKgPerDay: 3.0);
  return const PigStage(
      key: 'late',
      name: 'Late Finisher',
      range: '100–120 kg',
      feedKgPerDay: 3.2);
}

/// Ordered list of every feed-allowance band stageForWeight() can return —
/// backs the Feeding Guide's Growth Timeline and improved Stage Guide table.
/// Deliberately just these three (the ATI manual doesn't define a
/// "Starter"/"Grower" band before Early Finisher — this app's cycle starts
/// pigs at 60kg), plus a trailing Market Ready milestone once the batch
/// reaches kMarketWeightKg, so the timeline still ends on a real finish line.
const List<PigStage> kPigStages = [
  PigStage(
      key: 'early',
      name: 'Early Finisher',
      range: '60–80 kg',
      feedKgPerDay: 2.5),
  PigStage(
      key: 'mid', name: 'Mid Finisher', range: '80–100 kg', feedKgPerDay: 3.0),
  PigStage(
      key: 'late',
      name: 'Late Finisher',
      range: '100–120 kg',
      feedKgPerDay: 3.2),
];

/// The stage that follows [current] in kPigStages, or null once already in
/// the last defined feed-allowance band (Late Finisher) — callers treat
/// null as "next milestone is Market Ready" rather than another band.
PigStage? nextStage(PigStage current) {
  final idx = kPigStages.indexWhere((s) => s.key == current.key);
  if (idx == -1 || idx >= kPigStages.length - 1) return null;
  return kPigStages[idx + 1];
}

/// Weight (kg) at which [stage] hands off to the next band — mirrors
/// stageForWeight()'s own thresholds (80/100/120) so this can never drift
/// out of sync with the real classification logic.
double stageUpperBoundKg(PigStage stage) {
  if (stage.key == 'early') return 80;
  if (stage.key == 'mid') return 100;
  return kMarketWeightKg;
}

/// Weight (kg) at which [stage] begins — the counterpart to
/// stageUpperBoundKg(), used to compute how far through the current band
/// the batch has progressed (e.g. the Feeding Guide hero card's progress
/// bar).
double stageLowerBoundKg(PigStage stage) {
  if (stage.key == 'early') return 60;
  if (stage.key == 'mid') return 80;
  return 100;
}

/// Estimated whole days until [currentWeight] reaches [targetWeightKg],
/// using the batch's current ADG (g/day) — the same figure already shown on
/// the Dashboard. Null when ADG isn't known yet (no official weekly weigh-in
/// recorded) since there's no real trend to project from; 0 once the target
/// is already met.
int? daysUntilWeight(
    {required double currentWeight,
    required double targetWeightKg,
    required double? adg}) {
  if (adg == null || adg <= 0) return null;
  final remainingKg = targetWeightKg - currentWeight;
  if (remainingKg <= 0) return 0;
  return (remainingKg / (adg / 1000)).ceil();
}

/// Feed cost (₱) for a given daily feed allowance at the current price —
/// shared by the Feeding Guide's "Today's Feed Cost" and the Feed
/// Calculator's projections, so both always agree.
double feedCostForDays(
        {required double feedKgPerDay,
        required double feedPricePerKg,
        int days = 1}) =>
    feedKgPerDay * feedPricePerKg * days;

/// Real feed actually recorded (kg) for the production week [currentDay]
/// falls in — same week-numbering formula as WeightLogEntry.weekNumber
/// (ceil(day/7), 1-indexed), so "This Week" in the Feeding Guide's Feed
/// Statistics card always agrees with how weeks are counted everywhere
/// else in the app. Only sums entries that actually exist in feedLogs
/// (auto-recorded on advanceDay) — never a projection.
double feedConsumedForWeek(
    {required List<FeedLogEntry> feedLogs, required int currentDay}) {
  final weekNumber = ((currentDay - 1) ~/ 7) + 1;
  return feedLogs
      .where((f) => (((f.day - 1) ~/ 7) + 1) == weekNumber)
      .fold<double>(0, (sum, f) => sum + f.feedKg);
}

/// Production Day — a decoupled-from-the-calendar, independently persisted
/// counter (see the Flutter port's DashboardRepository.getCurrentDay). This
/// helper is ONLY the one-time migration/first-run fallback calculation —
/// "days elapsed since Start Date" — used to seed the counter if it's ever
/// missing, never the ongoing source of truth. Matches computeProductionDay()
/// in index.html exactly.
int computeProductionDayFallback(String? startDateIso) {
  if (startDateIso == null || startDateIso.isEmpty) return 1;
  final start = DateTime.tryParse(startDateIso);
  if (start == null) return 1;
  final today = DateTime.now();
  final startDay = DateTime(start.year, start.month, start.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  final elapsedDays = todayDay.difference(startDay).inDays;
  return (elapsedDays + 1).clamp(1, kMaxProductionDay);
}

/// True once at least one real weekly weigh-in (as opposed to the Day-1
/// baseline seed) has been recorded. This is THE gate for both the "Weekly
/// weight required." dashboard state and the Starting Weight edit lock — see
/// PigDetailController/pig_detail_screen.dart.
bool hasOfficialWeighIn(List<WeightLogEntry> weightLogs) =>
    weightLogs.any((e) => e.isOfficial);

/// The most recent official weigh-in (by production day), or null if none
/// exists yet. Deliberately NOT just `.last` — list order is expected to be
/// chronological but official-ness, not position, is what actually matters.
WeightLogEntry? latestOfficialEntry(List<WeightLogEntry> weightLogs) {
  final official = weightLogs.where((e) => e.isOfficial).toList()
    ..sort((a, b) => a.day.compareTo(b.day));
  return official.isEmpty ? null : official.last;
}

/// Calendar days from the batch Start Date to the latest OFFICIAL weigh-in
/// date (the Day-1 seed is never a valid endpoint for this calculation).
int? fatteningDaysElapsed(
    {required String? startDateIso, required List<WeightLogEntry> weightLogs}) {
  final latest = latestOfficialEntry(weightLogs);
  if (latest == null || startDateIso == null || startDateIso.isEmpty)
    return null;
  final start = DateTime.tryParse(startDateIso);
  final end =
      DateTime.tryParse(latest.date.isNotEmpty ? latest.date : startDateIso);
  if (start == null || end == null) return null;
  return end.difference(start).inDays;
}

/// ADG = ((Current Weight − Starting Weight) ÷ Fattening Days) × 1000.
/// Returns null until a real weekly weigh-in exists beyond the Day-1
/// baseline — same "Weekly weight required" gate as the web app's
/// hasRecordedWeighIn() guard.
double? currentAdg({
  required double? startWeight,
  required String? startDateIso,
  required List<WeightLogEntry> weightLogs,
}) {
  final latest = latestOfficialEntry(weightLogs);
  if (latest == null || startWeight == null) return null;
  final days =
      fatteningDaysElapsed(startDateIso: startDateIso, weightLogs: weightLogs);
  if (days == null || days <= 0) return null;
  final gain = latest.weight - startWeight;
  return (gain / days) * 1000;
}

/// FCR = Total Feed Consumed (kg) ÷ (Current Weight − Starting Weight).
/// Same "Weekly weight required" gate as currentAdg().
double? currentFcr({
  required double? startWeight,
  required String? startDateIso,
  required List<WeightLogEntry> weightLogs,
  required List<FeedLogEntry> feedLogs,
}) {
  final latest = latestOfficialEntry(weightLogs);
  if (latest == null || startWeight == null) return null;
  final gain = latest.weight - startWeight;
  if (gain <= 0) return null;
  final totalFeed = feedLogs
      .where((f) =>
          startDateIso == null ||
          startDateIso.isEmpty ||
          f.date.compareTo(startDateIso) >= 0)
      .fold<double>(0, (sum, f) => sum + f.feedKg);
  return totalFeed / gain;
}

/// Target live market weight (kg) — top of the ATI manual's "Late Finisher"
/// band (100–120 kg) — used only for the Dashboard's "Growth %" progress
/// stat, not for ADG/FCR/ROI.
const double kMarketWeightKg = 120.0;

/// Percent of the way from Starting Weight to market weight the batch has
/// grown, based on the latest official weigh-in. Null until a starting
/// weight is known.
double? growthPercent(
    {required double? startWeight, required double currentWeight}) {
  if (startWeight == null || kMarketWeightKg <= startWeight) return null;
  final pct =
      ((currentWeight - startWeight) / (kMarketWeightKg - startWeight)) * 100;
  return pct.clamp(0, 100);
}

/// One plotted point in a Growth chart — x is the production week number.
class ChartPoint {
  const ChartPoint({required this.week, required this.value});
  final int week;
  final double value;
}

/// Weight vs Week — every recorded point (baseline + every official
/// weigh-in), chronological.
List<ChartPoint> weightVsWeekSeries(List<WeightLogEntry> weightLogs) {
  final sorted = [...weightLogs]..sort((a, b) => a.day.compareTo(b.day));
  return sorted
      .map((e) => ChartPoint(week: e.weekNumber, value: e.weight))
      .toList();
}

/// ADG trend — the ADG that WOULD have been reported at each official
/// weigh-in, using the same formula as currentAdg() evaluated as of that
/// point in history (not just the latest).
List<ChartPoint> adgTrendSeries({
  required double? startWeight,
  required String? startDateIso,
  required List<WeightLogEntry> weightLogs,
}) {
  if (startWeight == null || startDateIso == null || startDateIso.isEmpty)
    return [];
  final start = DateTime.tryParse(startDateIso);
  if (start == null) return [];
  final official = weightLogs.where((e) => e.isOfficial).toList()
    ..sort((a, b) => a.day.compareTo(b.day));
  final points = <ChartPoint>[];
  for (final e in official) {
    final end = DateTime.tryParse(e.date);
    if (end == null) continue;
    final days = end.difference(start).inDays;
    if (days <= 0) continue;
    final gain = e.weight - startWeight;
    points.add(ChartPoint(week: e.weekNumber, value: (gain / days) * 1000));
  }
  return points;
}

/// FCR trend — cumulative feed-to-date ÷ cumulative gain-to-date, evaluated
/// as of each official weigh-in.
List<ChartPoint> fcrTrendSeries({
  required double? startWeight,
  required String? startDateIso,
  required List<WeightLogEntry> weightLogs,
  required List<FeedLogEntry> feedLogs,
}) {
  if (startWeight == null) return [];
  final official = weightLogs.where((e) => e.isOfficial).toList()
    ..sort((a, b) => a.day.compareTo(b.day));
  final points = <ChartPoint>[];
  for (final e in official) {
    final gain = e.weight - startWeight;
    if (gain <= 0) continue;
    final totalFeed = feedLogs
        .where((f) =>
            f.day <= e.day &&
            (startDateIso == null ||
                startDateIso.isEmpty ||
                f.date.compareTo(startDateIso) >= 0))
        .fold<double>(0, (sum, f) => sum + f.feedKg);
    if (totalFeed <= 0) continue;
    points.add(ChartPoint(week: e.weekNumber, value: totalFeed / gain));
  }
  return points;
}

class RoiResult {
  const RoiResult(
      {required this.totalInvested,
      required this.projectedRevenue,
      required this.netProfit,
      required this.roiPercent});
  final double totalInvested;
  final double projectedRevenue;
  final double netProfit;
  final double roiPercent;
  bool get profitable => netProfit >= 0;
}

/// Projected Net Profit & ROI — single source of truth shared by the
/// Dashboard summary card and the (future) Expenses & ROI page. Matches
/// loadData()'s calculation exactly: projected revenue assumes the pig
/// sells at market weight × market price/kg, scaled by a 1.55 dressed-weight
/// factor (the ATI manual's live-to-dressed-weight conversion).
RoiResult computeRoi(
    {required double currentWeight, required List<ExpenseEntry> expenses}) {
  final totalInvested = expenses.fold<double>(0, (sum, e) => sum + e.amount);
  final projectedRevenue = currentWeight * kMarketPricePerKg * 1.55;
  final netProfit = projectedRevenue - totalInvested;
  final roi = totalInvested > 0 ? (netProfit / totalInvested) * 100 : 0.0;
  return RoiResult(
      totalInvested: totalInvested,
      projectedRevenue: projectedRevenue,
      netProfit: netProfit,
      roiPercent: roi);
}

enum AdgStatusTier { poor, below, healthy, excellent }

AdgStatusTier? adgStatusTier(double? adg) {
  if (adg == null) return null;
  if (adg < adgBelowMin) return AdgStatusTier.poor;
  if (adg < adgTargetMin) return AdgStatusTier.below;
  if (adg <= adgTargetMax) return AdgStatusTier.healthy;
  return AdgStatusTier.excellent;
}

/// FCR has no existing classification in this app (unlike ADG's
/// adgStatusTier above) — this is a new, deliberately simple, conservative
/// swine grow-finish benchmark added for the Weight & ADG screen's FCR
/// status badge: at or below [kFcrGoodMax] is "Good", anything higher is
/// "Needs Improvement". Purely a display classification — it does not
/// feed into ROI, feed recommendations, or any other calculation, and can
/// be tuned independently later without affecting FCR itself.
const double kFcrGoodMax = 3.0;

enum FcrStatusTier { good, needsImprovement }

FcrStatusTier? fcrStatusTier(double? fcr) {
  if (fcr == null) return null;
  return fcr <= kFcrGoodMax
      ? FcrStatusTier.good
      : FcrStatusTier.needsImprovement;
}

/// Cumulative feed consumed (kg) as of each official weigh-in — the exact
/// same running total already computed inside fcrTrendSeries() (see its
/// `totalFeed` calc below), exposed as its own series so the Weight & ADG
/// screen's FCR History rows can show "Feed Consumed: X kg" without
/// duplicating or ever drifting from the real FCR formula. Skips the same
/// entries fcrTrendSeries() skips (no positive gain yet) so the two series
/// always line up 1:1 by week.
List<ChartPoint> feedConsumedTrendSeries({
  required double? startWeight,
  required String? startDateIso,
  required List<WeightLogEntry> weightLogs,
  required List<FeedLogEntry> feedLogs,
}) {
  if (startWeight == null) return [];
  final official = weightLogs.where((e) => e.isOfficial).toList()
    ..sort((a, b) => a.day.compareTo(b.day));
  final points = <ChartPoint>[];
  for (final e in official) {
    final gain = e.weight - startWeight;
    if (gain <= 0) continue;
    final totalFeed = feedLogs
        .where((f) =>
            f.day <= e.day &&
            (startDateIso == null ||
                startDateIso.isEmpty ||
                f.date.compareTo(startDateIso) >= 0))
        .fold<double>(0, (sum, f) => sum + f.feedKg);
    if (totalFeed <= 0) continue;
    points.add(ChartPoint(week: e.weekNumber, value: totalFeed));
  }
  return points;
}
