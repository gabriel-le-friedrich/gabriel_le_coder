import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/pig.dart';
import '../providers/pig_providers.dart';
import '../theme/pig_growth_palette.dart';

/// Add/Edit Pig — redesigned to match the Pig Growth module's visual
/// language (rounded sections, green Save button, large photo-upload
/// card). Every field still writes through the same PigFormController this
/// screen has always used; the only functional addition is Birth Date and
/// Start Date pickers — PigFormController already supported
/// updateBirthDate()/updateArrivalDate() and PigFormState already carried
/// both fields, they just had no input in the old form. "Target Market
/// Weight" and "Expected Weeks" from the reference mockup are deliberately
/// NOT included: the Pig model has no such fields today, and this pass is
/// UI-only — adding fake inputs with nowhere real to save would contradict
/// "do not use placeholder values."
class PigFormScreen extends ConsumerStatefulWidget {
  const PigFormScreen({super.key, this.editingPig});
  final Pig? editingPig;

  @override
  ConsumerState<PigFormScreen> createState() => _PigFormScreenState();
}

class _PigFormScreenState extends ConsumerState<PigFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _breedCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _penCtrl;
  late final TextEditingController _notesCtrl;
  final _nameFocus = FocusNode();
  final _breedFocus = FocusNode();
  final _weightFocus = FocusNode();
  final _penFocus = FocusNode();
  final _notesFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final pig = widget.editingPig;
    _nameCtrl = TextEditingController(text: pig?.name ?? '');
    _breedCtrl = TextEditingController(text: pig?.breed ?? '');
    _weightCtrl =
        TextEditingController(text: pig?.initialWeight.toString() ?? '');
    _penCtrl = TextEditingController(text: pig?.penNumber ?? '');
    _notesCtrl = TextEditingController(text: pig?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _weightCtrl.dispose();
    _penCtrl.dispose();
    _notesCtrl.dispose();
    _nameFocus.dispose();
    _breedFocus.dispose();
    _weightFocus.dispose();
    _penFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editingPig = widget.editingPig;
    final controller = ref.read(pigFormControllerProvider(editingPig).notifier);
    final state = ref.watch(pigFormControllerProvider(editingPig));
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final lang = ref.watch(appLanguageProvider);

    ref.listen(pigFormControllerProvider(editingPig), (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
      if (next.saved && previous?.saved != true) {
        ref.invalidate(pigListProvider(uid));
        ref.invalidate(allWeeklyImagesProvider(uid));
        if (context.mounted) context.pop();
      }
    });

    return Scaffold(
      backgroundColor: PigGrowthPalette.background,
      appBar: AppBar(
        backgroundColor: PigGrowthPalette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
            editingPig != null
                ? tr(lang, 'editPigTitle')
                : tr(lang, 'addPigTitle'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PhotoUploadCard(
                  photoLocalPath: state.photoLocalPath,
                  isCompressing: state.isCompressingPhoto,
                  onPick: (source) => controller.pickPhoto(source),
                  lang: lang,
                ),
                const SizedBox(height: 16),
                // Split into four clearly-labeled sections (Pig Information /
                // Schedule / Production / Photo, matching the feedback that a
                // single long card felt overwhelming) instead of one big
                // "PIG INFORMATION" card holding every field. Same fields,
                // same controllers/validators — only the grouping changed.
                _FormSection(
                  title: tr(lang, 'pigInformationSection'),
                  children: [
                    if (editingPig != null) ...[
                      _FieldLabel(tr(lang, 'pigIdLabel')),
                      _RoundedField(
                        child: TextFormField(
                          initialValue: editingPig.id,
                          readOnly: true,
                          decoration: const InputDecoration(
                              border: InputBorder.none, isDense: true),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _FieldLabel(tr(lang, 'pigNameLabel')),
                    _RoundedField(
                      child: TextFormField(
                        controller: _nameCtrl,
                        focusNode: _nameFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_breedFocus),
                        decoration: const InputDecoration(
                            border: InputBorder.none, isDense: true),
                        onChanged: controller.updateName,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? tr(lang, 'required')
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(tr(lang, 'breedLabel')),
                    _RoundedField(
                      child: TextFormField(
                        controller: _breedCtrl,
                        focusNode: _breedFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_weightFocus),
                        decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: tr(lang, 'breedHint')),
                        onChanged: controller.updateBreed,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(tr(lang, 'genderLabel')),
                    Row(
                      children: [
                        Expanded(
                            child: _GenderOption(
                                label: tr(lang, 'maleLabel'),
                                icon: Icons.male,
                                selected: state.gender == 'Male',
                                onTap: () => controller.updateGender('Male'))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _GenderOption(
                                label: tr(lang, 'femaleLabel'),
                                icon: Icons.female,
                                selected: state.gender == 'Female',
                                onTap: () =>
                                    controller.updateGender('Female'))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FormSection(
                  title: tr(lang, 'scheduleSection'),
                  children: [
                    _FieldLabel(tr(lang, 'arrivalDateLabel')),
                    _DatePickerField(
                      value: state.arrivalDate,
                      onPicked: controller.updateArrivalDate,
                      lang: lang,
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(tr(lang, 'birthDateLabel')),
                    _DatePickerField(
                      value: state.birthDate,
                      onPicked: controller.updateBirthDate,
                      lang: lang,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FormSection(
                  title: tr(lang, 'productionSection'),
                  children: [
                    _FieldLabel(tr(lang, 'initialWeightKgLabel')),
                    _RoundedField(
                      child: TextFormField(
                        controller: _weightCtrl,
                        focusNode: _weightFocus,
                        enabled: editingPig == null,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_penFocus),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: '20',
                          helperText: editingPig != null
                              ? tr(lang, 'editStartingWeightHelper')
                              : null,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (v) => controller
                            .updateStartingWeightForNewPig(double.tryParse(v)),
                        validator: (v) => editingPig == null &&
                                (double.tryParse(v ?? '') ?? -1) <= 0
                            ? tr(lang, 'enterValidWeight')
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(tr(lang, 'penNumberLabel')),
                    _RoundedField(
                      child: TextFormField(
                        controller: _penCtrl,
                        focusNode: _penFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_notesFocus),
                        decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: tr(lang, 'penNumberHint')),
                        onChanged: controller.updatePenNumber,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(tr(lang, 'notesOptional')),
                    _RoundedField(
                      child: TextFormField(
                        controller: _notesCtrl,
                        focusNode: _notesFocus,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: tr(lang, 'additionalRemarksHint')),
                        maxLines: 3,
                        onChanged: controller.updateNotes,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.pop(),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        child: Text(tr(lang, 'cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Semantics(
                        button: true,
                        label: state.isSaving
                            ? tr(lang, 'saving')
                            : (editingPig != null
                                ? tr(lang, 'saveChangesButton')
                                : tr(lang, 'savePigButton')),
                        liveRegion: state.isSaving,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: PigGrowthPalette.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: state.isSaving
                              ? null
                              : () {
                                  if (_formKey.currentState!.validate())
                                    controller.submit();
                                },
                          child: state.isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(
                                  editingPig != null
                                      ? tr(lang, 'saveChangesButton')
                                      : tr(lang, 'savePigButton'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled card grouping a handful of related fields — used to split the
/// Add/Edit Pig form into Pig Information / Schedule / Production sections
/// instead of one long list of fields in a single card.
class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: pigGrowthSectionTitleStyle),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: PigGrowthPalette.grayText,
              letterSpacing: 0.3)),
    );
  }
}

class _RoundedField extends StatelessWidget {
  const _RoundedField({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
          color: PigGrowthPalette.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PigGrowthPalette.border)),
      child: child,
    );
  }
}

class _GenderOption extends StatelessWidget {
  const _GenderOption(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? PigGrowthPalette.lightGreen
                : PigGrowthPalette.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected
                    ? PigGrowthPalette.primaryGreen
                    : PigGrowthPalette.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected
                      ? PigGrowthPalette.primaryGreen
                      : PigGrowthPalette.grayText),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? PigGrowthPalette.primaryGreen
                          : PigGrowthPalette.darkText)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField(
      {required this.value, required this.onPicked, required this.lang});
  final String value;
  final ValueChanged<String> onPicked;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(value);
    final displayValue = parsed == null
        ? tr(lang, 'mmddyyyyPlaceholder')
        : '${parsed.month.toString().padLeft(2, '0')}/${parsed.day.toString().padLeft(2, '0')}/${parsed.year}';
    return Semantics(
      button: true,
      label: displayValue,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: parsed ?? DateTime.now(),
            firstDate: DateTime(2015),
            lastDate: DateTime(2100),
          );
          if (picked != null)
            onPicked(picked.toIso8601String().split('T').first);
        },
        child: _RoundedField(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayValue,
                  style: TextStyle(
                      color: parsed == null
                          ? PigGrowthPalette.grayText
                          : PigGrowthPalette.darkText,
                      fontSize: 14.5),
                ),
              ),
              const Icon(Icons.calendar_today,
                  size: 16, color: PigGrowthPalette.grayText),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoUploadCard extends StatelessWidget {
  const _PhotoUploadCard(
      {required this.photoLocalPath,
      required this.onPick,
      required this.lang,
      this.isCompressing = false});
  final String? photoLocalPath;
  final ValueChanged<ImageSource> onPick;
  final AppLanguage lang;
  // While true, pickPhoto() is still compressing the just-picked image —
  // show a spinner over the thumbnail and disable both buttons so a second
  // tap can't fire mid-compression.
  final bool isCompressing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: pigGrowthCardDecoration(),
      padding: pigGrowthCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'photoUploadSection'),
              style: pigGrowthSectionTitleStyle),
          const SizedBox(height: 4),
          Text(
            tr(lang, 'maxSizeNotice'),
            style: const TextStyle(
                fontSize: 11.5, color: PigGrowthPalette.grayText),
          ),
          const SizedBox(height: 12),
          Center(
            child: Stack(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                      color: PigGrowthPalette.lightGreen,
                      borderRadius: BorderRadius.circular(20)),
                  clipBehavior: Clip.antiAlias,
                  child: photoLocalPath != null
                      ? Image.file(File(photoLocalPath!), fit: BoxFit.cover)
                      : const Center(
                          child: Icon(Icons.camera_alt_outlined,
                              size: 32, color: PigGrowthPalette.primaryGreen)),
                ),
                if (isCompressing)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Center(
                        child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      isCompressing ? null : () => onPick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(tr(lang, 'takePhoto')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PigGrowthPalette.primaryGreen,
                    side:
                        const BorderSide(color: PigGrowthPalette.primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      isCompressing ? null : () => onPick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(tr(lang, 'chooseFromGallery')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PigGrowthPalette.primaryGreen,
                    side:
                        const BorderSide(color: PigGrowthPalette.primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
