// ══════════════════════════════════════════════════════════════════════
// Riverpod providers + the AuthFlowController that backs the auth screens.
// This is the Flutter equivalent of window.AsfAuth's public API in
// auth-main.js — same operations (submitRegister, resendOtp, submitVerify,
// submitLoginEmail, submitLoginPhone, submitForgot, logout), same
// validation/business rules, exposed here as Riverpod state instead of
// imperative window.* calls.
//
// AuthFlowController is this app's "OTPController" + "AuthProvider" in one
// (see phone_auth_service.dart's file header for the full architecture
// mapping requested by the Phone Auth audit): it owns every piece of OTP
// flow UI state — step/loading/verificationId/resendToken/error/info — and
// is the only thing the Register/Login/VerifyOtp screens talk to. The
// actual verifyPhoneNumber() protocol lives one layer down in
// PhoneAuthService; account creation/linking/sign-in + Supabase/SQLite
// persistence lives in AuthRepository. This controller just sequences
// those two layers's calls and turns their callbacks into UI state.
// ══════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/remember_login_prefs.dart';
import '../../../email/data/email_repository.dart';
import '../../../email/presentation/providers/email_providers.dart';
import '../../data/auth_repository.dart';
import '../../domain/phone_utils.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

final rememberLoginPrefsProvider =
    Provider<RememberLoginPrefs>((ref) => RememberLoginPrefs());

/// Fires whenever Firebase's own auth state changes — mirrors the
/// `authStateChange` listener registered in auth-main.js's init(). This is
/// the single source of truth the app's root routing (see app.dart) reacts
/// to, exactly like showAuthShell()/showAppShell()/showOnboarding() do on
/// the web.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Fetches the signed-in user's Supabase profile — used by the Dashboard
/// route for its greeting name and, eventually, far more (pig count, batch
/// profile, settings, etc. — see hydrateAppFromProfile() in the web app for
/// the full list a future Dashboard slice will need to port).
///
/// P2 fix: this used to be a single unretried future — any transient
/// failure (a cold Supabase connection, a brief offline blip right after
/// login) surfaced as an AsyncError, which app_router.dart's `.error`
/// branch turned into a PERMANENT "fullName: null" Dashboard render. That
/// was the actual mechanism behind "Good Morning, Farmer 👋" appearing for
/// a real, freshly-registered, already-logged-in user — not a missing name
/// in the database, a swallowed transient error. Retrying in-place here
/// (Riverpod keeps reporting `loading` — so BootLoadingShell stays up,
/// never "Farmer" — for as long as this future hasn't settled) means the
/// router's `.error` branch is now reserved for genuine, non-transient
/// failures, and even those get a visible retry affordance instead of a
/// dead end (see GreetingHeader's onRetryName).
final userProfileProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, uid) async {
  final repo = ref.watch(authRepositoryProvider);
  const retryDelays = [
    Duration(milliseconds: 400),
    Duration(milliseconds: 1200)
  ];
  for (var attempt = 0;; attempt++) {
    try {
      return await repo.getUserProfile(uid);
    } catch (e) {
      if (attempt >= retryDelays.length) rethrow;
      await Future.delayed(retryDelays[attempt]);
    }
  }
});

enum AuthFlowStep { idle, otpSent }

enum VerifyMode { register, login }

class PendingRegistration {
  const PendingRegistration({
    required this.name,
    required this.mobileE164,
    required this.municipality,
    required this.email,
    required this.password,
  });

  final String name;
  final String mobileE164;
  final String municipality;
  final String email;
  final String password;
}

class AuthFlowState {
  const AuthFlowState({
    this.step = AuthFlowStep.idle,
    this.isLoading = false,
    this.errorMessage,
    this.infoMessage,
    this.verificationId,
    this.resendToken,
    this.verifyMode = VerifyMode.register,
    this.pendingRegistration,
    this.otpPhoneDisplay,
    this.forgotEmailSent = false,
  });

  final AuthFlowStep step;
  final bool isLoading;
  final String? errorMessage;
  final String? infoMessage;
  final String? verificationId;
  // ForceResendingToken from the most recent codeSent callback — passed
  // back into the next startPhoneVerification() call on a "Resend code"
  // tap so Firebase resumes the same verification session (see
  // PhoneAuthService's file header) instead of treating the resend as an
  // unrelated new request.
  final int? resendToken;
  final VerifyMode verifyMode;
  final PendingRegistration? pendingRegistration;
  final String? otpPhoneDisplay;
  final bool forgotEmailSent;

  AuthFlowState copyWith({
    AuthFlowStep? step,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
    String? verificationId,
    int? resendToken,
    VerifyMode? verifyMode,
    PendingRegistration? pendingRegistration,
    String? otpPhoneDisplay,
    bool? forgotEmailSent,
  }) {
    return AuthFlowState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      verifyMode: verifyMode ?? this.verifyMode,
      pendingRegistration: pendingRegistration ?? this.pendingRegistration,
      otpPhoneDisplay: otpPhoneDisplay ?? this.otpPhoneDisplay,
      forgotEmailSent: forgotEmailSent ?? this.forgotEmailSent,
    );
  }
}

class AuthFlowController extends StateNotifier<AuthFlowState> {
  AuthFlowController(this._repo, this._rememberPrefs, this._emailRepo)
      : super(const AuthFlowState());

  final AuthRepository _repo;
  final RememberLoginPrefs _rememberPrefs;
  final EmailRepository _emailRepo;

  /// Registration — see auth_repository.dart's file header for why the
  /// phone step LINKS rather than signs in. Order matches submitRegister()
  /// in auth-main.js exactly: phone-taken check → email-taken check →
  /// create email/password user → set display name → start phone
  /// verification.
  Future<void> submitRegister({
    required String name,
    required String mobileRaw,
    required String municipality,
    required String email,
    required String password,
  }) async {
    final phone = normalizePhilippineMobile(mobileRaw);
    if (phone == null) {
      state = state.copyWith(
          errorMessage:
              'Please enter a valid Philippine mobile number (e.g. 09171234567).');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (await _repo.phoneNumberIsTaken(phone)) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'This phone number is already registered to another account.',
        );
        return;
      }
      final existingUidForEmail = await _repo.getUidByEmail(email);
      if (existingUidForEmail != null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'This email is already registered. Please log in or use another email.',
        );
        return;
      }

      await _repo.createEmailPasswordUser(
          email: email, password: password, displayName: name);

      // ROOT-CAUSE FIX — registration race condition: createEmailPasswordUser()
      // above signs the user into Firebase IMMEDIATELY, which fires
      // authStateChangesProvider and, via _AuthRefreshNotifier, makes
      // GoRouter re-evaluate redirect() — often before startPhoneVerification()
      // below even finishes its network round-trip to actually send the SMS.
      // `step` used to stay at its previous value (idle) until onCodeSent
      // fired, so during that window the router saw "signed in, sitting on
      // a signed-out route (/register)" and matched its general
      // already-signed-in rule, bouncing the user straight to /dashboard —
      // before _finishRegistration() (which creates the Supabase/SQLite
      // profile) ever ran. That is what produced an "empty profile" after
      // registration: no profile was ever created, not a persistence bug.
      // Setting step: otpSent HERE, in the same update as verifyMode/
      // pendingRegistration and before startPhoneVerification is even
      // called, closes that window — the router's mid-registration
      // carve-out (see app_router.dart's redirect()) is active from this
      // point on, not from whenever the SMS happens to actually send.
      state = state.copyWith(
        verifyMode: VerifyMode.register,
        step: AuthFlowStep.otpSent,
        // Email verification was sent alongside account creation (see
        // createEmailPasswordUser) — surfaced here so the OTP screen can
        // show it without a separate round-trip. It runs in parallel with,
        // not instead of, the phone-OTP step below, which registration
        // still requires to complete.
        infoMessage:
            'We sent a verification link to $email. You can verify it anytime from Settings.',
        pendingRegistration: PendingRegistration(
          name: name,
          mobileE164: phone,
          municipality: municipality,
          email: email,
          password: password,
        ),
      );

      await _repo.startPhoneVerification(
        phoneE164: phone,
        onCodeSent: (codeSent) {
          // step is already otpSent (set above) — this just supplies the
          // verificationId once the SMS has actually been sent, plus the
          // resend token a later "Resend code" tap should reuse.
          state = state.copyWith(
            isLoading: false,
            verificationId: codeSent.verificationId,
            resendToken: codeSent.forceResendingToken,
            otpPhoneDisplay: phone,
          );
        },
        onFailed: (e) {
          state = state.copyWith(
              isLoading: false, errorMessage: mapFirebaseAuthError(e));
        },
        onAutoVerified: _handleAutoVerifiedCredential,
        onCodeAutoRetrievalTimeout: () {
          // Purely informational — the user can always type the code
          // manually; this just signals that Android's automatic SMS
          // read-back window has closed, matching the official
          // codeAutoRetrievalTimeout callback's documented meaning.
          state = state.copyWith(
              infoMessage: 'Enter the 6-digit code we sent you.');
        },
      );
    } catch (e) {
      state = state.copyWith(
          isLoading: false, errorMessage: mapFirebaseAuthError(e));
    }
  }

  /// True while a verifyPhoneNumber() call is already running — the OTP
  /// screen's "Resend" button should stay disabled while this is true,
  /// on top of its own 60s countdown, so a slow network round-trip can
  /// never be raced by a second tap.
  bool get isSendingCode => _repo.isPhoneVerificationInFlight;

  Future<void> resendOtp() async {
    final phone = state.otpPhoneDisplay;
    if (phone == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.startPhoneVerification(
        phoneE164: phone,
        // Reuses the token from the original send (see PhoneAuthService's
        // file header) instead of starting an unrelated new verification
        // session — this is what makes "Resend" behave the way the
        // official docs describe rather than just calling
        // verifyPhoneNumber() again from scratch.
        resendToken: state.resendToken,
        onCodeSent: (codeSent) {
          state = state.copyWith(
            isLoading: false,
            verificationId: codeSent.verificationId,
            resendToken: codeSent.forceResendingToken,
            infoMessage: 'Code resent.',
          );
        },
        onFailed: (e) {
          state = state.copyWith(
              isLoading: false, errorMessage: mapFirebaseAuthError(e));
        },
        onAutoVerified: _handleAutoVerifiedCredential,
        onCodeAutoRetrievalTimeout: () {
          state = state.copyWith(
              infoMessage: 'Enter the 6-digit code we sent you.');
        },
      );
    } catch (e) {
      state = state.copyWith(
          isLoading: false, errorMessage: mapFirebaseAuthError(e));
    }
  }

  /// Completes the OTP step. On the register path, finishes creating the
  /// Supabase profile row (name/phone/municipality/email) and logs the
  /// registration event. On the login-with-mobile path, just signs in.
  Future<void> submitVerify(String code) async {
    final verificationId = state.verificationId;
    if (verificationId == null) {
      state = state.copyWith(
          errorMessage:
              'This verification code has expired. Please request a new one.');
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (state.verifyMode == VerifyMode.register) {
        await _repo.confirmLinkPhoneCredential(
            verificationId: verificationId, smsCode: code);
        await _finishRegistration();
      } else {
        final credential = await _repo.confirmSignInPhoneCredential(
            verificationId: verificationId, smsCode: code);
        await _finishPhoneLogin(credential.user?.uid);
      }
      _markVerifySucceeded();
    } catch (e) {
      if (state.verifyMode == VerifyMode.login) {
        final failedUid =
            await _repo.getUidByPhone(state.otpPhoneDisplay ?? '');
        if (failedUid != null) {
          await _repo.recordActivityLog(
            uid: failedUid,
            actionType: 'auth',
            description: 'Invalid or expired OTP',
            action: 'LOGIN',
            status: 'FAILED',
          );
        }
      }
      state = state.copyWith(
          isLoading: false, errorMessage: mapFirebaseAuthError(e));
    }
  }

  /// Android's SMS auto-retrieval can complete phone verification before
  /// the user ever types a code — Firebase hands back a ready-to-use
  /// PhoneAuthCredential via startPhoneVerification's verificationCompleted
  /// callback in that case. Passed as `onAutoVerified` to every
  /// startPhoneVerification call below so that real-device flow finishes
  /// registration/login immediately instead of leaving the user stuck on a
  /// code-entry screen for a code they'll never need to type manually.
  /// Mirrors submitVerify()'s two branches exactly, just sourcing the
  /// credential differently (no verificationId/smsCode round-trip needed).
  Future<void> _handleAutoVerifiedCredential(
      PhoneAuthCredential credential) async {
    if (state.step != AuthFlowStep.otpSent) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (state.verifyMode == VerifyMode.register) {
        await _repo.linkPhoneCredential(credential);
        await _finishRegistration();
      } else {
        final result = await _repo.signInWithPhoneCredential(credential);
        await _finishPhoneLogin(result.user?.uid);
      }
      _markVerifySucceeded();
    } catch (e) {
      state = state.copyWith(
          isLoading: false, errorMessage: mapFirebaseAuthError(e));
    }
  }

  Future<void> _finishRegistration() async {
    final pending = state.pendingRegistration!;
    final user = _repo.currentUser!;
    await _repo.createUserProfile(
      user.uid,
      fullName: pending.name,
      phoneNumber: pending.mobileE164,
      municipality: pending.municipality,
      email: pending.email,
    );
    await _repo.recordActivityLog(
      uid: user.uid,
      actionType: 'auth',
      description: 'Account registered',
      username: pending.name,
      action: 'REGISTER',
      status: 'SUCCESS',
    );
    // Brevo welcome email — fire-and-forget: EmailRepository already never
    // throws and queues on failure (see its doc), so a slow/unreachable
    // email service can never block or fail registration itself (spec
    // item 11).
    unawaited(_emailRepo.sendWelcomeEmail(user.uid,
        to: pending.email, name: pending.name));
  }

  Future<void> _finishPhoneLogin(String? uid) async {
    if (uid != null) {
      await _repo.stampLastLogin(uid);
      await _repo.recordActivityLog(
        uid: uid,
        actionType: 'auth',
        description: 'Logged in via phone OTP',
        action: 'LOGIN',
        status: 'SUCCESS',
      );
    }
  }

  /// Clear `step` back to idle on success (not just isLoading): the
  /// register path's Firebase session actually started back at
  /// createEmailPasswordUser(), before this phone-link step ever ran, so
  /// authStateChangesProvider already emits a non-null user WHILE the user
  /// is still looking at the OTP screen. The router's redirect
  /// special-cases `step == otpSent && verifyMode == register` to keep the
  /// user on /verify-otp despite already being "signed in" — this reset is
  /// what lets that special-case turn back off once verification actually
  /// succeeds, so the redirect's normal dashboard logic can take over.
  /// Actual navigation to the app shell happens via the router's redirect
  /// reacting to authStateChangesProvider, same pattern as the web app's
  /// authStateChange listener driving showAppShell()/showOnboarding().
  void _markVerifySucceeded() {
    state = state.copyWith(isLoading: false, step: AuthFlowStep.idle);
  }

  Future<void> submitLoginEmail(
      {required String email,
      required String password,
      bool remember = true}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final credential =
          await _repo.signInWithEmailPassword(email: email, password: password);
      await _rememberPrefs.setRemember(remember);
      final uid = credential.user?.uid;
      if (uid != null) {
        await _repo.stampLastLogin(uid);
        await _repo.recordActivityLog(
          uid: uid,
          actionType: 'auth',
          description: 'Logged in',
          username: email,
          action: 'LOGIN',
          status: 'SUCCESS',
        );
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      final failedUid = await _repo.getUidByEmail(email);
      if (failedUid != null) {
        await _repo.recordActivityLog(
          uid: failedUid,
          actionType: 'auth',
          description: 'Wrong password',
          username: email,
          action: 'LOGIN',
          status: 'FAILED',
        );
      }
      state = state.copyWith(
          isLoading: false, errorMessage: mapFirebaseAuthError(e));
    }
  }

  Future<void> submitLoginPhone(String mobileRaw) async {
    final phone = normalizePhilippineMobile(mobileRaw);
    if (phone == null) {
      state = state.copyWith(
          errorMessage:
              'Please enter a valid Philippine mobile number (e.g. 09171234567).');
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (!await _repo.phoneNumberIsTaken(phone)) {
        state = state.copyWith(
            isLoading: false,
            errorMessage: 'No account was found with these details.');
        return;
      }
      state = state.copyWith(verifyMode: VerifyMode.login);
      await _repo.startPhoneVerification(
        phoneE164: phone,
        onCodeSent: (codeSent) {
          state = state.copyWith(
            isLoading: false,
            step: AuthFlowStep.otpSent,
            verificationId: codeSent.verificationId,
            resendToken: codeSent.forceResendingToken,
            otpPhoneDisplay: phone,
          );
        },
        onFailed: (e) {
          state = state.copyWith(
              isLoading: false, errorMessage: mapFirebaseAuthError(e));
        },
        onAutoVerified: _handleAutoVerifiedCredential,
        onCodeAutoRetrievalTimeout: () {
          state = state.copyWith(
              infoMessage: 'Enter the 6-digit code we sent you.');
        },
      );
    } catch (e) {
      final failedUid = await _repo.getUidByPhone(phone);
      if (failedUid != null) {
        await _repo.recordActivityLog(
          uid: failedUid,
          actionType: 'auth',
          description: 'Mobile OTP send failed',
          username: phone,
          action: 'LOGIN',
          status: 'FAILED',
        );
      }
      state = state.copyWith(
          isLoading: false, errorMessage: mapFirebaseAuthError(e));
    }
  }

  /// Returns true if a reset email was actually sent (real account found).
  /// The UI must show "No account was found with this email address." and
  /// NOT a generic success message when this returns false — this is the
  /// exact fix for the "reset email sent for unregistered email" bug from
  /// the web app's earlier bug report.
  Future<bool> submitForgotPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final uid = await _repo.submitForgotPassword(email);
      if (uid == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No account was found with this email address.',
        );
        return false;
      }
      await _repo.recordActivityLog(
        uid: uid,
        actionType: 'auth',
        description: 'Requested password reset',
        username: email,
        action: 'PASSWORD_RESET',
        status: 'SUCCESS',
      );
      // Spec item 3: after Firebase's own reset email is requested, also
      // send an informational Brevo email confirming the request was made
      // (never a substitute for Firebase's actual reset link).
      unawaited(_emailRepo.sendPasswordResetEmail(uid, to: email));
      state = state.copyWith(isLoading: false, forgotEmailSent: true);
      return true;
    } catch (e) {
      final failedUid = await _repo.getUidByEmail(email);
      if (failedUid != null) {
        await _repo.recordActivityLog(
          uid: failedUid,
          actionType: 'auth',
          description: 'Password reset request failed',
          username: email,
          action: 'PASSWORD_RESET',
          status: 'FAILED',
        );
      }
      state = state.copyWith(
          isLoading: false, errorMessage: mapFirebaseAuthError(e));
      return false;
    }
  }

  Future<void> logout() async {
    final uid = _repo.currentUser?.uid;
    if (uid != null) {
      await _repo.recordActivityLog(
        uid: uid,
        actionType: 'auth',
        description: 'Logged out',
        action: 'LOGOUT',
        status: 'SUCCESS',
      );
    }
    await _repo.signOut();
    // SQLite's cached data for this uid is deliberately left in place (same
    // as the web app) so a re-login on this device is instantly ready offline.
  }

  void reset() {
    state = const AuthFlowState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authFlowControllerProvider =
    StateNotifierProvider<AuthFlowController, AuthFlowState>((ref) {
  return AuthFlowController(
    ref.watch(authRepositoryProvider),
    ref.watch(rememberLoginPrefsProvider),
    ref.watch(emailRepositoryProvider),
  );
});
