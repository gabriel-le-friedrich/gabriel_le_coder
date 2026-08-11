import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/routing/app_router.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/domain/dashboard_calculations.dart'
    show
        AdgStatusTier,
        ChartPoint,
        FcrStatusTier,
        WeightLogEntry,
        adgStatusTier,
        adgTargetMax,
        adgTargetMin,
        daysUntilWeight,
        fcrStatusTier,
        kFcrGoodMax,
        kMarketWeightKg,
        kMaxProductionDay,
        kPigStages,
        nextStage,
        stageForWeight,
        stageUpperBoundKg;
import '../../../dashboard/presentation/providers/dashboard_providers.dart'
    show dashboardControllerProvider;
import '../../../dashboard/presentation/widgets/dashboard_app_bar_actions.dart';
import '../../../growth/presentation/providers/growth_providers.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/pig.dart';
import '../../domain/weekly_pig_image.dart';
import '../providers/pig_providers.dart';
import '../theme/pig_growth_palette.dart';

/// Total weekly-photo slots across the 120-day cycle — matches
/// totalWeeksInCycle() in index.html (ceil(120/7) = 18). The final slot is
/// additionally labeled "Market Day" per the mobile spec's timeline
/// description, on top of (not instead of) its week number.
final int kTotalCycleWeeks = (kMaxProductionDay / 7).ceil();

// ══════════════════════════════════════════════════════════════════════
// Growth History — redesigned from a bare weekly-photo timeline into a
// full per-pig growth dashboard: a real weight chart + timeline (the same
// batch-level weigh-in data GrowthScreen/GrowthController already track —
// weigh-ins are recorded once for the whole batch, not per individual pig,
// see growth_providers.dart's file header), an inline Record New Weight
// card (same addWeighIn()/duplicate-guard logic), the existing Weekly
// Progress Photos capture flow (restyled, unchanged behavior), a before/
// after Growth Comparison slider built from this pig's real captured
// photos, and a Notes card wired to WeeklyPigImage.notes.
//
// Nothing here changes any calculation, repository signature, or model
// field beyond one small, explicitly-justified addition:
// PigRepository.updateWeeklyImageNotes() (see its doc), needed because the
// existing schema had a notes field with no save path from the UI yet.
// ══════════════════════════════════════════════════════════════════════
class PigDetailScreen extends ConsumerStatefulWidget {
  const PigDetailScreen({super.key, required this.pigId});
  final String pigId;

  @override
  ConsumerState<PigDetailScreen> createState() => _PigDetailScreenState();
}

class _PigDetailScreenState extends ConsumerState<PigDetailScreen> {
  int? _weekA;
  int? _weekB;
  final _recordWeightKey = GlobalKey();
  final _weeklyPhotosKey = GlobalKey();

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pigAsync = ref.watch(pigDetailControllerProvider(widget.pigId));
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final fullName =
        ref.watch(userProfileProvider(uid)).valueOrNull?['fullName'] as String?;
    final controller =
        ref.read(pigDetailControllerProvider(widget.pigId).notifier);
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: PigGrowthPalette.background,
      appBar: AppBar(
        backgroundColor: PigGrowthPalette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
            pigAsync.valueOrNull?.name ?? tr(lang, 'growthHistoryTitle'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black87)),
        actions: [
          if (pigAsync.valueOrNull != null) ...[
            IconButton(
              icon: const Icon(Icons.calendar_view_month,
                  color: PigGrowthPalette.darkText),
              tooltip: tr(lang, 'calendarViewTooltip'),
              onPressed: () async {
                final week = await context
                    .push<int>('${AppRoutes.pigs}/${widget.pigId}/calendar');
                if (week != null) setState(() => _weekB = week);
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: PigGrowthPalette.darkText),
              tooltip: tr(lang, 'editPigTooltip'),
              onPressed: () => context.push(
                  '${AppRoutes.pigs}/${widget.pigId}/edit',
                  extra: pigAsync.valueOrNull),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DashboardAppBarActions(uid: uid, fullName: fullName),
          ),
        ],
      ),
      body: pigAsync.when(
        data: (pig) {
          if (pig == null)
            return Center(child: Text(tr(lang, 'pigNotFoundMessage')));
          final weeklyImagesAsync =
              ref.watch(weeklyImagesProvider((uid: uid, pigId: widget.pigId)));
          final growthAsync = ref.watch(growthControllerProvider(uid));
          final images = weeklyImagesAsync.valueOrNull ?? const [];
          final completedWeeks = images.map((i) => i.weekNumber).toSet().length;
          final sortedCaptureDates = images
              .map((i) => i.captureDate)
              .where((d) => d.isNotEmpty)
              .toList()
            ..sort();
          final latestUpload =
              sortedCaptureDates.isEmpty ? null : sortedCaptureDates.last;
          final currentWeekNumber = growthAsync.valueOrNull?.currentWeekNumber;

          return RefreshIndicator(
            onRefresh: () async {
              await controller.load();
              ref.invalidate(
                  weeklyImagesProvider((uid: uid, pigId: widget.pigId)));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: pigGrowthAnimatedChildren([
                _PigIdentityCard(
                    pig: pig,
                    lang: lang,
                    completedWeeks: completedWeeks,
                    latestUpload: latestUpload),
                const SizedBox(height: 16),
                _GrowthProgressCard(
                    completedWeeks: completedWeeks,
                    currentWeekNumber: currentWeekNumber,
                    lang: lang),
                const SizedBox(height: 16),
                // "Growth & Performance" — every card in this block reads
                // the same batch-level GrowthData (weight/ADG/FCR/production
                // day are recorded once per production batch, not per
                // individual pig — see this file's header comment), so the
                // section carries ONE disclaimer up top instead of repeating
                // it on every card inside.
                growthAsync.when(
                  data: (data) => Column(
                    key: _recordWeightKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(lang, 'herdGrowthSectionTitle'),
                          style: pigGrowthSectionTitleStyle),
                      const SizedBox(height: 6),
                      Text(tr(lang, 'herdGrowthDisclaimer'),
                          style: const TextStyle(
                              fontSize: 11,
                              color: PigGrowthPalette.grayText,
                              fontStyle: FontStyle.italic)),
                      const SizedBox(height: 12),
                      _HerdGrowthCard(data: data, lang: lang),
                      const SizedBox(height: 16),
                      _GrowthAnalyticsSection(data: data, lang: lang),
                      const SizedBox(height: 16),
                      _ProductionStageCard(data: data, lang: lang),
                      const SizedBox(height: 16),
                      _GrowthMilestonesCard(data: data, lang: lang),
                      const SizedBox(height: 16),
                      _GrowthChartCard(points: data.weightSeries, lang: lang),
                      const SizedBox(height: 16),
                      _WeightTimelineCard(
                          weightLogs: data.weightLogs, lang: lang),
                      const SizedBox(height: 16),
                      _RecordWeightCard(uid: uid, lang: lang),
                      const SizedBox(height: 16),
                      _WeighInHistoryCard(
                        uid: uid,
                        weightLogs: data.weightLogs,
                        adgSeries: data.adgSeries,
                        lang: lang,
                      ),
                      const SizedBox(height: 16),
                      _FcrHistoryCard(
                        weightLogs: data.weightLogs,
                        fcrSeries: data.fcrSeries,
                        feedConsumedSeries: data.feedConsumedSeries,
                        lang: lang,
                      ),
                    ],
                  ),
                  loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator())),
                  error: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(tr(lang, 'couldNotLoadWeightRecords'),
                        style:
                            const TextStyle(color: PigGrowthPalette.grayText)),
                  ),
                ),
                const SizedBox(height: 16),
                _WeeklyMilestoneRow(
                  images: images,
                  currentWeekNumber: currentWeekNumber,
                  lang: lang,
                  onViewAll: () => context
                      .push('${AppRoutes.pigs}/${widget.pigId}/calendar'),
                ),
                const SizedBox(height: 16),
                _LatestPhotoCard(
                  images: images,
                  lang: lang,
                  onViewAll: () => context
                      .push('${AppRoutes.pigs}/${widget.pigId}/calendar'),
                  onAddPhoto: () => _scrollToKey(_weeklyPhotosKey),
                ),
                const SizedBox(height: 16),
                Container(key: _weeklyPhotosKey),
                _WeeklyPhotosCard(
                  images: images,
                  lang: lang,
                  currentWeekNumber: growthAsync.valueOrNull?.currentWeekNumber,
                  onCapture: (week, existing) =>
                      _captureImage(context, ref, week, existing, lang),
                ),
                const SizedBox(height: 16),
                _GrowthComparisonCard(
                  images: images,
                  weekA: _weekA,
                  weekB: _weekB,
                  lang: lang,
                  onWeekAChanged: (w) => setState(() => _weekA = w),
                  onWeekBChanged: (w) => setState(() => _weekB = w),
                ),
                const SizedBox(height: 16),
                _NotesCard(
                  images: images,
                  selectedWeek: _weekB,
                  lang: lang,
                  onSaveNote: (imageId, notes) async {
                    final ok = await controller.saveWeeklyImageNotes(
                        imageId: imageId, notes: notes);
                    if (ok)
                      ref.invalidate(weeklyImagesProvider(
                          (uid: uid, pigId: widget.pigId)));
                    return ok;
                  },
                ),
                const SizedBox(height: 16),
                _InformationCard(pig: pig, lang: lang),
                const SizedBox(height: 16),
                _ActionsCard(
                  lang: lang,
                  onRecordWeight: () => _scrollToKey(_recordWeightKey),
                  onAddPhoto: () => _scrollToKey(_weeklyPhotosKey),
                  onEditPig: () => context.push(
                      '${AppRoutes.pigs}/${widget.pigId}/edit',
                      extra: pig),
                  onDeletePig: () =>
                      _confirmDeletePig(context, ref, uid, pig, lang),
                ),
              ]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(tr(lang, 'couldNotLoadThisPig'))),
      ),
      floatingActionButton: pigAsync.valueOrNull == null
          ? null
          : FloatingActionButton(
              backgroundColor: PigGrowthPalette.primaryGreen,
              tooltip: tr(lang, 'addNoteTooltip'),
              onPressed: () => _addNoteForSelectedWeek(context, ref, lang,
                  images: (ref
                          .read(weeklyImagesProvider(
                              (uid: uid, pigId: widget.pigId)))
                          .valueOrNull ??
                      const [])),
              child: const Icon(Icons.note_add_outlined),
            ),
    );
  }

  Future<void> _addNoteForSelectedWeek(
      BuildContext context, WidgetRef ref, AppLanguage lang,
      {required List<WeeklyPigImage> images}) async {
    final week = _weekB ??
        images.map((i) => i.weekNumber).fold<int>(0, (m, w) => w > m ? w : m);
    WeeklyPigImage? target;
    for (final img in images) {
      if (img.weekNumber == week) target = img;
    }
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(lang, 'takePhotoBeforeNoteMessage'))),
      );
      return;
    }
    final ctrl = TextEditingController(text: target.notes);
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${tr(lang, 'noteForWeekPrefix')} ${target!.weekNumber}'),
          content: TextField(
              controller: ctrl,
              maxLines: 4,
              decoration:
                  InputDecoration(hintText: tr(lang, 'addGrowthNoteHint'))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr(lang, 'cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: Text(tr(lang, 'save'))),
          ],
        ),
      );
      if (result == null) return;
      final controller =
          ref.read(pigDetailControllerProvider(widget.pigId).notifier);
      final ok = await controller.saveWeeklyImageNotes(
          imageId: target.id, notes: result);
      final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
      if (ok)
        ref.invalidate(weeklyImagesProvider((uid: uid, pigId: widget.pigId)));
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _captureImage(BuildContext context, WidgetRef ref, int week,
      WeeklyPigImage? existing, AppLanguage lang) async {
    // Fail fast on a still-locked week — no point opening the camera/
    // gallery sheet just to reject the upload afterward. captureWeeklyImage
    // re-checks this server-side too (defense in depth), so this is purely
    // a UX shortcut, not the only guard.
    final uidForLockCheck =
        ref.read(authRepositoryProvider).currentUser?.uid ?? '';
    final currentWeek = ref
        .read(growthControllerProvider(uidForLockCheck))
        .valueOrNull
        ?.currentWeekNumber;
    if (currentWeek != null && week > currentWeek) {
      final unlockDay = ((week - 1) * 7) + 1;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${tr(lang, 'weekPrefix')} $week ${tr(lang, 'weeklyPhotoUnlocksSuffix')} $unlockDay.'),
      ));
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(tr(lang, 'maxSizeNotice'),
                      style: const TextStyle(
                          fontSize: 11.5, color: Colors.black54)),
                ),
              ),
              ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: Text(tr(lang, 'takePhoto')),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera)),
              ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(tr(lang, 'chooseFromGallery')),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final uid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';

    // A weekly photo can take a moment to compress + write — show a
    // non-dismissible progress dialog for that window instead of leaving
    // the sheet looking unresponsive (mirrors the avatar/pig-profile-photo
    // spinner pattern used elsewhere for the same reason).
    if (context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(width: 16),
                  Text(tr(lang, 'uploadingPhotoMessage')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final result = await ref
        .read(pigDetailControllerProvider(widget.pigId).notifier)
        .captureWeeklyImage(
          weekNumber: week,
          source: source,
          replacingId: existing?.id,
        );

    if (context.mounted)
      Navigator.of(context, rootNavigator: true)
          .pop(); // dismiss the progress dialog

    if (result.success) {
      ref.invalidate(weeklyImagesProvider((uid: uid, pigId: widget.pigId)));
    } else if (context.mounted) {
      final message = result.lockedUntilDay != null
          ? '${tr(lang, 'weekPrefix')} $week ${tr(lang, 'weeklyPhotoUnlocksSuffix')} ${result.lockedUntilDay}.'
          : tr(lang, 'imageExceeds3MbMessage');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Actions section's "Delete Pig" — same confirm dialog + delete/log/
  /// invalidate sequence as the list screen's popup-menu delete, just
  /// reachable from the detail screen too, then pops back to the list
  /// since this pig no longer exists to show.
  Future<void> _confirmDeletePig(BuildContext context, WidgetRef ref,
      String uid, Pig pig, AppLanguage lang) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(lang, 'deleteThisPigTitle')),
        content: Text(
            '${tr(lang, 'deletePigBodyPrefix')} ${pig.name} (${pig.id}) ${tr(lang, 'deletePigBodySuffix')}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr(lang, 'cancel'))),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: PigGrowthPalette.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr(lang, 'delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(pigRepositoryProvider).deletePig(uid, pig.id);
    await ref.read(authRepositoryProvider).recordActivityLog(
        uid: uid,
        actionType: 'pig',
        description: 'deleted pig ${pig.name} (${pig.id})');
    ref.invalidate(pigListProvider(uid));
    ref.invalidate(allWeeklyImagesProvider(uid));
    ref.invalidate(dashboardControllerProvider(uid));
    if (context.mounted) context.pop();
  }
}

/// Status chip tiers, mirroring pig_list_screen.dart's private _deriveStatus
/// (kept duplicated rather than shared since Dart can't export a `_`-private
/// member across files — see that file's identical enum for the reasoning).
enum _DetailPigStatus { noPhotos, active, stale, completed }

_DetailPigStatus _deriveDetailStatus(int completed, String? latestUpload) {
  if (completed == 0) return _DetailPigStatus.noPhotos;
  if (completed >= kTotalCycleWeeks) return _DetailPigStatus.completed;
  final last = latestUpload == null ? null : DateTime.tryParse(latestUpload);
  if (last == null) return _DetailPigStatus.stale;
  final daysSince = DateTime.now().difference(last).inDays;
  return daysSince <= 10 ? _DetailPigStatus.active : _DetailPigStatus.stale;
}

class _DetailStatusChip extends StatelessWidget {
  const _DetailStatusChip({required this.status, required this.lang});
  final _DetailPigStatus status;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final (label, dotColor, bg, fg) = switch (status) {
      _DetailPigStatus.active => (
          tr(lang, 'statusActive'),
          const Color(0xFF4CAF50),
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32)
        ),
      _DetailPigStatus.stale => (
          tr(lang, 'statusInProgress'),
          const Color(0xFFFB8C00),
          PigGrowthPalette.lightOrange,
          const Color(0xFFB26A00)
        ),
      _DetailPigStatus.completed => (
          tr(lang, 'statusCompleted'),
          const Color(0xFF1E88E5),
          const Color(0xFFE3F2FD),
          const Color(0xFF1565C0)
        ),
      _DetailPigStatus.noPhotos => (
          tr(lang, 'statusNoPhotosYet'),
          PigGrowthPalette.grayText,
          const Color(0xFFF1F1F1),
          PigGrowthPalette.grayText
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

/// Profile card — real per-pig fields only (photo/name/id/breed/status/age/
/// starting weight/last upload). Batch-shared figures (current weight,
/// ADG, FCR) intentionally live in the separate _HerdGrowthCard below,
/// clearly labeled, rather than being presented here as if unique to this
/// one pig — see this file's header comment / the redesign plan for why.
class _PigIdentityCard extends StatelessWidget {
  const _PigIdentityCard(
      {required this.pig,
      required this.lang,
      required this.completedWeeks,
      required this.latestUpload});
  final Pig pig;
  final AppLanguage lang;
  final int completedWeeks;
  final String? latestUpload;

  @override
  Widget build(BuildContext context) {
    final isMale = pig.gender.toLowerCase() == 'male';
    final ageDays = _detailAgeDays(pig);
    final status = _deriveDetailStatus(completedWeeks, latestUpload);
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isMale
                      ? const Color(0xFFFFE0B2)
                      : const Color(0xFFF8BBD0),
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: pig.photoLocalPath != null
                    ? Image.file(File(pig.photoLocalPath!), fit: BoxFit.cover)
                    : const Center(
                        child: Text('🐷', style: TextStyle(fontSize: 30))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                            child: Text(pig.name.isEmpty ? pig.id : pig.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: PigGrowthPalette.darkText))),
                        const SizedBox(width: 6),
                        Icon(isMale ? Icons.male : Icons.female,
                            size: 18,
                            color: isMale
                                ? const Color(0xFF1E88E5)
                                : const Color(0xFFEC407A)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                        '${pig.id} · ${pig.breed.isEmpty ? tr(lang, 'unknownBreed') : pig.breed}',
                        style: const TextStyle(
                            fontSize: 12.5, color: PigGrowthPalette.grayText)),
                    const SizedBox(height: 8),
                    _DetailStatusChip(status: status, lang: lang),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: PigGrowthPalette.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _ProfileStat(
                      value: '$ageDays',
                      unit: tr(lang, 'daysUnit'),
                      label: tr(lang, 'ageMetricLabel'))),
              Expanded(
                  child: _ProfileStat(
                      value: pig.initialWeight.toStringAsFixed(1),
                      unit: 'kg',
                      label: tr(lang, 'weightMetricLabel'))),
              Expanded(
                  child: _ProfileStat(
                      value: '$completedWeeks/$kTotalCycleWeeks',
                      unit: '',
                      label: tr(lang, 'weeksMetricLabel'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat(
      {required this.value, required this.unit, required this.label});
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: value,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: PigGrowthPalette.darkText)),
              if (unit.isNotEmpty)
                TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PigGrowthPalette.grayText)),
            ],
          ),
        ),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: PigGrowthPalette.grayText,
                letterSpacing: 0.3)),
      ],
    );
  }
}

int _detailAgeDays(Pig pig) {
  final dateStr = pig.arrivalDate.isNotEmpty ? pig.arrivalDate : pig.birthDate;
  final date = DateTime.tryParse(dateStr);
  if (date == null) return 0;
  final start = DateTime(date.year, date.month, date.day);
  final today = DateTime.now();
  return DateTime(today.year, today.month, today.day).difference(start).inDays;
}

/// "Growth Progress" — the same photo-upload completion metric already
/// shown on the list card's progress bar (completedWeeks/kTotalCycleWeeks),
/// just given its own card with the "Week X of Y" / "N weeks remaining"
/// framing from the mockup. Per-pig, real, no new calculation.
class _GrowthProgressCard extends StatelessWidget {
  const _GrowthProgressCard(
      {required this.completedWeeks,
      required this.currentWeekNumber,
      required this.lang});
  final int completedWeeks;
  final int? currentWeekNumber;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final progress = (completedWeeks / kTotalCycleWeeks).clamp(0.0, 1.0);
    final weekShown =
        (currentWeekNumber ?? completedWeeks).clamp(1, kTotalCycleWeeks);
    final remaining = (kTotalCycleWeeks - weekShown).clamp(0, kTotalCycleWeeks);
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr(lang, 'growthProgressLabel'),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: PigGrowthPalette.darkText)),
              Text('${(progress * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: PigGrowthPalette.primaryGreen)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 9,
                backgroundColor: PigGrowthPalette.border,
                valueColor:
                    const AlwaysStoppedAnimation(PigGrowthPalette.primaryGreen),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  '${tr(lang, 'weekPrefix')} $weekShown ${tr(lang, 'ofLabel')} $kTotalCycleWeeks',
                  style: const TextStyle(
                      fontSize: 12, color: PigGrowthPalette.grayText)),
              Text('$remaining ${tr(lang, 'weeksRemainingSuffix')}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PigGrowthPalette.grayText)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Growth Statistics — the batch-level figures (Current Weight, Target
/// Weight, Remaining, ADG, FCR) reused exactly as computed for the Dashboard
/// /Weight & ADG screens (GrowthData.currentWeight/adg/fcr, kMarketWeightKg).
/// These are recorded once per production batch, not per individual pig
/// (see this file's header comment) — the umbrella "Growth & Performance"
/// section this card sits in (see build()) carries that disclaimer once, so
/// this card itself stays a plain stats grid.
class _HerdGrowthCard extends StatelessWidget {
  const _HerdGrowthCard({required this.data, required this.lang});
  final GrowthData data;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final current = data.currentWeight;
    final remaining = (kMarketWeightKg - current).clamp(0, kMarketWeightKg);
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: _ProfileStat(
                      value: current.toStringAsFixed(1),
                      unit: 'kg',
                      label: tr(lang, 'currentWeightLabel'))),
              Expanded(
                  child: _ProfileStat(
                      value: kMarketWeightKg.toStringAsFixed(0),
                      unit: 'kg',
                      label: tr(lang, 'targetWeightLabel'))),
              Expanded(
                  child: _ProfileStat(
                      value: remaining.toStringAsFixed(1),
                      unit: 'kg',
                      label: tr(lang, 'remainingSuffix'))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _ProfileStat(
                      value:
                          data.adg == null ? '—' : data.adg!.toStringAsFixed(0),
                      unit: data.adg == null ? '' : 'g/day',
                      label: tr(lang, 'adgLabel'))),
              Expanded(
                  child: _ProfileStat(
                      value:
                          data.fcr == null ? '—' : data.fcr!.toStringAsFixed(2),
                      unit: '',
                      label: tr(lang, 'fcrLabel'))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Growth Analytics — ADG status, FCR status, and a short FCR trend, reusing
/// the exact adgStatusTier()/fcrStatusTier()/adgTargetMin·Max/kFcrGoodMax
/// classification the old Weight & ADG screen's ADG/FCR/FCR-Trend cards used
/// (see dashboard_calculations.dart) — no new calculation, just restyled
/// into this merged profile screen. Batch-level, covered by this section's
/// shared disclaimer (see build()).
class _GrowthAnalyticsSection extends StatelessWidget {
  const _GrowthAnalyticsSection({required this.data, required this.lang});
  final GrowthData data;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(lang, 'growthAnalyticsSectionTitle'),
            style: pigGrowthSectionTitleStyle),
        const SizedBox(height: 12),
        _AdgAnalyticsCard(adg: data.adg, lang: lang),
        const SizedBox(height: 16),
        _FcrAnalyticsCard(fcr: data.fcr, lang: lang),
        const SizedBox(height: 16),
        _FcrTrendCard(fcrSeries: data.fcrSeries, lang: lang),
      ],
    );
  }
}

/// ADG Card — "This Week's ADG" against the 600–700 g/day Healthy band
/// (adgTargetMin/adgTargetMax), same 4-tier classification adgStatusTier()
/// already provides (Poor/Below Target/Healthy/Excellent).
class _AdgAnalyticsCard extends StatelessWidget {
  const _AdgAnalyticsCard({required this.adg, required this.lang});
  final double? adg;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final tier = adgStatusTier(adg);
    final (label, fg, bg) = switch (tier) {
      AdgStatusTier.poor => (
          tr(lang, 'poorTier'),
          PigGrowthPalette.red,
          PigGrowthPalette.lightOrange
        ),
      AdgStatusTier.below => (
          tr(lang, 'adgBelowTarget'),
          PigGrowthPalette.orange,
          PigGrowthPalette.lightOrange
        ),
      AdgStatusTier.healthy => (
          tr(lang, 'healthyTier'),
          PigGrowthPalette.primaryGreen,
          PigGrowthPalette.lightGreen
        ),
      AdgStatusTier.excellent => (
          tr(lang, 'adgExcellent'),
          PigGrowthPalette.primaryGreen,
          PigGrowthPalette.lightGreen
        ),
      null => (
          tr(lang, 'noDataYet'),
          PigGrowthPalette.grayText,
          PigGrowthPalette.border
        ),
    };
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr(lang, 'thisWeeksAdg'), style: pigGrowthSectionTitleStyle),
              _TierPill(label: label, foreground: fg, background: bg),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: adg == null ? '—' : adg!.toStringAsFixed(0),
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: PigGrowthPalette.darkText)),
              if (adg != null)
                const TextSpan(
                    text: ' g/day',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PigGrowthPalette.grayText)),
            ]),
          ),
          const SizedBox(height: 12),
          _RangeBar(
              min: 400,
              max: 900,
              value: adg,
              goodStart: adgTargetMin.toDouble(),
              goodEnd: adgTargetMax.toDouble()),
          const SizedBox(height: 6),
          Text(
              '${tr(lang, 'targetRangeLabel')} $adgTargetMin–$adgTargetMax g/day',
              style: const TextStyle(
                  fontSize: 11.5, color: PigGrowthPalette.grayText)),
        ],
      ),
    );
  }
}

/// FCR Card — "This Week's FCR" on the same 1.0–4.0 scale the old Weight &
/// ADG screen's FCR card used, Good/Needs Improvement classification from
/// fcrStatusTier()/kFcrGoodMax (≤3.0 = Good).
class _FcrAnalyticsCard extends StatelessWidget {
  const _FcrAnalyticsCard({required this.fcr, required this.lang});
  final double? fcr;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final tier = fcrStatusTier(fcr);
    final (label, fg, bg) = switch (tier) {
      FcrStatusTier.good => (
          tr(lang, 'goodTier'),
          PigGrowthPalette.primaryGreen,
          PigGrowthPalette.lightGreen
        ),
      FcrStatusTier.needsImprovement => (
          tr(lang, 'needsImprovementTier'),
          PigGrowthPalette.orange,
          PigGrowthPalette.lightOrange
        ),
      null => (
          tr(lang, 'noDataYet'),
          PigGrowthPalette.grayText,
          PigGrowthPalette.border
        ),
    };
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr(lang, 'thisWeeksFcr'), style: pigGrowthSectionTitleStyle),
              _TierPill(label: label, foreground: fg, background: bg),
            ],
          ),
          const SizedBox(height: 10),
          Text(fcr == null ? '—' : fcr!.toStringAsFixed(2),
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: PigGrowthPalette.darkText)),
          const SizedBox(height: 12),
          _RangeBar(
              min: 1.0,
              max: 4.0,
              value: fcr,
              goodStart: 1.0,
              goodEnd: kFcrGoodMax),
          const SizedBox(height: 6),
          Text(tr(lang, 'lowerFcrBetterNotice'),
              style: const TextStyle(
                  fontSize: 11.5,
                  color: PigGrowthPalette.grayText,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

/// Horizontal target-range indicator shared by the ADG and FCR analytics
/// cards — a plain bar spanning [min]..[max] with a shaded "good" band from
/// [goodStart] to [goodEnd] and a marker dot at [value] (clamped into
/// range), so both cards read at a glance without duplicating layout code.
class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.min,
    required this.max,
    required this.value,
    required this.goodStart,
    required this.goodEnd,
  });
  final double min;
  final double max;
  final double? value;
  final double goodStart;
  final double goodEnd;

  @override
  Widget build(BuildContext context) {
    final span = (max - min).abs();
    double fractionFor(double v) =>
        span <= 0 ? 0 : ((v - min) / span).clamp(0.0, 1.0);
    final goodLeft = fractionFor(goodStart);
    final goodRight = fractionFor(goodEnd);
    final markerFraction = value == null ? null : fractionFor(value!);

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return SizedBox(
        height: 22,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 8,
              width: width,
              decoration: BoxDecoration(
                color: PigGrowthPalette.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Positioned(
              left: width * goodLeft,
              child: Container(
                height: 8,
                width: (width * (goodRight - goodLeft)).clamp(0.0, width),
                decoration: BoxDecoration(
                  color: PigGrowthPalette.lightGreen,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (markerFraction != null)
              Positioned(
                left: (width * markerFraction - 7).clamp(0.0, width - 14),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: PigGrowthPalette.primaryGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 3,
                          offset: const Offset(0, 1)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// Small rounded status pill shared by the ADG and FCR analytics cards.
class _TierPill extends StatelessWidget {
  const _TierPill(
      {required this.label,
      required this.foreground,
      required this.background});
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: foreground)),
    );
  }
}

/// FCR Trend — the most recent up-to-3 points from the same fcrSeries the
/// FCR History card already lists, plotted as a small trend line, plus a
/// week-over-week delta caption. Lower FCR is better, so a negative delta
/// (this week's FCR below last week's) reads as "Improving".
class _FcrTrendCard extends StatelessWidget {
  const _FcrTrendCard({required this.fcrSeries, required this.lang});
  final List<ChartPoint> fcrSeries;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final sorted = [...fcrSeries]..sort((a, b) => a.week.compareTo(b.week));
    final recent =
        sorted.length > 3 ? sorted.sublist(sorted.length - 3) : sorted;

    Widget trendCaption = Text(tr(lang, 'noDataYet'),
        style: const TextStyle(fontSize: 12, color: PigGrowthPalette.grayText));
    if (recent.length >= 2) {
      final delta = recent.last.value - recent[recent.length - 2].value;
      final improving = delta < 0;
      final stable = delta == 0;
      final trendLabel = stable
          ? tr(lang, 'trendStableLabel')
          : (improving
              ? tr(lang, 'trendImprovingLabel')
              : tr(lang, 'trendDecliningLabel'));
      final color = stable
          ? PigGrowthPalette.grayText
          : (improving ? PigGrowthPalette.primaryGreen : PigGrowthPalette.red);
      final arrow = stable ? '→' : (improving ? '↓' : '↑');
      trendCaption = Text(
          '$arrow ${delta.abs().toStringAsFixed(2)} $trendLabel ${tr(lang, 'fromLastWeekSuffix')}',
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: color));
    }

    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'thisWeeksFcrTrend'),
              style: pigGrowthSectionTitleStyle),
          const SizedBox(height: 12),
          if (recent.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: Text(tr(lang, 'noDataYet'),
                      style: const TextStyle(
                          color: PigGrowthPalette.grayText, fontSize: 12.5))),
            )
          else
            SizedBox(height: 120, child: _FcrMiniChart(points: recent)),
          const SizedBox(height: 8),
          trendCaption,
        ],
      ),
    );
  }
}

class _FcrMiniChart extends StatelessWidget {
  const _FcrMiniChart({required this.points});
  final List<ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final spots =
        points.map((p) => FlSpot(p.week.toDouble(), p.value)).toList();
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final pad =
        ((maxY - minY).abs() * 0.3).clamp(0.3, double.infinity).toDouble();
    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: PigGrowthPalette.border, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text('W${value.toInt()}',
                  style: const TextStyle(
                      fontSize: 10, color: PigGrowthPalette.grayText)),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 10, color: PigGrowthPalette.grayText)),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched
                .map((t) => LineTooltipItem(t.y.toStringAsFixed(2),
                    const TextStyle(color: Colors.white)))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: PigGrowthPalette.orange,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: PigGrowthPalette.orange,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData:
                BarAreaData(show: true, color: PigGrowthPalette.lightOrange),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }
}

/// Production Stage — the existing ATI-manual feed-allowance band
/// (stageForWeight()/nextStage()) and the batch's real ADG projected via
/// daysUntilWeight(), same formulas the old Growth tab used. Batch-level,
/// covered by this section's shared disclaimer (see build()).
class _ProductionStageCard extends StatelessWidget {
  const _ProductionStageCard({required this.data, required this.lang});
  final GrowthData data;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final stage = stageForWeight(data.currentWeight);
    final next = nextStage(stage);
    final nextTargetKg =
        next != null ? stageUpperBoundKg(stage) : kMarketWeightKg;
    final daysToNext = daysUntilWeight(
        currentWeight: data.currentWeight,
        targetWeightKg: nextTargetKg,
        adg: data.adg);
    final estimatedTransitionDay = daysToNext == null
        ? null
        : (data.currentDay + daysToNext).clamp(1, kMaxProductionDay);
    final nextLabel = next?.name ?? tr(lang, 'marketReadyLabel');
    final dayProgress = (data.currentDay / kMaxProductionDay).clamp(0.0, 1.0);

    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'productionStageTitle'),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PigGrowthPalette.darkText)),
          const SizedBox(height: 10),
          Text(stage.name,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: PigGrowthPalette.darkText)),
          const SizedBox(height: 2),
          Text(
              '${tr(lang, 'dayLabel')} ${data.currentDay} / $kMaxProductionDay',
              style: const TextStyle(
                  fontSize: 12, color: PigGrowthPalette.grayText)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: dayProgress),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 9,
                backgroundColor: PigGrowthPalette.border,
                valueColor:
                    const AlwaysStoppedAnimation(PigGrowthPalette.primaryGreen),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(lang, 'nextStagePrefix').replaceAll(':', ''),
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: PigGrowthPalette.grayText)),
                      const SizedBox(height: 2),
                      Text(nextLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: PigGrowthPalette.darkText)),
                    ]),
              ),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(tr(lang, 'estimatedTransitionLabel'),
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: PigGrowthPalette.grayText)),
                      const SizedBox(height: 2),
                      Text(
                          estimatedTransitionDay == null
                              ? '—'
                              : '${tr(lang, 'dayLabel')} $estimatedTransitionDay',
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: PigGrowthPalette.darkText)),
                    ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Growth Milestones — a vertical timeline built from the existing
/// kPigStages list plus the Day-1 baseline and the Market Ready endpoint.
/// Done/current/upcoming state is derived purely from stageForWeight()'s
/// classification of the real current weight, nothing new persisted.
/// Batch-level, covered by this section's shared disclaimer (see build()).
class _GrowthMilestonesCard extends StatelessWidget {
  const _GrowthMilestonesCard({required this.data, required this.lang});
  final GrowthData data;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final stage = stageForWeight(data.currentWeight);
    final currentIdx = kPigStages.indexWhere((s) => s.key == stage.key);
    final cycleComplete = data.currentDay >= kMaxProductionDay;
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'growthMilestonesTitle'),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PigGrowthPalette.darkText)),
          const SizedBox(height: 12),
          _MilestoneRow(
            state: _MilestoneState.done,
            title: tr(lang, 'startingWeightMilestoneLabel'),
            subtitle: '${tr(lang, 'dayLabel')} 1',
            isLast: false,
          ),
          for (var i = 0; i < kPigStages.length; i++)
            _MilestoneRow(
              state: i <= currentIdx
                  ? _MilestoneState.done
                  : (i == currentIdx + 1
                      ? _MilestoneState.current
                      : _MilestoneState.upcoming),
              title: kPigStages[i].name,
              subtitle: i == currentIdx
                  ? tr(lang, 'currentStageMilestoneLabel')
                  : (i < currentIdx
                      ? tr(lang, 'completedLabel')
                      : tr(lang, 'upcomingLabel')),
              isLast: false,
            ),
          _MilestoneRow(
            state:
                cycleComplete ? _MilestoneState.done : _MilestoneState.upcoming,
            title: tr(lang, 'marketReadyLabel'),
            subtitle: '${tr(lang, 'dayLabel')} $kMaxProductionDay',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

enum _MilestoneState { done, current, upcoming }

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.state,
    required this.title,
    required this.subtitle,
    required this.isLast,
  });
  final _MilestoneState state;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    final Widget icon;
    switch (state) {
      case _MilestoneState.done:
        dotColor = PigGrowthPalette.primaryGreen;
        icon = const Icon(Icons.check_rounded, size: 13, color: Colors.white);
        break;
      case _MilestoneState.current:
        dotColor = PigGrowthPalette.orange;
        icon = Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle));
        break;
      case _MilestoneState.upcoming:
        dotColor = PigGrowthPalette.border;
        icon = const SizedBox.shrink();
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle),
              child: icon,
            ),
            if (!isLast)
              Expanded(
                  child: Container(
                width: 2,
                color: state == _MilestoneState.upcoming
                    ? PigGrowthPalette.border
                    : PigGrowthPalette.primaryGreen.withValues(alpha: 0.4),
              )),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: state == _MilestoneState.upcoming
                                ? PigGrowthPalette.grayText
                                : PigGrowthPalette.darkText)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11.5, color: PigGrowthPalette.grayText)),
                  ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Weigh-In History — every recorded weigh-in (chronological, newest first)
/// with an edit action, same GrowthController.editWeighIn() CRUD the old
/// Weight & ADG tab used. Deletion is intentionally not offered here either
/// — weekly weigh-ins have always been editable-only in this app (see
/// GrowthController.deleteWeighIn's doc and growth_screen.dart's prior
/// design note), so this merge preserves that behavior rather than
/// introducing a new delete affordance.
class _WeighInHistoryCard extends StatelessWidget {
  const _WeighInHistoryCard({
    required this.uid,
    required this.weightLogs,
    required this.adgSeries,
    required this.lang,
  });
  final String uid;
  final List<WeightLogEntry> weightLogs;
  final List<ChartPoint> adgSeries;
  final AppLanguage lang;

  double? _adgForWeek(int week) {
    for (final p in adgSeries) {
      if (p.week == week) return p.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...weightLogs]..sort((a, b) => b.day.compareTo(a.day));
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'weighInHistoryTitle'),
              style: pigGrowthSectionTitleStyle),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(tr(lang, 'noWeightRecordsYet'),
                  style: const TextStyle(
                      color: PigGrowthPalette.grayText, fontSize: 12.5)),
            )
          else
            Column(
              children: sorted.map((e) {
                final isBaseline = !e.isOfficial;
                final adg = isBaseline ? null : _adgForWeek(e.weekNumber);
                return _PigHistoryRow(
                  dayLabel: '${tr(lang, 'dayLabel')} ${e.day}',
                  primaryValue: '${e.weight.toStringAsFixed(1)} kg',
                  secondaryLine:
                      isBaseline ? tr(lang, 'baselineLabel') : e.date,
                  badgeText: isBaseline
                      ? '—'
                      : (adg == null
                          ? '—'
                          : '${adg >= 0 ? '+' : ''}${adg.round()} g/d'),
                  badgeColor: isBaseline
                      ? PigGrowthPalette.grayText
                      : (adg != null && adg < 0
                          ? PigGrowthPalette.red
                          : PigGrowthPalette.primaryGreen),
                  badgeBackground: isBaseline
                      ? PigGrowthPalette.border.withValues(alpha: 0.6)
                      : PigGrowthPalette.lightGreen,
                  onEdit: isBaseline
                      ? null
                      : () => showDialog<void>(
                            context: context,
                            builder: (_) =>
                                _EditWeighInDialog(uid: uid, existing: e),
                          ),
                  lang: lang,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

/// FCR History — same real weightLogs/fcrSeries/feedConsumedSeries the old
/// Weight & ADG tab used; consistently orange-badged since these are
/// historical values, not a live judgment call.
class _FcrHistoryCard extends StatelessWidget {
  const _FcrHistoryCard({
    required this.weightLogs,
    required this.fcrSeries,
    required this.feedConsumedSeries,
    required this.lang,
  });
  final List<WeightLogEntry> weightLogs;
  final List<ChartPoint> fcrSeries;
  final List<ChartPoint> feedConsumedSeries;
  final AppLanguage lang;

  double? _valueForWeek(List<ChartPoint> series, int week) {
    for (final p in series) {
      if (p.week == week) return p.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...weightLogs]..sort((a, b) => b.day.compareTo(a.day));
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'fcrHistoryTitle'), style: pigGrowthSectionTitleStyle),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(tr(lang, 'noWeightRecordsYet'),
                  style: const TextStyle(
                      color: PigGrowthPalette.grayText, fontSize: 12.5)),
            )
          else
            Column(
              children: sorted.map((e) {
                final isBaseline = !e.isOfficial;
                final fcr =
                    isBaseline ? null : _valueForWeek(fcrSeries, e.weekNumber);
                final feedConsumed = isBaseline
                    ? null
                    : _valueForWeek(feedConsumedSeries, e.weekNumber);
                return _PigHistoryRow(
                  dayLabel: '${tr(lang, 'dayLabel')} ${e.day}',
                  primaryValue: '${e.weight.toStringAsFixed(1)} kg',
                  secondaryLine: isBaseline
                      ? tr(lang, 'baselineLabel')
                      : (feedConsumed == null
                          ? ''
                          : '${tr(lang, 'feedConsumedPrefix')} ${feedConsumed.toStringAsFixed(1)} kg'),
                  badgeText: (isBaseline || fcr == null)
                      ? '—'
                      : fcr.toStringAsFixed(2),
                  badgeColor: (isBaseline || fcr == null)
                      ? PigGrowthPalette.grayText
                      : PigGrowthPalette.orange,
                  badgeBackground: (isBaseline || fcr == null)
                      ? PigGrowthPalette.border.withValues(alpha: 0.6)
                      : PigGrowthPalette.lightOrange,
                  lang: lang,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

/// Shared row layout for both history lists above — Day / value / secondary
/// line on the left, a colored value badge, and an optional Edit action for
/// entries that support it.
class _PigHistoryRow extends StatelessWidget {
  const _PigHistoryRow({
    required this.dayLabel,
    required this.primaryValue,
    required this.secondaryLine,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeBackground,
    required this.lang,
    this.onEdit,
  });

  final String dayLabel;
  final String primaryValue;
  final String secondaryLine;
  final String badgeText;
  final Color badgeColor;
  final Color badgeBackground;
  final AppLanguage lang;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PigGrowthPalette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PigGrowthPalette.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(dayLabel,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: PigGrowthPalette.grayText)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(primaryValue,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: PigGrowthPalette.darkText)),
                if (secondaryLine.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(secondaryLine,
                        style: const TextStyle(
                            fontSize: 11.5, color: PigGrowthPalette.grayText)),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: badgeBackground,
                borderRadius: BorderRadius.circular(20)),
            child: Text(badgeText,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: badgeColor)),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: PigGrowthPalette.grayText),
              tooltip: tr(lang, 'edit'),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }
}

/// Edit-only dialog for an existing weigh-in, reached via a Weigh-In History
/// row's Edit button. Same GrowthController.editWeighIn() call the old
/// Weight & ADG tab's edit dialog used — no new save path.
class _EditWeighInDialog extends ConsumerStatefulWidget {
  const _EditWeighInDialog({required this.uid, required this.existing});
  final String uid;
  final WeightLogEntry existing;

  @override
  ConsumerState<_EditWeighInDialog> createState() => _EditWeighInDialogState();
}

class _EditWeighInDialogState extends ConsumerState<_EditWeighInDialog> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl =
        TextEditingController(text: widget.existing.weight.toString());
    _notesCtrl = TextEditingController(text: widget.existing.notes);
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(growthControllerProvider(widget.uid));
    final data = state.valueOrNull;
    final lang = ref.watch(appLanguageProvider);

    ref.listen(growthControllerProvider(widget.uid), (previous, next) {
      final wasSaving = previous?.valueOrNull?.isSaving ?? false;
      final nowSaving = next.valueOrNull?.isSaving ?? false;
      if (wasSaving && !nowSaving && next.valueOrNull?.errorMessage == null) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    });

    return AlertDialog(
      title: Text(tr(lang, 'editWeighInTitle')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: tr(lang, 'weightKgLabel')),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(labelText: tr(lang, 'notesOptional')),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(lang, 'cancel'))),
        FilledButton(
          onPressed: (data?.isSaving ?? false)
              ? null
              : () {
                  final weight = double.tryParse(_weightCtrl.text);
                  if (weight == null || weight <= 0) return;
                  ref
                      .read(growthControllerProvider(widget.uid).notifier)
                      .editWeighIn(
                        day: widget.existing.day,
                        weight: weight,
                        notes: _notesCtrl.text.trim(),
                      );
                },
          child: Text(tr(lang, 'save')),
        ),
      ],
    );
  }
}

/// "Weekly Progress" — a compact horizontal milestone row (check/lock icons
/// + capture date) over this pig's own real weekly-image records, distinct
/// from the fuller capture strip further down (_WeeklyPhotosCard) which
/// still owns the actual take/replace-photo interaction.
class _WeeklyMilestoneRow extends StatelessWidget {
  const _WeeklyMilestoneRow(
      {required this.images,
      required this.currentWeekNumber,
      required this.lang,
      required this.onViewAll});
  final List<WeeklyPigImage> images;
  final int? currentWeekNumber;
  final AppLanguage lang;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final byWeek = <int, WeeklyPigImage>{};
    for (final img in images) {
      byWeek[img.weekNumber] = img;
    }
    final current = currentWeekNumber ?? 1;
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr(lang, 'weeklyProgressSectionTitle'),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: PigGrowthPalette.darkText)),
              InkWell(
                onTap: onViewAll,
                child: Text(tr(lang, 'viewAllLabel'),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PigGrowthPalette.primaryGreen)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kTotalCycleWeeks,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final week = i + 1;
                final img = byWeek[week];
                final done = img != null;
                final locked = week > current;
                final (bg, fg, icon) = done
                    ? (
                        const Color(0xFFE8F5E9),
                        PigGrowthPalette.primaryGreen,
                        Icons.check_circle
                      )
                    : locked
                        ? (
                            const Color(0xFFF1F1F1),
                            PigGrowthPalette.grayText,
                            Icons.lock_outline
                          )
                        : (
                            PigGrowthPalette.lightOrange,
                            PigGrowthPalette.orange,
                            Icons.radio_button_unchecked
                          );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration:
                          BoxDecoration(color: bg, shape: BoxShape.circle),
                      child: Icon(icon, size: 18, color: fg),
                    ),
                    const SizedBox(height: 4),
                    Text('W$week',
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: PigGrowthPalette.darkText)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// "Latest Photo" — the single most-recently-captured real photo for this
/// pig (falls back to an empty state when none exist yet), with a View All
/// link into the existing Calendar View screen (the app's real photo
/// gallery for this pig) rather than a new, duplicate photo-browsing UI.
class _LatestPhotoCard extends StatelessWidget {
  const _LatestPhotoCard(
      {required this.images,
      required this.lang,
      required this.onViewAll,
      required this.onAddPhoto});
  final List<WeeklyPigImage> images;
  final AppLanguage lang;
  final VoidCallback onViewAll;
  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final sorted = [...images]
      ..sort((a, b) => b.captureDate.compareTo(a.captureDate));
    final latest = sorted.isEmpty ? null : sorted.first;

    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr(lang, 'latestPhotoSectionTitle'),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: PigGrowthPalette.darkText)),
              if (latest != null)
                InkWell(
                  onTap: onViewAll,
                  child: Text(tr(lang, 'viewAllLabel'),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PigGrowthPalette.primaryGreen)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (latest == null)
            _InlineEmptyState(
                icon: Icons.photo_camera_back_outlined,
                title: tr(lang, 'noPhotosUploadedYetTitle'),
                body: tr(lang, 'noPhotosUploadedYetBody'),
                onAction: onAddPhoto,
                actionLabel: tr(lang, 'uploadPhotoButton'))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: _detailImageFor(latest.displayPath),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDetailDate(latest.captureDate, lang),
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: PigGrowthPalette.darkText)),
                      const SizedBox(height: 4),
                      Text('${tr(lang, 'weekPrefix')} ${latest.weekNumber}',
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: PigGrowthPalette.grayText)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String _formatDetailDate(String isoDate, AppLanguage lang) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  final months = monthAbbrev(lang);
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Same local-file-vs-remote-URL resolution already used by the Growth
/// Comparison slider's `_imageFor` (see below) — duplicated here rather
/// than shared since it's a tiny private helper local to each widget.
Widget _detailImageFor(String? path) {
  if (path == null) {
    return Container(
        color: PigGrowthPalette.background,
        child:
            const Icon(Icons.image_outlined, color: PigGrowthPalette.grayText));
  }
  if (path.startsWith('http')) {
    return Image.network(path, fit: BoxFit.cover);
  }
  return Image.file(File(path), fit: BoxFit.cover);
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState(
      {required this.icon,
      required this.title,
      required this.body,
      this.onAction,
      this.actionLabel});
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(icon, size: 36, color: PigGrowthPalette.grayText),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: PigGrowthPalette.darkText)),
          const SizedBox(height: 4),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: PigGrowthPalette.grayText)),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 10),
            TextButton(
                onPressed: onAction,
                child: Text(actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ],
      ),
    );
  }
}

/// "Information" — real per-pig fields only (breed/gender/DOB/pen/notes),
/// plus the shared production batch's name (real, from PigBatchProfile —
/// this app currently supports one batch per account, so every pig belongs
/// to it; there is no per-pig "batch" field to read instead).
class _InformationCard extends ConsumerWidget {
  const _InformationCard({required this.pig, required this.lang});
  final Pig pig;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final batchName = ref
        .watch(growthControllerProvider(uid))
        .valueOrNull
        ?.batchProfile
        ?.batchName;
    final dob =
        pig.birthDate.isEmpty ? '—' : _formatDetailDate(pig.birthDate, lang);
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'informationSectionTitle'),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PigGrowthPalette.darkText)),
          const SizedBox(height: 10),
          _InfoRow(
              label: tr(lang, 'breedLabel'),
              value: pig.breed.isEmpty ? tr(lang, 'unknownBreed') : pig.breed),
          _InfoRow(
              label: tr(lang, 'genderLabel'),
              value: pig.gender.isEmpty ? '—' : pig.gender),
          _InfoRow(label: tr(lang, 'dateOfBirthLabel'), value: dob),
          if (batchName != null && batchName.isNotEmpty)
            _InfoRow(label: tr(lang, 'batchLabel'), value: batchName),
          _InfoRow(
              label: tr(lang, 'penAreaLabel'),
              value: pig.penNumber.isEmpty ? '—' : pig.penNumber),
          _InfoRow(
              label: tr(lang, 'notesFieldLabel'),
              value:
                  pig.notes.isEmpty ? tr(lang, 'noNotesRecorded') : pig.notes,
              isLast: true),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.label, required this.value, this.isLast = false});
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5, color: PigGrowthPalette.grayText)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: PigGrowthPalette.darkText)),
          ),
        ],
      ),
    );
  }
}

/// "Actions" — Record Weight/Add Photo scroll to the existing inline
/// widgets that already own that functionality (rather than duplicating
/// the weigh-in form or photo picker here); Edit/Delete reuse the exact
/// same navigation/confirm-dialog/repository calls as elsewhere in this
/// module.
class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.lang,
    required this.onRecordWeight,
    required this.onAddPhoto,
    required this.onEditPig,
    required this.onDeletePig,
  });
  final AppLanguage lang;
  final VoidCallback onRecordWeight;
  final VoidCallback onAddPhoto;
  final VoidCallback onEditPig;
  final VoidCallback onDeletePig;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'actionsSectionTitle'),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PigGrowthPalette.darkText)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [
              _ActionButton(
                  icon: Icons.monitor_weight_outlined,
                  label: tr(lang, 'recordWeightActionTitle'),
                  color: PigGrowthPalette.primaryGreen,
                  onTap: onRecordWeight),
              _ActionButton(
                  icon: Icons.add_a_photo_outlined,
                  label: tr(lang, 'addPhotoActionLabel'),
                  color: PigGrowthPalette.primaryGreen,
                  onTap: onAddPhoto),
              _ActionButton(
                  icon: Icons.edit_outlined,
                  label: tr(lang, 'editPigActionLabel'),
                  color: PigGrowthPalette.primaryGreen,
                  onTap: onEditPig),
              _ActionButton(
                  icon: Icons.delete_outline,
                  label: tr(lang, 'deletePigActionLabel'),
                  color: PigGrowthPalette.red,
                  onTap: onDeletePig),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrowthChartCard extends StatelessWidget {
  const _GrowthChartCard({required this.points, required this.lang});
  final List<ChartPoint> points;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'growthChartSection'),
              style: pigGrowthSectionTitleStyle),
          const SizedBox(height: 14),
          if (points.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Text(tr(lang, 'recordTwoWeightsNotice'),
                      style: const TextStyle(
                          color: PigGrowthPalette.grayText, fontSize: 12.5))),
            )
          else
            SizedBox(
                height: 210,
                child: _WeightLineChart(points: points, lang: lang)),
        ],
      ),
    );
  }
}

class _WeightLineChart extends StatelessWidget {
  const _WeightLineChart({required this.points, required this.lang});
  final List<ChartPoint> points;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final spots =
        points.map((p) => FlSpot(p.week.toDouble(), p.value)).toList();
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final pad =
        ((maxY - minY).abs() * 0.2).clamp(1.0, double.infinity).toDouble();

    final lastIndex = spots.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: minY - pad,
              maxY: maxY + pad,
              gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                      color: PigGrowthPalette.border, strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Text(
                        '${tr(lang, 'weekPrefix')} ${value.toInt()}',
                        style: const TextStyle(
                            fontSize: 10, color: PigGrowthPalette.grayText)),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) => Text(
                        '${value.toStringAsFixed(0)}kg',
                        style: const TextStyle(
                            fontSize: 10, color: PigGrowthPalette.grayText)),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touched) => touched
                      .map((t) => LineTooltipItem(
                          '${t.y.toStringAsFixed(1)} kg',
                          const TextStyle(color: Colors.white)))
                      .toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: PigGrowthPalette.primaryGreen,
                  barWidth: 3,
                  // First and latest points get a bigger, outlined dot so
                  // they read as the "start" and "current" markers at a
                  // glance; every point in between keeps the plain small
                  // dot. Purely a rendering choice — same spots/values.
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) {
                      final isEndpoint = index == 0 || index == lastIndex;
                      return FlDotCirclePainter(
                        radius: isEndpoint ? 6 : 3,
                        color: index == lastIndex
                            ? PigGrowthPalette.primaryGreen
                            : Colors.white,
                        strokeWidth: isEndpoint ? 2.5 : 2,
                        strokeColor: PigGrowthPalette.primaryGreen,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                      show: true, color: PigGrowthPalette.lightGreen),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutCubic,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _ChartLegendDot(
                color: Colors.white,
                label: tr(lang, 'firstWeightLegend'),
                outlined: true),
            const SizedBox(width: 16),
            _ChartLegendDot(
                color: PigGrowthPalette.primaryGreen,
                label: tr(lang, 'latestWeightLegend')),
          ],
        ),
      ],
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  const _ChartLegendDot(
      {required this.color, required this.label, this.outlined = false});
  final Color color;
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
                color: PigGrowthPalette.primaryGreen, width: outlined ? 2 : 0),
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 10.5, color: PigGrowthPalette.grayText)),
      ],
    );
  }
}

class _WeightTimelineCard extends StatelessWidget {
  const _WeightTimelineCard({required this.weightLogs, required this.lang});
  final List<WeightLogEntry> weightLogs;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    // Compute each entry's delta against the previous (chronologically
    // earlier) weigh-in first, ascending by day, then reverse for display
    // (newest first) — the delta itself is just a subtraction over already-
    // loaded weightLogs, no new calculation or repository field.
    final ascending = [...weightLogs]..sort((a, b) => a.day.compareTo(b.day));
    final deltas = <int, double?>{};
    for (var i = 0; i < ascending.length; i++) {
      deltas[ascending[i].day] =
          i == 0 ? null : ascending[i].weight - ascending[i - 1].weight;
    }
    final sorted = ascending.reversed.toList();

    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'weightTimelineSection'),
              style: pigGrowthSectionTitleStyle),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(tr(lang, 'noWeightRecordsYet'),
                    style: const TextStyle(
                        color: PigGrowthPalette.grayText, fontSize: 12.5)))
          else
            ...sorted.map((e) {
              final delta = deltas[e.day];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: PigGrowthPalette.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PigGrowthPalette.border)),
                child: Row(
                  children: [
                    SizedBox(
                        width: 56,
                        child: Text('${tr(lang, 'weekPrefix')} ${e.weekNumber}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: PigGrowthPalette.grayText))),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.weight.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: PigGrowthPalette.darkText)),
                          Text(e.date,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: PigGrowthPalette.grayText)),
                        ],
                      ),
                    ),
                    if (delta == null)
                      Text(tr(lang, 'baselineLabel'),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: PigGrowthPalette.grayText))
                    else
                      Text(
                        '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg\n${tr(lang, 'sinceLastWeighInSuffix')}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: delta >= 0
                                ? const Color(0xFF2E7D32)
                                : PigGrowthPalette.red,
                            height: 1.3),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Inline weight-entry card — same addWeighIn()/confirmOverwriteDuplicate()
/// controller methods and duplicate-week guard as the Weight & ADG screen's
/// own record-weight card; kept as a small local copy (rather than a shared
/// import) since each screen uses its own palette per its own design spec.
class _RecordWeightCard extends ConsumerStatefulWidget {
  const _RecordWeightCard({required this.uid, required this.lang});
  final String uid;
  final AppLanguage lang;

  @override
  ConsumerState<_RecordWeightCard> createState() => _RecordWeightCardState();
}

class _RecordWeightCardState extends ConsumerState<_RecordWeightCard> {
  final _weightCtrl = TextEditingController();

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(growthControllerProvider(widget.uid)).valueOrNull;
    final isSaving = state?.isSaving ?? false;

    ref.listen(growthControllerProvider(widget.uid), (previous, next) {
      final dup = next.valueOrNull?.pendingDuplicateWeek;
      final prevDup = previous?.valueOrNull?.pendingDuplicateWeek;
      if (dup != null && dup != prevDup) _confirmReplaceDuplicate(dup);
      final wasSaving = previous?.valueOrNull?.isSaving ?? false;
      final nowSaving = next.valueOrNull?.isSaving ?? false;
      final err = next.valueOrNull?.errorMessage;
      if (wasSaving && !nowSaving && dup == null && err == null)
        _weightCtrl.clear();
    });

    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(widget.lang, 'recordNewWeightTitle'),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PigGrowthPalette.darkText)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: PigGrowthPalette.primaryGreen
                              .withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _weightCtrl,
                    enabled: !isSaving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                        hintText: 'kg',
                        suffixText: 'kg',
                        border: InputBorder.none,
                        isDense: true),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: PigGrowthPalette.primaryGreen,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isSaving ? null : _save,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(tr(widget.lang, 'save'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final weight = double.tryParse(_weightCtrl.text.trim());
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(widget.lang, 'enterValidWeightKg'))));
      return;
    }
    ref
        .read(growthControllerProvider(widget.uid).notifier)
        .addWeighIn(weight: weight);
  }

  Future<void> _confirmReplaceDuplicate(int week) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(widget.lang, 'replaceThisWeeksWeighInTitle')),
        content: Text(
            '${tr(widget.lang, 'weighInExistsPrefix')} $week. ${tr(widget.lang, 'replaceWithSuffix')} ${_weightCtrl.text} kg?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr(widget.lang, 'cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr(widget.lang, 'replaceButton'))),
        ],
      ),
    );
    if (!mounted) return;
    final notifier = ref.read(growthControllerProvider(widget.uid).notifier);
    if (confirmed == true) {
      final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0;
      notifier.confirmOverwriteDuplicate(weight: weight);
    } else {
      notifier.cancelDuplicate();
    }
  }
}

/// Weekly Progress Photos — the existing capture/replace flow (camera or
/// gallery, per-week slot), restyled as a horizontal strip of rounded
/// thumbnails instead of a full-height ListTile timeline. Tapping any slot
/// (photographed or not) opens the same Take Photo/Choose Gallery sheet as
/// before.
class _WeeklyPhotosCard extends StatelessWidget {
  const _WeeklyPhotosCard(
      {required this.images,
      required this.onCapture,
      required this.lang,
      this.currentWeekNumber});
  final List<WeeklyPigImage> images;
  final void Function(int week, WeeklyPigImage? existing) onCapture;
  final AppLanguage lang;

  /// The furthest week currently unlocked (from GrowthData.currentWeekNumber
  /// — the same manual production-day counter every other week calculation
  /// in the app reads from). Null only while that data is still loading, in
  /// which case slots are shown unlocked rather than guessing wrong.
  final int? currentWeekNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'weeklyProgressPhotosSection'),
              style: pigGrowthSectionTitleStyle),
          const SizedBox(height: 12),
          if (images.isEmpty) ...[
            _NoPhotosEmptyState(onUpload: () => onCapture(1, null), lang: lang),
            const SizedBox(height: 14),
          ],
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kTotalCycleWeeks,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final week = i + 1;
                final locked =
                    currentWeekNumber != null && week > currentWeekNumber!;
                WeeklyPigImage? existing;
                for (final img in images) {
                  if (img.weekNumber == week) existing = img;
                }
                final path = existing?.displayPath;
                return GestureDetector(
                  onTap: () => onCapture(week, existing),
                  child: Opacity(
                    opacity: locked ? 0.45 : 1,
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: PigGrowthPalette.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: existing != null
                                    ? PigGrowthPalette.primaryGreen
                                    : PigGrowthPalette.border,
                                width: existing != null ? 2 : 1),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: locked
                              ? const Icon(Icons.lock_outline,
                                  color: PigGrowthPalette.grayText)
                              : (path == null
                                  ? const Icon(Icons.camera_alt_outlined,
                                      color: PigGrowthPalette.grayText)
                                  : (path.startsWith('http')
                                      ? Image.network(path, fit: BoxFit.cover)
                                      : Image.file(File(path),
                                          fit: BoxFit.cover))),
                        ),
                        const SizedBox(height: 4),
                        Text('W$week',
                            style: const TextStyle(
                                fontSize: 10,
                                color: PigGrowthPalette.grayText)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly empty state shown above the weekly-photo strip when this pig
/// has zero recorded photos yet, instead of just 18 empty camera-icon
/// slots with no guidance. Tapping Upload starts the same capture flow as
/// tapping any individual week slot, targeted at Week 1.
class _NoPhotosEmptyState extends StatelessWidget {
  const _NoPhotosEmptyState({required this.onUpload, required this.lang});
  final VoidCallback onUpload;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
          color: PigGrowthPalette.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PigGrowthPalette.border)),
      child: Column(
        children: [
          const Icon(Icons.photo_camera_outlined,
              size: 32, color: PigGrowthPalette.grayText),
          const SizedBox(height: 8),
          Text(tr(lang, 'noGrowthPhotosYet'),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PigGrowthPalette.darkText)),
          const SizedBox(height: 4),
          Text(
            tr(lang, 'startTrackingPigNotice'),
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 12, color: PigGrowthPalette.grayText),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.add_a_photo_outlined, size: 16),
            label: Text(tr(lang, 'uploadPhotoButton')),
            style: OutlinedButton.styleFrom(
              foregroundColor: PigGrowthPalette.primaryGreen,
              side: const BorderSide(color: PigGrowthPalette.primaryGreen),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Growth Comparison — a draggable before/after slider between any two
/// captured weeks of THIS pig's real photos.
class _GrowthComparisonCard extends StatelessWidget {
  const _GrowthComparisonCard({
    required this.images,
    required this.weekA,
    required this.weekB,
    required this.onWeekAChanged,
    required this.onWeekBChanged,
    required this.lang,
  });
  final List<WeeklyPigImage> images;
  final int? weekA;
  final int? weekB;
  final ValueChanged<int?> onWeekAChanged;
  final ValueChanged<int?> onWeekBChanged;
  final AppLanguage lang;

  WeeklyPigImage? _imageForWeek(int? week) {
    if (week == null) return null;
    for (final img in images) {
      if (img.weekNumber == week) return img;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final weeksWithPhotos = images.map((i) => i.weekNumber).toSet().toList()
      ..sort();
    final imgA = _imageForWeek(
        weekA ?? (weeksWithPhotos.isNotEmpty ? weeksWithPhotos.first : null));
    final imgB = _imageForWeek(
        weekB ?? (weeksWithPhotos.length > 1 ? weeksWithPhotos.last : null));

    Widget body;
    if (weeksWithPhotos.isEmpty) {
      // No photos at all yet — same "no uploads" message as the photos
      // card above, kept short here since the fuller empty state with the
      // Upload button already appears in _WeeklyPhotosCard right above.
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(tr(lang, 'noGrowthPhotosYet'),
            style: const TextStyle(
                color: PigGrowthPalette.grayText, fontSize: 12.5)),
      );
    } else if (weeksWithPhotos.length == 1) {
      // Exactly one recorded week — show it as a single reference week with
      // only one (effectively disabled) dropdown, since there's nothing yet
      // to compare it against.
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WeekDropdown(
              label: tr(lang, 'weekPrefix'),
              value: weeksWithPhotos.first,
              weeks: weeksWithPhotos,
              onChanged: null,
              lang: lang),
          const SizedBox(height: 14),
          Text(tr(lang, 'uploadAnotherWeekNotice'),
              style: const TextStyle(
                  color: PigGrowthPalette.grayText, fontSize: 12.5)),
        ],
      );
    } else {
      final neitherHasImage =
          imgA?.displayPath == null && imgB?.displayPath == null;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: _WeekDropdown(
                      label: tr(lang, 'weekALabel'),
                      value: weekA ?? weeksWithPhotos.first,
                      weeks: weeksWithPhotos,
                      onChanged: onWeekAChanged,
                      lang: lang)),
              const SizedBox(width: 12),
              Expanded(
                  child: _WeekDropdown(
                      label: tr(lang, 'weekBLabel'),
                      value: weekB ?? weeksWithPhotos.last,
                      weeks: weeksWithPhotos,
                      onChanged: onWeekBChanged,
                      lang: lang)),
            ],
          ),
          const SizedBox(height: 14),
          if (imgA == null || imgB == null)
            Text(tr(lang, 'selectTwoWeeksNotice'),
                style: const TextStyle(
                    color: PigGrowthPalette.grayText, fontSize: 12.5))
          else if (neitherHasImage)
            Text(tr(lang, 'noImageAvailableMessage'),
                style: const TextStyle(
                    color: PigGrowthPalette.grayText, fontSize: 12.5))
          else
            _BeforeAfterSlider(
                before: imgA,
                after: imgB,
                beforeLabel: '${tr(lang, 'weekPrefix')} ${imgA.weekNumber}',
                afterLabel: '${tr(lang, 'weekPrefix')} ${imgB.weekNumber}'),
        ],
      );
    }

    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'growthComparisonSection'),
              style: pigGrowthSectionTitleStyle),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }
}

class _WeekDropdown extends StatelessWidget {
  const _WeekDropdown(
      {required this.label,
      required this.value,
      required this.weeks,
      required this.onChanged,
      required this.lang});
  final String label;
  final int value;
  final List<int> weeks;
  // Nullable so a single-week Growth Comparison can render this dropdown
  // disabled (DropdownButton treats onChanged: null as disabled) instead of
  // omitting it entirely — the week number is still visible for context.
  final ValueChanged<int?>? onChanged;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: PigGrowthPalette.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PigGrowthPalette.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: weeks.contains(value) ? value : weeks.first,
          isExpanded: true,
          hint: Text(label),
          items: weeks
              .map((w) => DropdownMenuItem(
                  value: w, child: Text('${tr(lang, 'weekPrefix')} $w')))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _BeforeAfterSlider extends StatefulWidget {
  const _BeforeAfterSlider(
      {required this.before,
      required this.after,
      required this.beforeLabel,
      required this.afterLabel});
  final WeeklyPigImage before;
  final WeeklyPigImage after;
  final String beforeLabel;
  final String afterLabel;

  @override
  State<_BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<_BeforeAfterSlider> {
  double _position = 0.5;

  Widget _imageFor(String? path) {
    if (path == null)
      return Container(
          color: PigGrowthPalette.lightGreen,
          child:
              const Center(child: Text('🐷', style: TextStyle(fontSize: 48))));
    if (path.startsWith('http')) return Image.network(path, fit: BoxFit.cover);
    return Image.file(File(path), fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() => _position =
                  (_position + details.delta.dx / width).clamp(0.0, 1.0));
            },
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(child: _imageFor(widget.after.displayPath)),
                  Positioned.fill(
                    child: ClipRect(
                      clipper: _LeftClipper(fraction: _position),
                      child: _imageFor(widget.before.displayPath),
                    ),
                  ),
                  Positioned(
                    left: (width * _position - 1).clamp(0, width - 2),
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.white),
                  ),
                  Positioned(
                    left: (width * _position - 14).clamp(0, width - 28),
                    top: 96,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.drag_handle,
                          size: 16, color: PigGrowthPalette.darkText),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _CompareBadge(text: widget.beforeLabel),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _CompareBadge(text: widget.afterLabel),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompareBadge extends StatelessWidget {
  const _CompareBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.black54, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper({required this.fraction});
  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(covariant _LeftClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

/// Notes — reads/writes WeeklyPigImage.notes for the currently selected
/// comparison week (Week B), the same field the model has always had; the
/// only new piece of wiring is PigRepository.updateWeeklyImageNotes()/
/// PigDetailController.saveWeeklyImageNotes(), a small, explicitly-scoped
/// addition (see file header) since there was previously no save path for
/// notes-only edits.
class _NotesCard extends StatelessWidget {
  const _NotesCard(
      {required this.images,
      required this.selectedWeek,
      required this.onSaveNote,
      required this.lang});
  final List<WeeklyPigImage> images;
  final int? selectedWeek;
  final Future<bool> Function(String imageId, String notes) onSaveNote;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    WeeklyPigImage? target;
    if (selectedWeek != null) {
      for (final img in images) {
        if (img.weekNumber == selectedWeek) target = img;
      }
    }
    target ??= images.isEmpty
        ? null
        : (images..sort((a, b) => b.weekNumber.compareTo(a.weekNumber))).first;

    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'notesSection'), style: pigGrowthSectionTitleStyle),
          const SizedBox(height: 10),
          Text(
            target == null || target.notes.trim().isEmpty
                ? tr(lang, 'noNotesAddedYet')
                : '${target.notes}\n— ${tr(lang, 'weekPrefix')} ${target.weekNumber}',
            style: TextStyle(
                fontSize: 13,
                color: target == null || target.notes.trim().isEmpty
                    ? PigGrowthPalette.grayText
                    : PigGrowthPalette.darkText),
          ),
        ],
      ),
    );
  }
}
