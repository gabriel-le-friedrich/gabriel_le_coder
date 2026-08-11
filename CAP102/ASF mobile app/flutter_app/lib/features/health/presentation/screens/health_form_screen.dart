import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/theme/dashboard_palette.dart';
import '../../../pigs/domain/pig.dart';
import '../../../pigs/presentation/providers/pig_providers.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/health_draft_repository.dart';
import '../../data/vet_contact_repository.dart';
import '../../domain/health_calculations.dart';
import '../../domain/health_status_colors.dart';
import '../providers/health_providers.dart';
import '../providers/vet_contact_providers.dart';

/// Add/Edit Health Observation — Behavior / Appetite / Waste Condition
/// stay single-select rounded cards; Physical Condition is now
/// MULTIPLE select, grouped into Healthy Indicators / Needs Monitoring /
/// At Risk / Critical sections. Overall status comes from
/// computeHealthAssessment() (see health_calculations.dart) rather than a
/// simple "highest tier wins" rule.
///
/// Two distinct "Critical" surfaces exist here on purpose: the moment the
/// farmer ticks one of the named Emergency symptoms (Collapse, Unable to
/// Stand, etc. — see kEmergencySymptomKeys), the alert fires immediately,
/// live, before they've even finished the rest of the form. The same
/// alert also fires after Save if the final assessment came out Critical
/// through the count/score rules instead (e.g. several lesser
/// Critical-severity symptoms adding up) — but only if the immediate one
/// didn't already show for this session, so the farmer isn't shown the
/// same warning twice.
class HealthFormScreen extends ConsumerStatefulWidget {
  const HealthFormScreen(
      {super.key,
      this.editing,
      this.pigId,
      this.pigName,
      this.sessionId,
      this.herdProgressLabel,
      this.onSavedInHerdFlow});
  final HealthLogEntry? editing;

  /// Health Monitor redesign — when set, this check is attributed to one
  /// real pig (Specific Pig / Overall Herd modes) instead of the
  /// pre-redesign flock-level form. Falls back to [editing]'s own
  /// pigId/pigName when editing an existing per-pig entry and these aren't
  /// explicitly supplied.
  final String? pigId;
  final String? pigName;

  /// Groups this check with the other individual pig checks in the same
  /// "Overall Herd" run — purely metadata (see HealthLogEntry.sessionId).
  final String? sessionId;

  /// e.g. "Pig 2 of 5" — shown instead of the default title when this
  /// screen is one step of a herd run.
  final String? herdProgressLabel;

  /// Overall Herd flow hook: called with the saved entry instead of the
  /// screen popping itself, so the herd controller can advance to the next
  /// pig (or the summary) rather than returning to whatever launched the
  /// herd run.
  final void Function(HealthLogEntry saved)? onSavedInHerdFlow;

  @override
  ConsumerState<HealthFormScreen> createState() => _HealthFormScreenState();
}

class _HealthFormScreenState extends ConsumerState<HealthFormScreen> {
  late final TextEditingController _notesCtrl;
  late final TextEditingController _assessedByCtrl;
  final _notesFocus = FocusNode();
  final _assessedByFocus = FocusNode();
  bool _emergencyAlertShown = false;

  /// Scroll target for the "Incomplete Health Assessment" validation guard
  /// — Physical Condition is the only category without a default
  /// selection, so it's the section we auto-scroll to.
  final _scrollController = ScrollController();
  final _physicalSectionKey = GlobalKey();

  // Round 3 items 4 & 6 — both are one-shot checks that only make sense
  // for a brand-new (non-editing) observation, and each should only ever
  // prompt once per screen instance.
  bool _duplicateChecked = false;
  bool _duplicateExists = false;
  bool _draftPromptShown = false;

  /// Which real pig this check belongs to, if any — explicit [widget.pigId]
  /// wins, otherwise falls back to the entry being edited (so opening an
  /// existing per-pig log from History still scopes drafts/duplicate-guard
  /// correctly without the caller having to pass it again).
  String? get _pigId => widget.pigId ?? widget.editing?.pigId;
  String? get _pigName => widget.pigName ?? widget.editing?.pigName;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.editing?.notes ?? '');
    _assessedByCtrl =
        TextEditingController(text: widget.editing?.assessedBy ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _assessedByCtrl.dispose();
    _notesFocus.dispose();
    _assessedByFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final pigId = _pigId;
    final params = (
      editing: editing,
      pigId: pigId,
      pigName: _pigName,
      sessionId: widget.sessionId,
    );
    final state = ref.watch(healthFormControllerProvider(params));
    final controller = ref.read(healthFormControllerProvider(params).notifier);
    final lang = ref.watch(appLanguageProvider);
    final pigAsync = (pigId != null && pigId.isNotEmpty && uid.isNotEmpty)
        ? ref.watch(pigByIdProvider((uid: uid, pigId: pigId)))
        : null;

    ref.listen(healthFormControllerProvider(params), (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
      if (next.savedEntry != null && next.savedEntry != previous?.savedEntry) {
        final saved = next.savedEntry!;
        if (widget.onSavedInHerdFlow == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 5),
              content: Text(
                '${tr(lang, 'healthSavedSnackbar')}\n'
                '${tr(lang, 'tasksUnlocked')}: ${kHealthUnlockedTaskTitles.join(', ')}',
              ),
            ),
          );
          Navigator.of(context).pop();
        }
        if (saved.status == HealthStatus.critical && !_emergencyAlertShown) {
          _showCriticalAlert(context, uid);
        }
        // Herd flow: let the herd controller advance instead of popping —
        // it owns navigating to the next pig or the summary screen.
        widget.onSavedInHerdFlow?.call(saved);
      }
    });

    // Both checks only ever apply to a brand-new observation. They're
    // chained rather than nested so that the very same build pass that
    // resolves "no duplicate for today" can immediately also check for a
    // recoverable draft, instead of waiting for a rebuild that may not
    // otherwise happen if the farmer hasn't touched anything yet.
    if (editing == null && uid.isNotEmpty) {
      final duplicateGuardAsync = pigId != null && pigId.isNotEmpty
          ? ref.watch(healthDuplicateGuardForPigProvider((uid: uid, pigId: pigId)))
          : ref.watch(healthDuplicateGuardProvider(uid));
      duplicateGuardAsync.whenData((guard) {
        if (!_duplicateChecked) {
          _duplicateChecked = true;
          _duplicateExists = guard.existing != null;
          if (_duplicateExists) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted)
                _showDuplicateGuardDialog(context, guard.day, guard.existing!);
            });
          }
        }
      });

      if (_duplicateChecked && !_duplicateExists && !_draftPromptShown) {
        final draftAsync = pigId != null && pigId.isNotEmpty
            ? ref.watch(healthDraftForPigProvider((uid: uid, pigId: pigId)))
            : ref.watch(healthDraftProvider(uid));
        draftAsync.whenData((draft) {
          if (draft != null && !_draftPromptShown) {
            _draftPromptShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _offerDraftRestore(context, controller, draft);
            });
          }
        });
      }
    }

    final assessment = state.liveAssessment;

    return Scaffold(
      backgroundColor: DashboardPalette.background,
      appBar:
          AppBar(backgroundColor: DashboardPalette.background, elevation: 0),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            if (widget.herdProgressLabel != null) ...[
              Text(widget.herdProgressLabel!,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: DashboardPalette.primaryGreen)),
              const SizedBox(height: 4),
            ],
            Text(
                editing != null
                    ? tr(lang, 'editObservation')
                    : tr(lang, 'healthMonitorTitle'),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              editing != null
                  ? '${tr(lang, 'editingLogFrom')} ${editing.date}'
                  : tr(lang, 'dailyObservationLog'),
              style: const TextStyle(
                  fontSize: 13, color: DashboardPalette.textGray),
            ),
            if (pigAsync != null) ...[
              const SizedBox(height: 14),
              pigAsync.when(
                data: (pig) => pig == null
                    ? const SizedBox.shrink()
                    : _PigContextCard(pig: pig),
                loading: () => const SizedBox(
                    height: 64,
                    child: Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)))),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
            const SizedBox(height: 12),
            if (widget.herdProgressLabel == null)
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.health),
                style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20))),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: Text(tr(lang, 'viewHealthLogs')),
              ),
            const SizedBox(height: 20),
            _SingleSelectGroup(
              icon: '🧠',
              title: tr(lang, 'behaviorLabel'),
              selectOneLabel: tr(lang, 'selectOne'),
              options: kBehaviorOptions,
              selected: state.behavior,
              lang: lang,
              category: 'behavior',
              onSelect: (key) {
                final becomingEmergency = key != state.behavior &&
                    kEmergencySymptomKeys.contains(key);
                controller.updateBehavior(key);
                if (becomingEmergency) _maybeShowImmediateEmergencyAlert(uid);
              },
            ),
            const SizedBox(height: 16),
            _SingleSelectGroup(
              icon: '🍽',
              title: tr(lang, 'appetiteLabel'),
              selectOneLabel: tr(lang, 'selectOne'),
              options: kAppetiteOptions,
              selected: state.appetite,
              lang: lang,
              category: 'appetite',
              onSelect: controller.updateAppetite,
            ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: _physicalSectionKey,
              child: _PhysicalMultiSelectGroup(
                lang: lang,
                selected: state.physical,
                onToggle: (key) {
                  final becomingSelected = !state.physical.contains(key);
                  controller.togglePhysical(key);
                  if (becomingSelected && kEmergencySymptomKeys.contains(key))
                    _maybeShowImmediateEmergencyAlert(uid);
                },
              ),
            ),
            const SizedBox(height: 16),
            _SingleSelectGroup(
              icon: '💩',
              title: tr(lang, 'wasteLabel'),
              selectOneLabel: tr(lang, 'selectOne'),
              options: kWasteOptions,
              selected: state.waste,
              lang: lang,
              category: 'waste',
              onSelect: controller.updateWaste,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              focusNode: _notesFocus,
              decoration: InputDecoration(
                labelText: tr(lang, 'notesOptional'),
                hintText: tr(lang, 'notesHint'),
                filled: true,
                fillColor: DashboardPalette.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.next,
              onEditingComplete: () =>
                  FocusScope.of(context).requestFocus(_assessedByFocus),
              onChanged: controller.updateNotes,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _assessedByCtrl,
              focusNode: _assessedByFocus,
              decoration: InputDecoration(
                labelText: tr(lang, 'assessedByOptional'),
                hintText: tr(lang, 'assessedByHint'),
                filled: true,
                fillColor: DashboardPalette.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
              textInputAction: TextInputAction.done,
              onChanged: controller.updateAssessedBy,
            ),
            const SizedBox(height: 20),
            _HealthSummaryCard(
                state: state, assessment: assessment, lang: lang),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                button: true,
                label: state.isSaving
                    ? tr(lang, 'saving')
                    : tr(lang, 'saveObservation'),
                liveRegion: state.isSaving,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: DashboardPalette.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: state.isSaving
                      ? null
                      : () => _handleSavePressed(context, state, controller),
                  icon: state.isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 20),
                  label: Text(state.isSaving
                      ? tr(lang, 'saving')
                      : tr(lang, 'saveObservation')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Round 3 item 1 — Physical Condition is the only category without a
  /// default selection, so an empty selection there is the one way this
  /// form can be "incomplete". Rather than silently disabling Save, show
  /// the farmer exactly what's missing and scroll straight to it.
  void _handleSavePressed(BuildContext context, HealthFormState state,
      HealthFormController controller) {
    if (!state.canSave) {
      final lang = ref.read(appLanguageProvider);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr(lang, 'incompleteAssessmentTitle')),
          content: Text(tr(lang, 'incompleteAssessmentBody')),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr(lang, 'ok')))
          ],
        ),
      ).then((_) {
        if (!context.mounted) return;
        final target = _physicalSectionKey.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(target,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              alignment: 0.05);
        }
      });
      return;
    }
    controller.submit();
  }

  /// Round 3 item 6 — a health assessment already exists for today's
  /// production day. Offer to edit that record instead of silently
  /// creating a second one; "Cancel" backs out of the form entirely since
  /// there's nothing new to fill in for today.
  Future<void> _showDuplicateGuardDialog(
      BuildContext context, int day, HealthLogEntry existing) async {
    final lang = ref.read(appLanguageProvider);
    final editInstead = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(tr(lang, 'alreadyRecordedTitle')),
        content: Text('${tr(lang, 'alreadyRecordedBody')} $day.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr(lang, 'cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr(lang, 'editTodaysAssessment'))),
        ],
      ),
    );
    if (!context.mounted) return;
    if (editInstead == true) {
      context.pushReplacement('${AppRoutes.health}/new', extra: existing);
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Round 3 item 4 — offers to resume an in-progress observation left
  /// over from an unexpected app close. "Discard" clears it so it never
  /// resurfaces; "Restore" repopulates the form fields (including the two
  /// TextEditingControllers, which don't watch Riverpod state directly).
  Future<void> _offerDraftRestore(BuildContext context,
      HealthFormController controller, HealthDraft draft) async {
    final lang = ref.read(appLanguageProvider);
    final restore = await showCustomConfirmDialog(
      context,
      title: tr(lang, 'unfinishedAssessmentTitle'),
      message: tr(lang, 'unfinishedAssessmentBody'),
      confirmLabel: tr(lang, 'restore'),
      cancelLabel: tr(lang, 'discard'),
    );
    if (!context.mounted) return;
    if (restore) {
      controller.applyDraft(draft);
      _notesCtrl.text = draft.notes;
      _assessedByCtrl.text = draft.assessedBy;
    } else {
      controller.discardDraft();
    }
  }

  /// Fires the Critical Alert the instant a named Emergency symptom is
  /// ticked — live, mid-form — rather than waiting for Save. Only ever
  /// shows once per form session; the post-save check (in the ref.listen
  /// above) skips re-showing it if this already fired.
  void _maybeShowImmediateEmergencyAlert(String uid) {
    if (_emergencyAlertShown) return;
    _emergencyAlertShown = true;
    _showCriticalAlert(context, uid);
  }

  Future<void> _showCriticalAlert(BuildContext context, String uid) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CriticalAlertSheet(uid: uid),
    );
  }
}

class _CriticalAlertSheet extends ConsumerWidget {
  const _CriticalAlertSheet({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: DashboardPalette.card,
            borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🚨', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(lang, 'criticalHealthAlert'),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: kHealthStatusColor[HealthStatus.critical]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tr(lang, 'criticalAlertBody'),
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kHealthStatusColor[HealthStatus.critical],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Text('📞', style: TextStyle(fontSize: 16)),
                label: Text(tr(lang, 'callVeterinarian')),
                onPressed: () async {
                  final contact =
                      await ref.read(vetContactProvider(uid).future);
                  if (!context.mounted) return;
                  if (contact == null || !contact.isSaved) {
                    Navigator.of(context).pop();
                    if (context.mounted) context.push(AppRoutes.vetContacts);
                    return;
                  }
                  Navigator.of(context).pop();
                  if (context.mounted) {
                    await _confirmAndCallVeterinarian(context, contact, lang);
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Text('📋', style: TextStyle(fontSize: 16)),
                label: Text(tr(lang, 'viewContactList')),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.vetContacts);
                },
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: Text(tr(lang, 'close')),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Health Monitor redesign — shows exactly which real pig this check is
/// for: the pig's own real photo (never a stand-in), real name, and real
/// Pig ID/breed. This is deliberately the pig's photo, not the farmer's —
/// unlike Settings, Health Monitor always identifies the animal being
/// assessed.
class _PigContextCard extends StatelessWidget {
  const _PigContextCard({required this.pig});
  final Pig pig;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DashboardPalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DashboardPalette.primaryGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48,
              height: 48,
              child: pig.photoLocalPath != null
                  ? Image.file(File(pig.photoLocalPath!),
                      fit: BoxFit.cover, cacheWidth: 96, cacheHeight: 96)
                  : Container(
                      color: DashboardPalette.primaryGreen.withValues(alpha: 0.1),
                      alignment: Alignment.center,
                      child: const Text('🐷', style: TextStyle(fontSize: 22)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pig.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${pig.id} · ${pig.breed}',
                    style: const TextStyle(
                        fontSize: 12, color: DashboardPalette.textGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirms before dialing — a mis-tap on "Call Veterinarian" shouldn't
/// place a real phone call straight away. Shows the vet's name/number and
/// requires an explicit "Call Now" before launching the dialer.
Future<void> _confirmAndCallVeterinarian(
    BuildContext context, VetContact contact, AppLanguage lang) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('🚨 ${tr(lang, 'criticalHealthAlert')}'),
      content: Text(
          '${tr(lang, 'callConfirmPrefix')} ${contact.name}?\n${contact.phone}'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr(lang, 'cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: kHealthStatusColor[HealthStatus.critical]),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr(lang, 'callNow')),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await launchUrl(Uri(scheme: 'tel', path: contact.phone));
  }
}

/// "Health Summary" — every current selection, the Overall Status (with a
/// severity bar and Reason bullets explaining how it was reached), the
/// Severity Counts breakdown, and the Recommendation, all in one card
/// right before Save so the farmer can double-check their entries.
class _HealthSummaryCard extends StatelessWidget {
  const _HealthSummaryCard(
      {required this.state, required this.assessment, required this.lang});
  final HealthFormState state;
  final HealthAssessment assessment;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final status = assessment.status;
    final meta = kHealthStatusMeta[status]!;
    final color = kHealthStatusColor[status]!;
    final rec = computeStatusRecommendation(status);
    final digestiveTip =
        computeDigestiveTip(appetite: state.appetite, waste: state.waste);
    final behaviorLabel = healthOptionLabel(
        lang,
        'behavior',
        state.behavior,
        findHealthOption(kBehaviorOptions, state.behavior)?.label ??
            state.behavior);
    final appetiteLabel = healthOptionLabel(
        lang,
        'appetite',
        state.appetite,
        findHealthOption(kAppetiteOptions, state.appetite)?.label ??
            state.appetite);
    final wasteLabel = healthOptionLabel(lang, 'waste', state.waste,
        findHealthOption(kWasteOptions, state.waste)?.label ?? state.waste);
    final physicalLabels = state.physical
        .map((k) => healthOptionLabel(lang, 'physical', k,
            findHealthOption(kPhysicalOptions, k)?.label ?? k))
        .toList();

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'healthSummary'),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          _SummaryRow(
              label: tr(lang, 'behaviorLabel'), values: [behaviorLabel]),
          _SummaryRow(
              label: tr(lang, 'appetiteLabel'), values: [appetiteLabel]),
          _SummaryRow(
              label: tr(lang, 'physicalLabel'),
              values: physicalLabels.isEmpty
                  ? [tr(lang, 'noneSelected')]
                  : physicalLabels),
          _SummaryRow(label: tr(lang, 'wasteLabel'), values: [wasteLabel]),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1)),
          Text(tr(lang, 'overallStatus'),
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: DashboardPalette.textGray)),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child)),
            child: Row(
              key: ValueKey(status),
              children: [
                Text('${meta.emoji} ${healthStatusLabel(lang, status)}',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: tr(lang, 'overallStatus'),
            value: '${meta.emoji} ${healthStatusLabel(lang, status)}',
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                  begin: 0,
                  end: (status.index + 1) / HealthStatus.values.length),
              duration: const Duration(milliseconds: 400),
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: DashboardPalette.background,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(tr(lang, 'severityCounts'),
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: DashboardPalette.textGray)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _CountChip(
                      label: tr(lang, 'healthyChip'),
                      count: assessment.healthyCount,
                      color: kHealthStatusColor[HealthStatus.healthy]!)),
              const SizedBox(width: 6),
              Expanded(
                  child: _CountChip(
                      label: tr(lang, 'monitoringChip'),
                      count: assessment.monitorCount,
                      color: kHealthStatusColor[HealthStatus.monitor]!)),
              const SizedBox(width: 6),
              Expanded(
                  child: _CountChip(
                      label: tr(lang, 'atRiskChip'),
                      count: assessment.riskCount,
                      color: kHealthStatusColor[HealthStatus.risk]!)),
              const SizedBox(width: 6),
              Expanded(
                  child: _CountChip(
                      label: tr(lang, 'criticalChip'),
                      count: assessment.criticalCount,
                      color: kHealthStatusColor[HealthStatus.critical]!)),
            ],
          ),
          const SizedBox(height: 14),
          Text(tr(lang, 'reasonLabel'),
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: DashboardPalette.textGray)),
          const SizedBox(height: 6),
          ...assessment.reasons.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $r', style: const TextStyle(fontSize: 12.5)),
              )),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1)),
          Text(tr(lang, 'recommendationLabel'),
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: DashboardPalette.textGray)),
          const SizedBox(height: 6),
          _RecommendationCard(rec: rec, color: color),
          if (digestiveTip != null) ...[
            const SizedBox(height: 10),
            _RecommendationCard(
                rec: digestiveTip, color: DashboardPalette.accentOrange),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.values});
  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DashboardPalette.textGray)),
          const SizedBox(height: 2),
          ...values.map((v) => Text('✓ $v',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(
      {required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text('$count',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 9.5, color: DashboardPalette.textGray),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.rec, required this.color});
  final HealthRecommendation rec;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rec.title,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13.5, color: color)),
          const SizedBox(height: 6),
          ...rec.body.map((b) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $b', style: const TextStyle(fontSize: 12.5)))),
        ],
      ),
    );
  }
}

class _SingleSelectGroup extends StatelessWidget {
  const _SingleSelectGroup({
    required this.icon,
    required this.title,
    required this.selectOneLabel,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.lang,
    required this.category,
  });
  final String icon;
  final String title;
  final String selectOneLabel;
  final List<HealthOption> options;
  final String selected;
  final void Function(String) onSelect;
  final AppLanguage lang;

  /// One of 'behavior' / 'appetite' / 'waste' — selects which Filipino
  /// lookup table healthOptionLabel()/healthOptionSubtitle() use, since
  /// the same option `key` (e.g. 'normal') means something different in
  /// each category.
  final String category;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$icon $title',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Text(selectOneLabel,
                  style: const TextStyle(
                      fontSize: 10.5,
                      color: DashboardPalette.textGray,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          _OptionRows(
            options: options,
            isSelected: (o) => o.key == selected,
            onTap: (o) => onSelect(o.key),
            showCheckBadge: false,
            lang: lang,
            category: category,
          ),
        ],
      ),
    );
  }
}

class _PhysicalMultiSelectGroup extends StatelessWidget {
  const _PhysicalMultiSelectGroup(
      {required this.lang, required this.selected, required this.onToggle});
  final AppLanguage lang;
  final Set<String> selected;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr(lang, 'physicalCondition'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Text(tr(lang, 'multipleSelect'),
                  style: const TextStyle(
                      fontSize: 10.5,
                      color: DashboardPalette.textGray,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          _PhysicalSection(
              label: tr(lang, 'healthyIndicators'),
              options: kPhysicalHealthyGroup,
              selected: selected,
              onToggle: onToggle,
              lang: lang),
          _PhysicalSection(
              label: tr(lang, 'needsMonitoring'),
              options: kPhysicalMonitoringGroup,
              selected: selected,
              onToggle: onToggle,
              lang: lang),
          _PhysicalSection(
              label: tr(lang, 'atRiskSection'),
              options: kPhysicalAtRiskGroup,
              selected: selected,
              onToggle: onToggle,
              lang: lang),
          _PhysicalSection(
              label: tr(lang, 'criticalSection'),
              options: kPhysicalCriticalGroup,
              selected: selected,
              onToggle: onToggle,
              lang: lang,
              isLast: true),
        ],
      ),
    );
  }
}

class _PhysicalSection extends StatelessWidget {
  const _PhysicalSection({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.lang,
    this.isLast = false,
  });
  final String label;
  final List<HealthOption> options;
  final Set<String> selected;
  final void Function(String) onToggle;
  final AppLanguage lang;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 14, bottom: isLast ? 0 : 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: DashboardPalette.textGray)),
          const SizedBox(height: 8),
          _OptionRows(
            options: options,
            isSelected: (o) => selected.contains(o.key),
            onTap: (o) => onToggle(o.key),
            showCheckBadge: true,
            lang: lang,
            category: 'physical',
          ),
        ],
      ),
    );
  }
}

/// Lays [options] out two-per-row, with a trailing odd option taking the
/// full row width — matches the reference design's card grid exactly.
class _OptionRows extends StatelessWidget {
  const _OptionRows({
    required this.options,
    required this.isSelected,
    required this.onTap,
    required this.showCheckBadge,
    required this.lang,
    required this.category,
  });
  final List<HealthOption> options;
  final bool Function(HealthOption) isSelected;
  final void Function(HealthOption) onTap;
  final bool showCheckBadge;
  final AppLanguage lang;
  final String category;

  @override
  Widget build(BuildContext context) {
    // This loop is the ONLY place in the Health Monitor screen that calls
    // healthOptionLabel()/healthOptionSubtitle() while constructing the
    // actual card widgets. Kept wrapped in try/catch per-pair as
    // permanent defensive hardening: if either of those ever throws for
    // a future option, the exception renders as a visible red diagnostic
    // card naming the option key and the exception text, instead of the
    // pair silently vanishing the way the real bug (see IntrinsicHeight
    // fix below) made it look like the app was failing to load data.
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 2) {
      final first = options[i];
      final second = i + 1 < options.length ? options[i + 1] : null;
      try {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            // ROOT CAUSE FIX: this Row sits inside a plain Column, itself
            // inside the screen's outer ListView — which gives every
            // non-scrolling descendant an UNBOUNDED (infinite) height.
            // `CrossAxisAlignment.stretch` asks each Expanded child to
            // stretch to fill the Row's own cross-axis (height) extent;
            // when that extent is unbounded, Flutter's debug-mode assert
            // ("BoxConstraints forces an infinite height") would normally
            // catch this immediately — but asserts are stripped from
            // --release builds, so instead of throwing loudly, the Row
            // silently resolves each card's height to a degenerate/
            // infinite value. The emoji/label Text inside each card still
            // lays out and paints at its own natural size (text layout
            // doesn't depend on the parent's cross-axis extent the same
            // way), but the surrounding AnimatedContainer's colored,
            // rounded-rect BACKGROUND — which does depend on having a
            // real, finite size — fails to paint at all, and everything
            // in the ListView after the first affected row never gets a
            // valid layout pass either. This exact signature (icon/label
            // text floating with no visible card, followed by a fully
            // blank screen below) was reproduced identically by a throw-
            // away diagnostic screen built from hardcoded strings with
            // zero HealthOption/Riverpod/repository/translation
            // dependency — confirming this was a layout bug, not a data
            // bug. `IntrinsicHeight` fixes it the standard way: it forces
            // this Row to first measure its children's own natural
            // (finite) heights and use the tallest as its own height,
            // before CrossAxisAlignment.stretch ever runs — so "stretch"
            // still makes the two cards match each other's height, it
            // just no longer has to resolve against infinity to do it.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _OptionCard(
                      option: first,
                      label: healthOptionLabel(
                          lang, category, first.key, first.label),
                      subtitle: healthOptionSubtitle(
                          lang, category, first.key, first.subtitle),
                      selected: isSelected(first),
                      showCheckBadge: showCheckBadge,
                      onTap: () => onTap(first),
                    ),
                  ),
                  if (second != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OptionCard(
                        option: second,
                        label: healthOptionLabel(
                            lang, category, second.key, second.label),
                        subtitle: healthOptionSubtitle(
                            lang, category, second.key, second.subtitle),
                        selected: isSelected(second),
                        showCheckBadge: showCheckBadge,
                        onTap: () => onTap(second),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      } catch (e, st) {
        debugPrint('[HealthMonitor][Stage4-ERROR] pair "${first.key}"'
            '${second != null ? '/"${second.key}"' : ''} in category "$category" threw: $e\n$st');
        rows.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200)),
            child: Text(
              'Health Monitor render error\n'
              'category: $category, option(s): ${first.key}${second != null ? ', ${second.key}' : ''}\n'
              '$e',
              style: TextStyle(color: Colors.red.shade900, fontSize: 11),
            ),
          ),
        );
      }
    }

    return Column(children: rows);
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard(
      {required this.option,
      required this.label,
      required this.subtitle,
      required this.selected,
      required this.showCheckBadge,
      required this.onTap});
  final HealthOption option;

  /// Display label — already resolved to the current [AppLanguage] by
  /// _OptionRows via healthOptionLabel(); option.label itself stays
  /// English/canonical (see settings_strings.dart's health-option
  /// translation block for why).
  final String label;
  final String subtitle;
  final bool selected;
  final bool showCheckBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Selection state is shown visually via color/border/check-badge —
    // Semantics.selected makes screen readers announce it too, so status
    // is never color-only for a blind or low-vision farmer either.
    return Semantics(
      button: true,
      selected: selected,
      label: subtitle.isNotEmpty ? '$label, $subtitle' : label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: BoxDecoration(
              color: selected
                  ? DashboardPalette.lightGreen
                  : DashboardPalette.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected
                      ? DashboardPalette.primaryGreen
                      : const Color(0xFFE6E6E6),
                  width: selected ? 1.6 : 1),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(option.icon, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 7),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected
                            ? DashboardPalette.darkGreen
                            : Colors.black87,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: selected
                                ? DashboardPalette.primaryGreen
                                : DashboardPalette.textGray),
                      ),
                    ],
                  ],
                ),
                if (showCheckBadge)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      scale: selected ? 1 : 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            color: DashboardPalette.primaryGreen,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.check,
                            size: 13, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
