import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/theme/app_design_system.dart'
    show ShimmerListSkeleton;
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/domain/dashboard_calculations.dart'
    show growthPercent;
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../dashboard/presentation/widgets/dashboard_drawer.dart';
import '../../../growth/presentation/providers/growth_providers.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/pig.dart';
import '../../domain/weekly_pig_image.dart';
import '../providers/pig_providers.dart';
import '../screens/pig_detail_screen.dart' show kTotalCycleWeeks;
import '../theme/pig_growth_palette.dart';

// ══════════════════════════════════════════════════════════════════════
// Pig Growth Dashboard — redesigned from a bare pig list into a livestock
// management dashboard: four summary stat cards, search/filter/sort, and a
// richer per-pig card with real Age/Weight/Latest Upload/Completed Weeks
// metrics and a progress bar. This is a UI redesign only — every number
// comes from the same PigRepository/pigListProvider/weeklyImagesProvider
// this screen (and PigDetailScreen) already used; the only additions are
// allWeeklyImagesProvider (a read-only aggregation over the existing
// getWeeklyImages() calls, see pig_providers.dart) and small presentation-
// layer helpers below (age-in-days, completed-week count) that derive
// display values from already-loaded data without changing any repository,
// model, or calculation.
// ══════════════════════════════════════════════════════════════════════

enum _PigFilter { all, active, completedGrowth, male, female }

enum _PigSort { name, age, latestUpload, weight }

class PigListScreen extends ConsumerStatefulWidget {
  const PigListScreen({super.key});

  @override
  ConsumerState<PigListScreen> createState() => _PigListScreenState();
}

class _PigListScreenState extends ConsumerState<PigListScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  _PigFilter _filter = _PigFilter.all;
  _PigSort _sort = _PigSort.name;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final pigsAsync = ref.watch(pigListProvider(uid));
    final imagesAsync = ref.watch(allWeeklyImagesProvider(uid));
    // Batch-level Current Weight/Growth% for the Growth Overview card's
    // "Avg. Weight"/"Growth" stats — the same GrowthData this pig's own
    // Herd Growth section reads (see pig_detail_screen.dart), reused here
    // rather than recomputed, since weight/growth is recorded once per
    // production batch, not per individual pig.
    final growthAsync = ref.watch(growthControllerProvider(uid));
    final fullName =
        ref.watch(userProfileProvider(uid)).valueOrNull?['fullName'] as String?;
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: PigGrowthPalette.background,
      drawer: DashboardDrawer(uid: uid, fullName: fullName),
      appBar: pigGrowthAppBar(
          title: tr(lang, 'pigGrowthTitle'),
          uid: uid,
          fullName: fullName,
          lang: lang),
      body: pigsAsync.when(
        data: (pigs) {
          final images = imagesAsync.valueOrNull ?? const {};
          final visible = _visiblePigs(pigs, images);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pigListProvider(uid));
              ref.invalidate(allWeeklyImagesProvider(uid));
            },
            // CustomScrollView + SliverList.builder (instead of a single
            // ListView with every pig card spread in eagerly) so that on a
            // large farm (50-100+ pigs) only the cards actually scrolled
            // into view get built — the header controls above stay a single
            // SliverToBoxAdapter since they're fixed, small, and already
            // cheap to build once per frame.
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: pigGrowthAnimatedChildren([
                        Text(tr(lang, 'pigGrowthTitle'),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: PigGrowthPalette.darkText)),
                        Text(tr(lang, 'trackPigsGrowthSubtitle'),
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: PigGrowthPalette.grayText)),
                        const SizedBox(height: 14),
                        const _FarmVisualBanner(),
                        const SizedBox(height: 16),
                        _GrowthOverviewCard(
                            pigs: pigs,
                            images: images,
                            growthData: growthAsync.valueOrNull,
                            lang: lang),
                        const SizedBox(height: 16),
                        _AddPigButton(
                            onTap: () => context.push('${AppRoutes.pigs}/new'),
                            lang: lang),
                        const SizedBox(height: 16),
                        _SearchField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(
                                () => _search = v.trim().toLowerCase()),
                            lang: lang),
                        const SizedBox(height: 12),
                        _FilterChipsRow(
                            selected: _filter,
                            onSelected: (f) => setState(() => _filter = f),
                            lang: lang),
                        const SizedBox(height: 12),
                        _SortDropdown(
                            sort: _sort,
                            onChanged: (s) => setState(() => _sort = s!),
                            lang: lang),
                        const SizedBox(height: 16),
                        Text(tr(lang, 'registeredPigsSection'),
                            style: pigGrowthSectionTitleStyle),
                        const SizedBox(height: 10),
                      ]),
                    ),
                  ),
                ),
                if (pigs.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverToBoxAdapter(
                        child: _EmptyState(
                            onAddPig: () =>
                                context.push('${AppRoutes.pigs}/new'),
                            lang: lang)),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final pig = visible[i];
                        return Padding(
                          key: ValueKey(pig.id),
                          padding: const EdgeInsets.only(bottom: 14),
                          // Cap the stagger delay (instead of i*60 growing
                          // unbounded) so cards that scroll into view later
                          // in a long list still animate promptly.
                          child: PigGrowthFadeSlideIn(
                            delayMs: (i % 8) * 50,
                            child: _PigCard(
                              pig: pig,
                              images: images[pig.id] ?? const [],
                              lang: lang,
                              onTap: () =>
                                  context.push('${AppRoutes.pigs}/${pig.id}'),
                              onEdit: () => context.push(
                                  '${AppRoutes.pigs}/${pig.id}/edit',
                                  extra: pig),
                              onDelete: () =>
                                  _confirmDelete(context, ref, uid, pig, lang),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const ShimmerListSkeleton(count: 3, itemHeight: 140),
        error: (_, __) => Center(child: Text(tr(lang, 'couldNotLoadPigs'))),
      ),
    );
  }

  List<Pig> _visiblePigs(
      List<Pig> pigs, Map<String, List<WeeklyPigImage>> images) {
    var result = [...pigs];
    if (_search.isNotEmpty) {
      result = result
          .where((p) =>
              p.name.toLowerCase().contains(_search) ||
              p.id.toLowerCase().contains(_search))
          .toList();
    }
    result = result.where((p) {
      final completed = _completedWeeksForPig(images[p.id] ?? const []);
      switch (_filter) {
        case _PigFilter.all:
          return true;
        case _PigFilter.active:
          return completed < kTotalCycleWeeks;
        case _PigFilter.completedGrowth:
          return completed >= kTotalCycleWeeks;
        case _PigFilter.male:
          return p.gender.toLowerCase() == 'male';
        case _PigFilter.female:
          return p.gender.toLowerCase() == 'female';
      }
    }).toList();
    switch (_sort) {
      case _PigSort.name:
        result.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _PigSort.age:
        result.sort((a, b) => _ageDays(b).compareTo(_ageDays(a)));
        break;
      case _PigSort.latestUpload:
        result.sort((a, b) {
          final au = _latestUploadForPig(images[a.id] ?? const []) ?? '';
          final bu = _latestUploadForPig(images[b.id] ?? const []) ?? '';
          return bu.compareTo(au);
        });
        break;
      case _PigSort.weight:
        result.sort((a, b) => b.initialWeight.compareTo(a.initialWeight));
        break;
    }
    return result;
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String uid,
      Pig pig, AppLanguage lang) async {
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
    if (confirmed == true) {
      await ref.read(pigRepositoryProvider).deletePig(uid, pig.id);
      await ref.read(authRepositoryProvider).recordActivityLog(
          uid: uid,
          actionType: 'pig',
          description: 'deleted pig ${pig.name} (${pig.id})');
      ref.invalidate(pigListProvider(uid));
      ref.invalidate(allWeeklyImagesProvider(uid));
      ref.invalidate(dashboardControllerProvider(uid));
    }
  }
}

// ── Presentation-only helpers — pure derivations over already-loaded data,
// no new persistence or business calculation. ──

int _ageDays(Pig pig) {
  final dateStr = pig.arrivalDate.isNotEmpty ? pig.arrivalDate : pig.birthDate;
  final date = DateTime.tryParse(dateStr);
  if (date == null) return 0;
  final start = DateTime(date.year, date.month, date.day);
  final today = DateTime.now();
  return DateTime(today.year, today.month, today.day).difference(start).inDays;
}

int _completedWeeksForPig(List<WeeklyPigImage> images) =>
    images.map((i) => i.weekNumber).toSet().length;

String? _latestUploadForPig(List<WeeklyPigImage> images) {
  final dates = images
      .map((i) => i.captureDate)
      .where((d) => d.isNotEmpty)
      .toList()
    ..sort();
  return dates.isEmpty ? null : dates.last;
}

int _totalDistinctWeeksRecorded(Map<String, List<WeeklyPigImage>> images) {
  final weeks = <int>{};
  for (final list in images.values) {
    for (final img in list) {
      weeks.add(img.weekNumber);
    }
  }
  return weeks.length;
}

int _totalPhotosOverall(Map<String, List<WeeklyPigImage>> images) =>
    images.values.fold(0, (sum, l) => sum + l.length);

/// Count of pigs still mid-cycle (same predicate as _PigFilter.active below
/// — reused rather than reinvented) — pigs that haven't yet completed all
/// [kTotalCycleWeeks] weekly-photo slots.
int _activePigsCount(List<Pig> pigs, Map<String, List<WeeklyPigImage>> images) {
  return pigs
      .where((p) =>
          _completedWeeksForPig(images[p.id] ?? const []) < kTotalCycleWeeks)
      .length;
}

String _formatDisplayDate(String isoDate, AppLanguage lang) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  final months = monthAbbrev(lang);
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Status chip tiers — purely derived from the same completed-weeks/latest-
/// upload numbers already computed for the card, no new database field.
/// noPhotos: nothing uploaded at all. completed: hit the full cycle.
/// active: mid-cycle with a recent upload (within 10 days) — on track.
/// stale: mid-cycle but no upload in over 10 days — needs attention.
enum _PigStatus { noPhotos, active, stale, completed }

_PigStatus _deriveStatus(int completed, String? latestUpload) {
  if (completed == 0) return _PigStatus.noPhotos;
  if (completed >= kTotalCycleWeeks) return _PigStatus.completed;
  final last = latestUpload == null ? null : DateTime.tryParse(latestUpload);
  if (last == null) return _PigStatus.stale;
  final daysSince = DateTime.now().difference(last).inDays;
  return daysSince <= 10 ? _PigStatus.active : _PigStatus.stale;
}

/// Subtle decorative farm illustration banner shown under the header — no
/// financial/growth data, purely visual, matching the same pattern used on
/// the redesigned Expense & ROI screen's banner.
class _FarmVisualBanner extends StatelessWidget {
  const _FarmVisualBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 88,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFDCEFDA), Color(0xFFC8E6C9)]),
        ),
        child: const Stack(
          children: [
            Positioned(
                left: 16,
                top: 12,
                child: Opacity(
                    opacity: 0.9,
                    child: Text('🏡', style: TextStyle(fontSize: 26)))),
            Positioned(
                right: 64,
                bottom: 6,
                child: Opacity(
                    opacity: 0.85,
                    child: Text('🌾', style: TextStyle(fontSize: 28)))),
            Positioned(
                right: 14,
                bottom: 2,
                child: Opacity(
                    opacity: 0.95,
                    child: Text('🐖', style: TextStyle(fontSize: 36)))),
            Positioned(
                left: 76,
                bottom: 4,
                child: Opacity(
                    opacity: 0.8,
                    child: Text('🌳', style: TextStyle(fontSize: 26)))),
          ],
        ),
      ),
    );
  }
}

/// "Growth Overview" — a single grouped card (matching the mockup) holding
/// a small sub-heading plus a grid of stat items: Total Pigs, Active Pigs,
/// Avg. Weight, Growth %, Weeks Recorded, Growth Photos. The per-pig counts
/// are pure derivations over already-loaded weekly-image data (see the
/// helper functions above this class); Avg. Weight/Growth % reuse the same
/// batch-level GrowthData (currentWeight/growthPercent()) already shown on
/// this pig's Herd Growth card in pig_detail_screen.dart — recorded once per
/// production batch, not per individual pig, so "Avg. Weight" here is that
/// same shared figure, not a new per-pig average calculation. No new
/// persistence or calculation is introduced anywhere in this card.
class _GrowthOverviewCard extends StatelessWidget {
  const _GrowthOverviewCard({
    required this.pigs,
    required this.images,
    required this.growthData,
    required this.lang,
  });
  final List<Pig> pigs;
  final Map<String, List<WeeklyPigImage>> images;
  final GrowthData? growthData;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final weeksRecorded = _totalDistinctWeeksRecorded(images);
    final totalPhotos = _totalPhotosOverall(images);
    final totalPigs = pigs.length;
    final activePigs = _activePigsCount(pigs, images);
    final avgWeight = growthData?.currentWeight;
    final growthPct = growthData == null
        ? null
        : growthPercent(
            startWeight: growthData!.batchProfile?.startWeight,
            currentWeight: growthData!.currentWeight);

    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: PigGrowthPalette.lightGreen,
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.insights_rounded,
                    size: 16, color: PigGrowthPalette.primaryGreen),
              ),
              const SizedBox(width: 10),
              Text(tr(lang, 'growthOverviewLabel'),
                  style: pigGrowthSectionTitleStyle),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              _StatItem(
                  icon: Icons.pets,
                  value: '$totalPigs',
                  label: tr(lang, 'totalPigsLabel')),
              _StatItem(
                  icon: Icons.favorite_border,
                  value: '$activePigs',
                  label: tr(lang, 'activePigsLabel')),
              _StatItem(
                  icon: Icons.monitor_weight_outlined,
                  value: avgWeight == null
                      ? '—'
                      : '${avgWeight.toStringAsFixed(1)} kg',
                  label: tr(lang, 'averageWeightLabel')),
              _StatItem(
                  icon: Icons.trending_up_rounded,
                  value: growthPct == null ? '—' : '${growthPct.round()}%',
                  label: tr(lang, 'growthPercent')),
              _StatItem(
                  icon: Icons.calendar_month,
                  value: '$weeksRecorded',
                  label: tr(lang, 'weeksRecordedCaption')),
              _StatItem(
                  icon: Icons.image,
                  value: '$totalPhotos',
                  label: tr(lang, 'growthPhotosCaption')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem(
      {required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: PigGrowthPalette.lightGreen,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 17, color: PigGrowthPalette.primaryGreen),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: PigGrowthPalette.darkText)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: PigGrowthPalette.grayText,
                      letterSpacing: 0.2)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddPigButton extends StatelessWidget {
  const _AddPigButton({required this.onTap, required this.lang});
  final VoidCallback onTap;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: PigGrowthPalette.primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.add),
        label: Text(tr(lang, 'addPigButton'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField(
      {required this.controller, required this.onChanged, required this.lang});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: PigGrowthPalette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PigGrowthPalette.border)),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon:
              const Icon(Icons.search, color: PigGrowthPalette.grayText),
          hintText: tr(lang, 'searchPigHint'),
          hintStyle:
              const TextStyle(color: PigGrowthPalette.grayText, fontSize: 13.5),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow(
      {required this.selected, required this.onSelected, required this.lang});
  final _PigFilter selected;
  final ValueChanged<_PigFilter> onSelected;
  final AppLanguage lang;

  Map<_PigFilter, String> _labels(AppLanguage lang) => {
        _PigFilter.all: tr(lang, 'filterAllPigs'),
        _PigFilter.active: tr(lang, 'filterActive'),
        _PigFilter.completedGrowth: tr(lang, 'filterCompletedGrowth'),
        _PigFilter.male: tr(lang, 'filterMale'),
        _PigFilter.female: tr(lang, 'filterFemale'),
      };

  @override
  Widget build(BuildContext context) {
    final labels = _labels(lang);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _PigFilter.values.map((f) {
          final isSelected = f == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labels[f]!),
              selected: isSelected,
              onSelected: (_) => onSelected(f),
              selectedColor: PigGrowthPalette.primaryGreen,
              labelStyle: TextStyle(
                  color: isSelected ? Colors.white : PigGrowthPalette.darkText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5),
              backgroundColor: PigGrowthPalette.card,
              side: BorderSide(
                  color: isSelected
                      ? PigGrowthPalette.primaryGreen
                      : PigGrowthPalette.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown(
      {required this.sort, required this.onChanged, required this.lang});
  final _PigSort sort;
  final ValueChanged<_PigSort?> onChanged;
  final AppLanguage lang;

  Map<_PigSort, String> _labels(AppLanguage lang) => {
        _PigSort.name: tr(lang, 'sortName'),
        _PigSort.age: tr(lang, 'sortAge'),
        _PigSort.latestUpload: tr(lang, 'sortLatestUpload'),
        _PigSort.weight: tr(lang, 'sortWeight'),
      };

  @override
  Widget build(BuildContext context) {
    final labels = _labels(lang);
    return Row(
      children: [
        Text(tr(lang, 'sortByLabel'),
            style: const TextStyle(
                fontSize: 13, color: PigGrowthPalette.grayText)),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: PigGrowthPalette.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PigGrowthPalette.border)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_PigSort>(
                value: sort,
                isExpanded: true,
                items: _PigSort.values
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(labels[s]!)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddPig, required this.lang});
  final VoidCallback onAddPig;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.pets_outlined,
              size: 48, color: PigGrowthPalette.grayText),
          const SizedBox(height: 12),
          Text(tr(lang, 'noPigRecordsTitle'),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: PigGrowthPalette.darkText)),
          const SizedBox(height: 6),
          Text(
            tr(lang, 'noPigRecordsBody'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: PigGrowthPalette.grayText, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _PigCard extends StatelessWidget {
  const _PigCard(
      {required this.pig,
      required this.images,
      required this.onTap,
      required this.onEdit,
      required this.onDelete,
      required this.lang});
  final Pig pig;
  final List<WeeklyPigImage> images;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final ageDays = _ageDays(pig);
    final ageWeeks = (ageDays / 7).floor();
    final completed = _completedWeeksForPig(images);
    final latestUpload = _latestUploadForPig(images);
    final progress = (completed / kTotalCycleWeeks).clamp(0.0, 1.0);
    final isMale = pig.gender.toLowerCase() == 'male';

    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PigAvatar(pig: pig, isMale: isMale),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pig.name.isEmpty ? pig.id : pig.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15.5,
                                color: PigGrowthPalette.darkText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(isMale ? Icons.male : Icons.female,
                            size: 16,
                            color: isMale
                                ? const Color(0xFF1E88E5)
                                : const Color(0xFFEC407A)),
                      ],
                    ),
                    Text(
                      '${pig.id} · ${pig.breed.isEmpty ? tr(lang, 'unknownBreed') : pig.breed}',
                      style: const TextStyle(
                          fontSize: 12, color: PigGrowthPalette.grayText),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _StatusChip(
                        status: _deriveStatus(completed, latestUpload),
                        lang: lang),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    color: PigGrowthPalette.grayText),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text(tr(lang, 'edit'))),
                  PopupMenuItem(
                      value: 'delete', child: Text(tr(lang, 'delete'))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _MetricTile(
                      label: tr(lang, 'ageMetricLabel'),
                      value:
                          '$ageDays ${tr(lang, 'daysUnit')} ($ageWeeks ${tr(lang, 'wksUnit')})')),
              const SizedBox(width: 10),
              Expanded(
                  child: _MetricTile(
                      label: tr(lang, 'weightMetricLabel'),
                      value: '${pig.initialWeight.toStringAsFixed(1)} kg')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _MetricTile(
                      label: tr(lang, 'lastUploadMetricLabel'),
                      value: latestUpload == null
                          ? '—'
                          : _formatDisplayDate(latestUpload, lang)
                              .replaceFirst(RegExp(r', \d+$'), ''))),
              const SizedBox(width: 10),
              Expanded(
                  child: _MetricTile(
                      label: tr(lang, 'weeksMetricLabel'),
                      value: '$completed / $kTotalCycleWeeks')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr(lang, 'growthProgressLabel'),
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: PigGrowthPalette.grayText)),
              Text(
                  '$completed / $kTotalCycleWeeks ${tr(lang, 'weeksCompletedSuffix')}',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: PigGrowthPalette.darkText)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: PigGrowthPalette.border,
                      valueColor: const AlwaysStoppedAnimation(
                          PigGrowthPalette.primaryGreen),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${(progress * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: PigGrowthPalette.primaryGreen)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: PigGrowthPalette.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(tr(lang, 'viewGrowthButton'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: PigGrowthPalette.background,
          borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: PigGrowthPalette.grayText,
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: PigGrowthPalette.darkText),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _PigAvatar extends StatelessWidget {
  const _PigAvatar({required this.pig, required this.isMale});
  final Pig pig;
  final bool isMale;

  @override
  Widget build(BuildContext context) {
    final bg = isMale ? const Color(0xFFFFE0B2) : const Color(0xFFF8BBD0);
    return Container(
      width: 56,
      height: 56,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: pig.photoLocalPath != null
          // cacheWidth/cacheHeight decode the thumbnail at display size
          // instead of full resolution, then Flutter's own ImageCache keeps
          // that decoded frame around across rebuilds/scrolls — meaningful
          // memory/CPU savings once a farm has 50-100+ pig photos on screen.
          ? Image.file(File(pig.photoLocalPath!),
              fit: BoxFit.cover, cacheWidth: 112, cacheHeight: 112)
          : const Center(child: Text('🐷', style: TextStyle(fontSize: 26))),
    );
  }
}

/// Status chip — purely derived (see _deriveStatus), no new database field.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.lang});
  final _PigStatus status;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final (label, dotColor, bg, fg) = switch (status) {
      _PigStatus.active => (
          tr(lang, 'statusActive'),
          const Color(0xFF4CAF50),
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32)
        ),
      _PigStatus.stale => (
          tr(lang, 'statusInProgress'),
          const Color(0xFFFB8C00),
          PigGrowthPalette.lightOrange,
          const Color(0xFFB26A00)
        ),
      _PigStatus.completed => (
          tr(lang, 'statusCompleted'),
          const Color(0xFF1E88E5),
          const Color(0xFFE3F2FD),
          const Color(0xFF1565C0)
        ),
      _PigStatus.noPhotos => (
          tr(lang, 'statusNoPhotosYet'),
          PigGrowthPalette.grayText,
          const Color(0xFFF1F1F1),
          PigGrowthPalette.grayText
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}
