import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/app_language.dart';
import '../../domain/settings_strings.dart';
import '../providers/settings_providers.dart';
import '../theme/settings_palette.dart';
import '../widgets/settings_widgets.dart';

/// Profile & Farm — the farmer's own account details, restyled from the
/// previous plain-TextField list into the ASF card design. Every field,
/// controller, save/validation path, and the avatar upload flow are the
/// exact same ones the earlier version used (see ProfileFormController in
/// settings_providers.dart) — this file only changes presentation and adds
/// two purely-informational, real-data rows: "Member Since" (from the
/// profile's own createdAt, newly surfaced — see AuthRepository's doc) and
/// an Account Security card (static, honest copy — no invented claims).
///
/// "Units & Preferences" (Weight Unit/Temperature/Date/Time format) from
/// the original spec is intentionally omitted: nothing in this app is
/// actually configurable in those units today (weight is always kg, dates
/// always follow the app's own formatting), so adding switches for them
/// would be non-functional UI — see the redesign plan discussion.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _municipalityCtrl;
  late final TextEditingController _provinceCtrl;
  late final TextEditingController _farmNameCtrl;
  bool _controllersSeeded = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _municipalityCtrl = TextEditingController();
    _provinceCtrl = TextEditingController();
    _farmNameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _municipalityCtrl.dispose();
    _provinceCtrl.dispose();
    _farmNameCtrl.dispose();
    super.dispose();
  }

  String _formatMemberSince(Object? createdAt, AppLanguage lang) {
    DateTime? date;
    if (createdAt is int) {
      date = DateTime.fromMillisecondsSinceEpoch(createdAt);
    } else if (createdAt is String) {
      date = DateTime.tryParse(createdAt);
    }
    if (date == null) return '—';
    final months = monthAbbrev(lang);
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final state = ref.watch(profileFormControllerProvider(widget.uid));
    final controller =
        ref.read(profileFormControllerProvider(widget.uid).notifier);

    // Seed the controllers from loaded state exactly once (the moment
    // isLoading flips false) — never on every rebuild, or the cursor/typed
    // text would keep getting stomped by the provider's own copy.
    if (!_controllersSeeded && !state.isLoading) {
      _nameCtrl.text = state.fullName;
      _emailCtrl.text = state.email;
      _phoneCtrl.text = state.phoneNumber;
      _municipalityCtrl.text = state.municipality;
      _provinceCtrl.text = state.province;
      _farmNameCtrl.text = state.farmName;
      _controllersSeeded = true;
    }

    ref.listen(profileFormControllerProvider(widget.uid), (previous, next) {
      if (next.saved && previous?.saved != true) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr(lang, 'profileSaved'))));
      }
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return Scaffold(
      backgroundColor: SettingsPalette.background,
      appBar: AppBar(
        backgroundColor: SettingsPalette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(tr(lang, 'profileFarmLabel'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: SettingsPalette.darkText)),
        iconTheme: const IconThemeData(color: SettingsPalette.darkText),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: settingsAnimatedChildren([
                _ProfileHeaderCard(
                    state: state, controller: controller, lang: lang),
                const SizedBox(height: 18),
                Text(tr(lang, 'personalInformationTitle'),
                    style: settingsSectionTitleStyle),
                const SizedBox(height: 10),
                Container(
                  decoration: settingsCardDecoration(radius: 18),
                  padding: settingsCardPadding,
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration:
                            InputDecoration(labelText: tr(lang, 'fullName')),
                        onChanged: controller.updateFullName,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _emailCtrl,
                        decoration:
                            InputDecoration(labelText: tr(lang, 'email')),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: controller.updateEmail,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _phoneCtrl,
                        decoration: InputDecoration(
                            labelText: tr(lang, 'phoneNumber'),
                            hintText: '09XX XXX XXXX'),
                        keyboardType: TextInputType.phone,
                        onChanged: controller.updatePhoneNumber,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: state.farmerType,
                        decoration:
                            InputDecoration(labelText: tr(lang, 'roleLabel')),
                        items: kFarmerTypeOptions
                            .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(farmerTypeLabel(lang, t))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) controller.updateFarmerType(v);
                        },
                      ),
                      const SizedBox(height: 14),
                      _ReadOnlyRow(
                        label: tr(lang, 'memberSinceLabel'),
                        value: _formatMemberSince(state.createdAt, lang),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(tr(lang, 'farmInformationTitle'),
                    style: settingsSectionTitleStyle),
                const SizedBox(height: 10),
                Container(
                  decoration: settingsCardDecoration(radius: 18),
                  padding: settingsCardPadding,
                  child: Column(
                    children: [
                      TextField(
                        controller: _farmNameCtrl,
                        decoration:
                            InputDecoration(labelText: tr(lang, 'farmName')),
                        onChanged: controller.updateFarmName,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _municipalityCtrl,
                        decoration: InputDecoration(
                            labelText:
                                '${tr(lang, 'farmLocationLabel')} — ${tr(lang, 'municipality')}'),
                        onChanged: controller.updateMunicipality,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _provinceCtrl,
                        decoration:
                            InputDecoration(labelText: tr(lang, 'province')),
                        onChanged: controller.updateProvince,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _AccountSecurityCard(lang: lang),
                const SizedBox(height: 22),
                Semantics(
                  button: true,
                  label: state.isSaving ? tr(lang, 'saving') : tr(lang, 'save'),
                  liveRegion: state.isSaving,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: SettingsPalette.primaryGreen,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: state.isSaving ? null : controller.save,
                    child: state.isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(tr(lang, 'save')),
                  ),
                ),
                const SizedBox(height: 12),
                _ProfileLogoutButton(lang: lang),
              ]),
            ),
    );
  }
}

/// Header — real farmer photo with camera badge (unchanged upload flow,
/// see _ProfileAvatar below), name, email, phone, and an Active Account
/// status chip.
class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard(
      {required this.state, required this.controller, required this.lang});
  final ProfileFormState state;
  final ProfileFormController controller;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: settingsCardDecoration(),
      padding: settingsCardPadding,
      child: Column(
        children: [
          _ProfileAvatar(state: state, controller: controller, lang: lang),
          const SizedBox(height: 14),
          Text(state.fullName.isEmpty ? '—' : state.fullName,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: SettingsPalette.darkText)),
          const SizedBox(height: 4),
          if (state.email.isNotEmpty)
            Text(state.email,
                style: const TextStyle(
                    fontSize: 13, color: SettingsPalette.grayText)),
          if (state.phoneNumber.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(state.phoneNumber,
                  style: const TextStyle(
                      fontSize: 13, color: SettingsPalette.grayText)),
            ),
          const SizedBox(height: 10),
          SettingsStatusChip(
            label: state.verified
                ? tr(lang, 'activeAccountStatus')
                : tr(lang, 'statusInProgress'),
            foreground: state.verified
                ? SettingsPalette.primaryGreen
                : SettingsPalette.orange,
            background: state.verified
                ? SettingsPalette.lightGreen
                : SettingsPalette.lightOrange,
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: SettingsPalette.grayText)),
        Text(value,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: SettingsPalette.darkText)),
      ],
    );
  }
}

class _AccountSecurityCard extends StatelessWidget {
  const _AccountSecurityCard({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: settingsCardDecoration(),
      padding: settingsCardPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: SettingsPalette.lightGreen, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.shield_outlined,
                color: SettingsPalette.primaryGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(lang, 'accountSecureTitle'),
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: SettingsPalette.darkText)),
                const SizedBox(height: 3),
                Text(tr(lang, 'accountSecureBody'),
                    style: const TextStyle(
                        fontSize: 12.5, color: SettingsPalette.grayText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLogoutButton extends ConsumerWidget {
  const _ProfileLogoutButton({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: tr(lang, 'logout'),
      child: Material(
        color: SettingsPalette.lightRed,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final confirmed = await showCustomConfirmDialog(
              context,
              title: tr(lang, 'logoutConfirmTitle'),
              message: tr(lang, 'logoutConfirmBody'),
              confirmLabel: tr(lang, 'logout'),
              cancelLabel: tr(lang, 'cancel'),
            );
            if (confirmed) {
              await ref.read(authFlowControllerProvider.notifier).logout();
            }
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout, color: SettingsPalette.red, size: 19),
                const SizedBox(width: 8),
                Text(tr(lang, 'logout'),
                    style: const TextStyle(
                        color: SettingsPalette.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable circular avatar — shows the current photo (local file or
/// remote URL, whichever updateProfileImage() last resolved to), initials
/// as a placeholder when there's none yet, and a small camera badge that
/// opens Take Photo/Choose from Gallery. A spinner overlay replaces the
/// badge while an upload is in flight so a slow/offline upload can't be
/// mistaken for nothing having happened. Unchanged from the pre-redesign
/// version besides the badge color now using SettingsPalette.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar(
      {required this.state, required this.controller, required this.lang});
  final ProfileFormState state;
  final ProfileFormController controller;
  final AppLanguage lang;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
      if (picked == null) return;
      await controller.updateAvatar(picked.path);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(lang, 'couldNotLoadImage'))),
        );
      }
    }
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr(lang, 'updateProfilePhotoTitle'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(tr(lang, 'maxSizeCompressed'),
                  style: const TextStyle(
                      fontSize: 11.5, color: SettingsPalette.grayText)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pick(context, ImageSource.camera);
                      },
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(tr(lang, 'takePhoto')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pick(context, ImageSource.gallery);
                      },
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(tr(lang, 'chooseGallery')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = state.profileImage;
    final initial = state.fullName.trim().isNotEmpty
        ? state.fullName.trim()[0].toUpperCase()
        : '?';
    ImageProvider? provider;
    if (image != null && image.isNotEmpty) {
      provider = image.startsWith('http')
          ? NetworkImage(image)
          : FileImage(File(image)) as ImageProvider;
    }

    return Semantics(
      button: true,
      label: tr(lang, 'updateProfilePhotoTooltip'),
      child: GestureDetector(
        onTap: state.isUploadingAvatar ? null : () => _showPicker(context),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: SettingsPalette.lightGreen,
              backgroundImage: provider,
              child: provider == null
                  ? Text(initial,
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: SettingsPalette.primaryGreen))
                  : null,
            ),
            if (state.isUploadingAvatar)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle),
                  child: const Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: SettingsPalette.primaryGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
