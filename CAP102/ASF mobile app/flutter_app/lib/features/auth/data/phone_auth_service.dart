// ══════════════════════════════════════════════════════════════════════
// PhoneAuthService — the ONLY place in this app that calls
// FirebaseAuth.verifyPhoneNumber(). Isolating it here means the official
// Firebase phone-auth protocol (PhoneAuthOptions' four lifecycle
// callbacks and ForceResendingToken reuse on resend) is implemented in
// exactly one place, matching the official documentation:
// https://firebase.google.com/docs/auth/flutter/phone-auth
//
// Note on the Android-only "missing activity for reCAPTCHA" case: the
// native Android SDK throws a distinct
// `FirebaseAuthMissingActivityForRecaptchaException` Kotlin/Java type, but
// FlutterFire's Android plugin (FlutterFirebaseAuthPluginException.java)
// catches every native FirebaseAuthException subtype and relays it to Dart
// as a plain `FirebaseAuthException` carrying the native error code — there
// is no separate Dart exception class for this case (confirmed by reading
// package:firebase_auth/firebase_auth.dart's export list, which does not
// include it). It is therefore handled below by the generic
// `on FirebaseAuthException catch (e)` block, same as every other Firebase
// auth error, with auth_error_mapper.dart supplying the user-facing message
// for whatever code the native SDK reports.
//
// AuthRepository (one layer up) never touches FirebaseAuth.verifyPhoneNumber
// directly — it only calls this service, then does the
// linkWithCredential()/signInWithCredential() step with the resulting
// PhoneAuthCredential. That split mirrors the architecture requested for
// this audit: PhoneAuthService (this file, wraps the raw SDK call) ->
// AuthRepository (data/auth_repository.dart, owns account creation/
// linking/sign-in + Supabase/SQLite persistence) -> AuthFlowController
// (presentation/providers/auth_providers.dart, the Riverpod
// StateNotifier the OTP/Register/Login screens talk to — this is this
// app's "OTPController"/"AuthProvider": it owns the OTP flow's UI state
// — step/loading/verificationId/resend-token/error — the same role an
// OTPController plays in the requested architecture, kept inside the
// existing Riverpod provider layer rather than a parallel class so the
// three auth screens keep one single state stream to listen to).
// ══════════════════════════════════════════════════════════════════════

import 'package:firebase_auth/firebase_auth.dart';

/// Everything the caller needs once Firebase has actually dispatched an
/// SMS: the verificationId required to build a PhoneAuthCredential, and
/// the ForceResendingToken that lets a subsequent "Resend" reuse this
/// same verification session (see [PhoneAuthService.verifyPhoneNumber]'s
/// [resendToken] parameter) instead of starting an entirely new one.
/// Reusing the token is what the official docs recommend for a resend
/// button — it avoids Firebase treating the resend as a brand-new,
/// unrelated verification attempt (which is both slower and counts
/// separately against Firebase's per-number SMS quota).
// Named PhoneVerificationCodeSent rather than the shorter, more obvious
// "PhoneCodeSent" to avoid colliding with firebase_auth_platform_interface's
// own internal `PhoneCodeSent` class, which
// `package:firebase_auth/firebase_auth.dart` re-exports — the compiler
// reported an ambiguous-import error the first time this used that name.
class PhoneVerificationCodeSent {
  const PhoneVerificationCodeSent(
      {required this.verificationId, this.forceResendingToken});
  final String verificationId;
  final int? forceResendingToken;
}

class PhoneAuthService {
  PhoneAuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Guards against a second verifyPhoneNumber() call firing while one is
  /// already in flight (e.g. a double-tap on "Send code"/"Resend" before
  /// the button's own disabled-while-loading state has rebuilt yet).
  /// Firebase itself has no such guard — two overlapping calls would each
  /// get their own verificationId and could confuse which one the OTP
  /// screen should confirm against, or trip Firebase's abuse-detection
  /// quota faster than a real user could.
  bool _inFlight = false;
  bool get isVerificationInFlight => _inFlight;

  /// Starts (or, via [resendToken], resumes) phone-number verification.
  /// Every parameter here maps 1:1 to the official
  /// `PhoneAuthProvider.verifyPhoneNumber()`/`PhoneAuthOptions` callbacks:
  ///
  ///  - [onAutoVerified]  == `verificationCompleted`  — fires when Android
  ///    completes verification WITHOUT the user typing anything, via
  ///    either Instant Verification (the device itself is already
  ///    trusted/SIM-verified) or SMS Auto-Retrieval (the OS reads the
  ///    incoming SMS itself and hands Firebase a ready credential). The
  ///    caller should immediately call linkWithCredential()/
  ///    signInWithCredential() with the credential it receives here — the
  ///    OTP screen should never require the user to type a code they'll
  ///    never actually need.
  ///  - [onFailed]        == `verificationFailed` — a real
  ///    FirebaseAuthException (invalid number, quota exceeded, etc).
  ///    `FirebaseAuthMissingActivityForRecaptchaException` (an
  ///    Android-only case where Firebase needed to show a reCAPTCHA
  ///    fallback but the plugin had no foreground Activity to attach it
  ///    to — see the class doc above) is caught separately below and
  ///    normalized into a FirebaseAuthException with a stable code so
  ///    every caller only ever has one exception type to handle.
  ///  - [onCodeSent]      == `codeSent` — SMS dispatched; hands back both
  ///    the verificationId AND the resend token (see [PhoneVerificationCodeSent]).
  ///  - [onCodeAutoRetrievalTimeout] == `codeAutoRetrievalTimeout` — the
  ///    ~60s SMS auto-retrieval window closed with no code detected; the
  ///    UI should stop waiting for auto-fill and let the user type
  ///    normally (already possible the whole time — this is purely a
  ///    signal, not a hard cutoff).
  ///
  /// [resendToken] should be the [PhoneVerificationCodeSent.forceResendingToken] from
  /// the previous call when this is a "Resend code" tap, or omitted for a
  /// first-time send.
  Future<void> verifyPhoneNumber({
    required String phoneE164,
    required void Function(PhoneVerificationCodeSent codeSent) onCodeSent,
    required void Function(FirebaseAuthException error) onFailed,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    void Function(String verificationId)? onCodeAutoRetrievalTimeout,
    int? resendToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (_inFlight) return; // duplicate tap — ignore, see _inFlight's doc above
    _inFlight = true;
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneE164,
        timeout: timeout,
        forceResendingToken: resendToken,
        verificationCompleted: (credential) {
          _inFlight = false;
          onAutoVerified(credential);
        },
        verificationFailed: (error) {
          _inFlight = false;
          onFailed(error);
        },
        codeSent: (verificationId, forceResendingToken) {
          // Firebase's own send-side work is done the moment codeSent
          // fires — clearing _inFlight here (rather than waiting for the
          // user to finish typing/submitting the code) is correct: the
          // thing this flag protects against is a second concurrent
          // *send*, not a second concurrent *verify*.
          _inFlight = false;
          onCodeSent(PhoneVerificationCodeSent(
              verificationId: verificationId,
              forceResendingToken: forceResendingToken));
        },
        codeAutoRetrievalTimeout: (verificationId) {
          onCodeAutoRetrievalTimeout?.call(verificationId);
        },
      );
    } on FirebaseAuthException catch (e) {
      _inFlight = false;
      onFailed(e);
    } catch (e) {
      _inFlight = false;
      onFailed(FirebaseAuthException(code: 'unknown', message: e.toString()));
    }
  }
}
