// ══════════════════════════════════════════════════════════════════════
// Firebase error → user-facing message, ported 1:1 from auth-main.js's
// mapAuthError(). Every code the JS version handles is handled here with
// the same resulting message, so behavior stays identical between the web
// app and this Flutter app.
// ══════════════════════════════════════════════════════════════════════

import 'package:firebase_auth/firebase_auth.dart';

const Map<String, String> _codeToMessage = {
  'invalid-phone-number':
      'The phone number entered is not valid. Please check the number and try again.',
  'missing-phone-number':
      'The phone number entered is not valid. Please check the number and try again.',
  'invalid-verification-code':
      'The verification code entered is invalid. Please check and try again.',
  'missing-verification-code':
      'The verification code entered is invalid. Please check and try again.',
  'code-expired':
      'This verification code has expired. Please request a new one.',
  'session-expired':
      'This verification code has expired. Please request a new one.',
  'too-many-requests':
      'Too many attempts. Please wait a bit before trying again.',
  'quota-exceeded':
      'Too many verification requests for this number right now. Please wait a while before trying again.',
  'network-request-failed':
      'Network error. Please check your connection and try again.',
  'unavailable': 'Service temporarily unavailable. Please try again shortly.',
  'internal-error':
      'Service temporarily unavailable. Please try again shortly.',
  'phone-number-already-exists':
      'This phone number is already registered to another account.',
  'credential-already-in-use':
      'This phone number is already registered to another account.',
  'email-already-in-use':
      'This email is already registered. Please log in or use another email.',
  'account-exists-with-different-credential':
      'This email is already registered. Please log in or use another email.',
  'user-not-found': 'No account was found with these details.',
  'user-disabled': 'This account has been disabled. Please contact support.',
  'invalid-credential': 'Incorrect email or password.',
  'wrong-password': 'Incorrect email or password.',
  'weak-password': 'Please choose a stronger password (at least 6 characters).',
  'invalid-email': 'Please enter a valid email address.',
  'requires-recent-login': 'Please log in again to complete this action.',
  'popup-closed-by-user': 'That action was cancelled.',
  'cancelled': 'That action was cancelled.',
  // ── Additions from the Phone Auth audit — every code Firebase's own
  // docs list as possible from verifyPhoneNumber()/linkWithCredential()/
  // signInWithCredential() that the table above didn't already cover. ──
  'missing-activity-for-recaptcha':
      'Could not show the verification screen. Please make sure the app is open and in the foreground, then try again.',
  'captcha-check-failed': 'Verification failed. Please try again in a moment.',
  'app-not-authorized':
      'This app is not authorized to verify phone numbers right now. Ensure your app build (SHA-1 fingerprint) is registered in Firebase Console.',
  'missing-client-identifier':
      'Verification failed. Please try again in a moment.',
  'invalid-app-credential':
      'Phone verification failed. Ensure your app build (SHA-1 fingerprint) is registered in Firebase Console, then try again.',
  'operation-not-allowed':
      'Phone sign-in is not currently available. Please contact support.',
  'provider-already-linked':
      'This account already has a phone number linked to it.',
  'user-mismatch':
      'This code does not match the account currently signed in. Please start over.',
  'timeout':
      'The request timed out. Please check your connection and try again.',
  'unknown': 'Something went wrong. Please try again.',
};

const String kGenericAuthError = 'Something went wrong. Please try again.';

/// Mirrors mapAuthError(err) from auth-main.js exactly — same fallback,
/// same "(code)" suffix so a user-reported screenshot can still be traced
/// back to a specific Firebase error code during support/debugging.
String mapFirebaseAuthError(Object error) {
  if (error is FirebaseAuthException) {
    final code = error.code;
    final message = _codeToMessage[code] ?? kGenericAuthError;
    return '$message ($code)';
  }
  return kGenericAuthError;
}
