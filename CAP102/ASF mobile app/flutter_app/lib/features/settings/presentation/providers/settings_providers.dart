// ══════════════════════════════════════════════════════════════════════
// Riverpod state for the Settings feature. Theme + Language are APP-WIDE,
// in-memory switches (appThemeModeProvider / appLanguageProvider) that
// app.dart watches directly — they're plain StateProviders rather than
// uid-keyed families because MaterialApp.router needs a single themeMode
// value regardless of which uid is signed in. settingsBootstrapProvider
// loads the signed-in user's saved values into those two switches once
// per session, exactly like notificationBootstrapProvider does for
// reminders (see notification_providers.dart) — watched once from
// _DashboardRoute in app_router.dart.
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/phone_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/data/notification_repository.dart';
import '../../data/settings_repository.dart';
import '../../domain/app_language.dart';

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SettingsRepository());

final appThemeModeProvider =
    StateProvider<ThemeMode>((ref) => ThemeMode.system);
final appLanguageProvider = StateProvider<AppLanguage>((ref) => AppLanguage.en);

final settingsBootstrapProvider =
    FutureProvider.autoDispose.family<void, String>((ref, uid) async {
  final repo = ref.watch(settingsRepositoryProvider);
  final results =
      await Future.wait([repo.getThemeMode(uid), repo.getLanguage(uid)]);
  ref.read(appThemeModeProvider.notifier).state = results[0] as ThemeMode;
  ref.read(appLanguageProvider.notifier).state = results[1] as AppLanguage;
});

/// Theme/Language pickers act immediately (no draft/Save step — these are
/// single-value toggles, not a multi-field form like Notification prefs),
/// so the Settings menu screen calls these directly rather than going
/// through a controller class.
Future<void> applyThemeMode(WidgetRef ref, String uid, ThemeMode mode) async {
  ref.read(appThemeModeProvider.notifier).state = mode;
  await ref.read(settingsRepositoryProvider).setThemeMode(uid, mode);
}

Future<void> applyLanguage(WidgetRef ref, String uid, AppLanguage lang) async {
  ref.read(appLanguageProvider.notifier).state = lang;
  await ref.read(settingsRepositoryProvider).setLanguage(uid, lang);
  // Bug B1 fix: re-schedules every already-set OS reminder with the new
  // language's title/body immediately, rather than leaving previously
  // English-scheduled notifications stuck in English until the next
  // unrelated toggle/reboot happens to reschedule them. Best-effort — a
  // notification-scheduling hiccup here must never block the language
  // switch itself from applying.
  try {
    await NotificationRepository().rescheduleAll(uid);
  } catch (_) {}
}

// ── Profile editing (draft/Save pattern, same shape as Notification
// Settings — nothing persists until the user taps Save). ──

class ProfileFormState {
  const ProfileFormState({
    required this.fullName,
    required this.municipality,
    required this.province,
    required this.farmName,
    required this.farmerType,
    required this.email,
    required this.phoneNumber,
    this.profileImage,
    this.isSaving = false,
    this.isLoading = true,
    this.isUploadingAvatar = false,
    this.saved = false,
    this.errorMessage,
    this.createdAt,
    this.verified = true,
  });

  final String fullName;
  final String municipality;
  final String province;
  final String farmName;
  final String farmerType;
  final String email;
  final String phoneNumber;
  // Local file path or remote URL — CircleAvatar/Image.file/Image.network
  // pick the right ImageProvider based on which it is (see _ProfileAvatar).
  final String? profileImage;
  final bool isSaving;
  final bool isLoading;
  final bool isUploadingAvatar;
  final bool saved;
  final String? errorMessage;
  // Settings redesign's "Member Since"/Account Security display — read-only,
  // never edited from this form. See AuthRepository._profileFromSupabaseRow/
  // _profileFromSqliteRow's doc for why this is either an epoch-ms int or an
  // ISO-8601 string depending on which cache the profile loaded from.
  final Object? createdAt;
  final bool verified;

  ProfileFormState copyWith({
    String? fullName,
    String? municipality,
    String? province,
    String? farmName,
    String? farmerType,
    String? email,
    String? phoneNumber,
    String? profileImage,
    bool? isSaving,
    bool? isLoading,
    bool? isUploadingAvatar,
    bool? saved,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileFormState(
      fullName: fullName ?? this.fullName,
      municipality: municipality ?? this.municipality,
      province: province ?? this.province,
      farmName: farmName ?? this.farmName,
      farmerType: farmerType ?? this.farmerType,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImage: profileImage ?? this.profileImage,
      isSaving: isSaving ?? this.isSaving,
      isLoading: isLoading ?? this.isLoading,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      saved: saved ?? false,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt,
      verified: verified,
    );
  }

  static const empty = ProfileFormState(
    fullName: '',
    municipality: '',
    province: '',
    farmName: '',
    farmerType: 'Backyard Raiser',
    email: '',
    phoneNumber: '',
  );
}

class ProfileFormController extends StateNotifier<ProfileFormState> {
  ProfileFormController(this._repo, this._uid, this._ref)
      : super(ProfileFormState.empty) {
    _load();
  }

  final SettingsRepository _repo;
  final String _uid;
  final Ref _ref;

  Future<void> _load() async {
    try {
      final profile = await _repo.getProfile(_uid);
      state = ProfileFormState(
        fullName: (profile?['fullName'] as String?) ?? '',
        municipality: (profile?['municipality'] as String?) ?? '',
        province: (profile?['province'] as String?) ?? '',
        farmName: (profile?['farmName'] as String?) ?? '',
        farmerType: (profile?['farmerType'] as String?) ?? 'Backyard Raiser',
        email: (profile?['email'] as String?) ?? '',
        phoneNumber: (profile?['phoneNumber'] as String?) ?? '',
        profileImage: profile?['profileImage'] as String?,
        isLoading: false,
        createdAt: profile?['createdAt'],
        verified: (profile?['verified'] as bool?) ?? true,
      );
    } catch (_) {
      state = state.copyWith(
          isLoading: false,
          errorMessage: 'Could not load your profile. Please try again.');
    }
  }

  void updateFullName(String v) =>
      state = state.copyWith(fullName: v, clearError: true);
  void updateMunicipality(String v) =>
      state = state.copyWith(municipality: v, clearError: true);
  void updateProvince(String v) =>
      state = state.copyWith(province: v, clearError: true);
  void updateFarmName(String v) =>
      state = state.copyWith(farmName: v, clearError: true);
  void updateFarmerType(String v) =>
      state = state.copyWith(farmerType: v, clearError: true);
  // C2: email/phone are now editable profile-record fields (see the doc
  // comment on AuthRepository.updateProfileFields for the important
  // distinction between this app-level record and the Firebase Auth
  // identity itself).
  void updatePhoneNumber(String v) =>
      state = state.copyWith(phoneNumber: v, clearError: true);
  void updateEmail(String v) =>
      state = state.copyWith(email: v, clearError: true);

  /// Picks up an already-captured/selected image path and uploads it as
  /// the new avatar. The image-picker call itself lives in the screen (same
  /// split as pig photo capture) — this just owns the loading state +
  /// persistence, so a rebuild mid-upload doesn't lose progress.
  Future<void> updateAvatar(String localImagePath) async {
    state = state.copyWith(isUploadingAvatar: true, clearError: true);
    try {
      final path = await _repo.updateProfileImage(_uid, localImagePath);
      if (path == null) {
        state = state.copyWith(
            isUploadingAvatar: false,
            errorMessage: 'Image exceeds 3 MB. Please choose another image.');
        return;
      }
      state = state.copyWith(isUploadingAvatar: false, profileImage: path);
      // Bug A1 fix: without this, every screen that reads the profile via
      // userProfileProvider (Dashboard greeting, app bar avatar, Drawer
      // footer, Pig/Growth/Expenses screens) keeps showing whatever it
      // fetched on its first build — this FutureProvider.autoDispose.family
      // never refetches on its own just because SQLite/Supabase changed
      // underneath it. Invalidating forces every current watcher to re-run
      // getUserProfile() and pick up the new avatar immediately.
      _ref.invalidate(userProfileProvider(_uid));
    } catch (_) {
      state = state.copyWith(
          isUploadingAvatar: false,
          errorMessage: 'Could not update your photo. Please try again.');
    }
  }

  Future<void> save() async {
    if (state.fullName.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Full name is required.');
      return;
    }
    final trimmedEmail = state.email.trim();
    if (trimmedEmail.isNotEmpty && !trimmedEmail.contains('@')) {
      state =
          state.copyWith(errorMessage: 'Please enter a valid email address.');
      return;
    }
    final trimmedPhone = state.phoneNumber.trim();
    if (trimmedPhone.isNotEmpty &&
        normalizePhilippineMobile(trimmedPhone) == null) {
      state = state.copyWith(
          errorMessage:
              'Please enter a valid Philippine mobile number (e.g. 09171234567).');
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repo.updateProfile(
        _uid,
        fullName: state.fullName.trim(),
        municipality: state.municipality.trim(),
        province: state.province.trim(),
        farmName: state.farmName.trim(),
        farmerType: state.farmerType,
        email: trimmedEmail,
        phoneNumber: trimmedPhone.isEmpty
            ? trimmedPhone
            : (normalizePhilippineMobile(trimmedPhone) ?? trimmedPhone),
      );
      state = state.copyWith(isSaving: false, saved: true);
      // Bug A1 fix: see the matching comment in updateAvatar() above — same
      // stale-provider cause for "profile info lost after editing" (the
      // write always succeeded; nothing ever told the Dashboard/Drawer/App
      // Bar to look at it again).
      _ref.invalidate(userProfileProvider(_uid));
    } catch (_) {
      state = state.copyWith(
          isSaving: false,
          errorMessage: 'Could not save your profile. Please try again.');
    }
  }
}

final profileFormControllerProvider = StateNotifierProvider.autoDispose
    .family<ProfileFormController, ProfileFormState, String>((ref, uid) {
  return ProfileFormController(ref.watch(settingsRepositoryProvider), uid, ref);
});
