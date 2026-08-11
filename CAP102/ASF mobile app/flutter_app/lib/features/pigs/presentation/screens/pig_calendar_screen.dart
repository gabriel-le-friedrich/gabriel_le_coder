import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/widgets/dashboard_app_bar_actions.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/weekly_pig_image.dart';
import '../providers/pig_providers.dart';
import '../theme/pig_growth_palette.dart';

// ══════════════════════════════════════════════════════════════════════
// Calendar View — a monthly calendar of this pig's real weekly-photo
// upload dates (WeeklyPigImage.captureDate), plus a Growth Timeline list
// of every week that actually has a recorded photo. New screen (there was
// no calendar view for weekly photos before), but every value on it comes
// straight from the existing weeklyImagesProvider/PigRepository — no new
// persistence or calculation. Tapping a timeline card returns that week
// number to the caller (Growth History), which pre-selects it as "Week B"
// in the Growth Comparison slider.
// ══════════════════════════════════════════════════════════════════════
class PigCalendarScreen extends ConsumerStatefulWidget {
  const PigCalendarScreen({super.key, required this.pigId});
  final String pigId;

  @override
  ConsumerState<PigCalendarScreen> createState() => _PigCalendarScreenState();
}

class _PigCalendarScreenState extends ConsumerState<PigCalendarScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final fullName =
        ref.watch(userProfileProvider(uid)).valueOrNull?['fullName'] as String?;
    final pigAsync =
        ref.watch(pigByIdProvider((uid: uid, pigId: widget.pigId)));
    final imagesAsync =
        ref.watch(weeklyImagesProvider((uid: uid, pigId: widget.pigId)));
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: PigGrowthPalette.background,
      appBar: AppBar(
        backgroundColor: PigGrowthPalette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
            '${pigAsync.valueOrNull?.name ?? tr(lang, 'pigFallback')} · ${tr(lang, 'calendarSuffix')}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black87)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DashboardAppBarActions(uid: uid, fullName: fullName),
          ),
        ],
      ),
      body: imagesAsync.when(
        data: (images) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: pigGrowthAnimatedChildren([
            _MonthCalendarCard(
              month: _month,
              images: images,
              lang: lang,
              onPrevMonth: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1, 1)),
              onNextMonth: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1, 1)),
            ),
            const SizedBox(height: 16),
            Text(tr(lang, 'growthTimelineSectionUpper'),
                style: pigGrowthSectionTitleStyle),
            const SizedBox(height: 10),
            if (images.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(tr(lang, 'noWeeklyPhotosYet'),
                    style: const TextStyle(
                        color: PigGrowthPalette.grayText, fontSize: 12.5)),
              )
            else
              ...(([...images]
                    ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber)))
                  .map((img) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TimelineRow(
                            image: img,
                            lang: lang,
                            onTap: () => context.pop(img.weekNumber)),
                      ))),
          ]),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(tr(lang, 'couldNotLoadCalendar'))),
      ),
    );
  }
}

class _MonthCalendarCard extends StatelessWidget {
  const _MonthCalendarCard(
      {required this.month,
      required this.images,
      required this.onPrevMonth,
      required this.onNextMonth,
      required this.lang});
  final DateTime month;
  final List<WeeklyPigImage> images;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final monthNamesList = monthNames(lang);
    final weekdayLabelsList = weekdayLabels(lang);
    final today = DateTime.now();
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstDayOfMonth.weekday %
        7; // DateTime.weekday: Mon=1..Sun=7 -> Sun=0..Sat=6

    // day -> week number, instead of just a Set<int>, so each highlighted
    // cell can show which week's photo it is (e.g. "W2"), not just a plain
    // green square.
    final photoDayWeeks = <int, int>{};
    for (final img in images) {
      final d = DateTime.tryParse(img.captureDate);
      if (d != null && d.year == month.year && d.month == month.month)
        photoDayWeeks[d.day] = img.weekNumber;
    }

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: tr(lang, 'previousMonth'),
                  onPressed: onPrevMonth,
                  color: PigGrowthPalette.darkText),
              Text('${monthNamesList[month.month - 1]} ${month.year}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: PigGrowthPalette.darkText)),
              IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: tr(lang, 'nextMonth'),
                  onPressed: onNextMonth,
                  color: PigGrowthPalette.darkText),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: weekdayLabelsList
                .map((w) => Expanded(
                    child: Center(
                        child: Text(w,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: PigGrowthPalette.grayText)))))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingBlanks + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();
              final day = index - leadingBlanks + 1;
              final week = photoDayWeeks[day];
              final hasPhoto = week != null;
              final isToday = today.year == month.year &&
                  today.month == month.month &&
                  today.day == day;
              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hasPhoto
                      ? PigGrowthPalette.lightGreen
                      : PigGrowthPalette.background,
                  borderRadius: BorderRadius.circular(10),
                  border: isToday
                      ? Border.all(
                          color: PigGrowthPalette.primaryGreen, width: 2)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$day',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.w500,
                            color: PigGrowthPalette.darkText)),
                    if (hasPhoto)
                      // Tiny camera icon + week-number badge, so the calendar
                      // reads as "photo taken for Week 2" at a glance instead
                      // of just a plain colored square.
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_camera,
                              size: 8, color: PigGrowthPalette.primaryGreen),
                          const SizedBox(width: 1),
                          Text('W$week',
                              style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: PigGrowthPalette.primaryGreen)),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _CalendarLegend(lang: lang),
        ],
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, {bool outline = false}) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: outline ? PigGrowthPalette.background : c,
            border: outline ? Border.all(color: c, width: 2) : null,
            borderRadius: BorderRadius.circular(4),
          ),
        );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          dot(PigGrowthPalette.lightGreen),
          const SizedBox(width: 4),
          Text(tr(lang, 'hasPhotoLegend'),
              style: const TextStyle(
                  fontSize: 11, color: PigGrowthPalette.grayText))
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          dot(PigGrowthPalette.background),
          const SizedBox(width: 4),
          Text(tr(lang, 'noPhotoLegend'),
              style: const TextStyle(
                  fontSize: 11, color: PigGrowthPalette.grayText))
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          dot(PigGrowthPalette.primaryGreen, outline: true),
          const SizedBox(width: 4),
          Text(tr(lang, 'todayLegend'),
              style: const TextStyle(
                  fontSize: 11, color: PigGrowthPalette.grayText))
        ]),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow(
      {required this.image, required this.onTap, required this.lang});
  final WeeklyPigImage image;
  final VoidCallback onTap;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final path = image.displayPath;
    return Material(
      color: PigGrowthPalette.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PigGrowthPalette.border)),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: PigGrowthPalette.lightGreen,
                    borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: path == null
                    ? const Center(
                        child: Icon(Icons.camera_alt_outlined,
                            color: PigGrowthPalette.grayText))
                    : (path.startsWith('http')
                        ? Image.network(path, fit: BoxFit.cover)
                        : Image.file(File(path), fit: BoxFit.cover)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${tr(lang, 'weekPrefix')} ${image.weekNumber}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: PigGrowthPalette.darkText)),
                    Text(
                      image.captureDate.isEmpty
                          ? tr(lang, 'noImageUploaded')
                          : '${tr(lang, 'uploadedPrefix')} ${image.captureDate}',
                      style: const TextStyle(
                          fontSize: 11.5, color: PigGrowthPalette.grayText),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: PigGrowthPalette.grayText),
            ],
          ),
        ),
      ),
    );
  }
}
