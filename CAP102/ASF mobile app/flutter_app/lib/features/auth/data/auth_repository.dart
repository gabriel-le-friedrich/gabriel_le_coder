// ══════════════════════════════════════════════════════════════════════
// ASF — Auth repository (Flutter port of the auth logic in
// src/auth-main.js). Firebase Authentication is the sole identity
// provider; Supabase's `profiles` table is the sole source of truth for
// profile fields (full name, phone, municipality, email, onboarding
// status) — same hybrid-backend split as the existing app.
//
// Phone OTP nuance (ported faithfully): registration creates the Firebase
// user via email/password FIRST (that sign-in stays current for the rest
// of registration), then LINKS the phone number onto that same
// already-signed-in user via `linkWithCredential()` — never
// `signInWithCredential()` during registration, because phone auth is a
// real independent sign-in method that would otherwise SWITCH the active
// session to whichever Firebase user that phone number already resolves
// to (a brand-new orphaned user the first time, or — critically — a
// pre-existing account if that phone number is ever reused). Logging in
// with a phone number (as opposed to registering) is the one case that
// legitimately DOES use signInWithCredential(), since that's a real
// separate sign-in flow, not a linking step.
// ══════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/config/supabase_config.dart';
import '../../../core/database/sqlite_service.dart';
import '../../../core/services/device_id_service.dart';
import '../../../core/services/image_compression_service.dart';
import 'phone_auth_service.dart';
export '../domain/auth_error_mapper.dart' show mapFirebaseAuthError;
export 'phone_auth_service.dart' show PhoneVerificationCodeSent;

/// Result of starting a phone-verification flow — the UI needs the
/// verificationId to complete the OTP step, and a way to resend.
class PhoneVerificationHandle {
  PhoneVerificationHandle({required this.verificationId});
  final String verificationId;
}

class AuthRepository {
  AuthRepository(
      {FirebaseAuth? firebaseAuth, PhoneAuthService? phoneAuthService})
      : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _phoneAuth =
            phoneAuthService ?? PhoneAuthService(firebaseAuth: firebaseAuth);

  final FirebaseAuth _auth;
  final PhoneAuthService _phoneAuth;
  final SqliteService _sqlite = SqliteService.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Supabase profile lookups (RLS is permissive — access control is
  // enforced here in the app by always filtering on the signed-in
  // Firebase uid, exactly like sync-engine.js/auth-main.js on the web). ──

  /// All three pre-auth lookups below (`phoneNumberIsTaken`,
  /// `getUidByEmail`, `getUidByPhone`) route through the `lookup-account`
  /// Supabase Edge Function instead of querying `profiles` directly.
  ///
  /// Root cause this fixes: every one of these methods is called BEFORE
  /// the user has an active Firebase session — Forgot Password exists
  /// specifically because the user can't sign in, the phone-taken check
  /// runs before phone login completes, and the duplicate-account guard
  /// runs before registration creates the Firebase user. `profiles`' RLS
  /// policy is `firebase_uid = auth.jwt()->>'sub'`, which evaluates to
  /// `firebase_uid = NULL` for an unauthenticated request — and `NULL`
  /// never equals anything in SQL, so a direct client-side query from a
  /// signed-out user ALWAYS returned zero rows, no matter the account's
  /// real existence or the email's casing. That's what produced "No
  /// account was found with this email address" on Forgot Password for a
  /// real, freshly-registered account — normalizing casing alone (the
  /// previous fix attempt) could never have worked, because RLS blocked
  /// the query before casing was ever evaluated. Both `phoneNumberIsTaken`
  /// (pre-login) and the duplicate-registration guard in
  /// AuthFlowController.submitRegister were silently broken by the exact
  /// same mechanism.
  ///
  /// `lookup-account` runs server-side with the service-role key (bypasses
  /// RLS) and is deliberately unauthenticated (see
  /// `[functions.lookup-account]` in supabase/config.toml) so it's
  /// reachable from a signed-out client. It returns only a Firebase uid —
  /// never any other profile field — which grants no access on its own;
  /// every other read/write still requires a real Firebase ID token whose
  /// `sub` claim matches, enforced by RLS exactly as before.
  Future<String?> _lookupUid(
      {required String type, required String value}) async {
    try {
      final res = await supabase.functions
          .invoke('lookup-account', body: {'type': type, 'value': value});
      final body = res.data;
      final map =
          body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
      return map['uid'] as String?;
    } catch (_) {
      // Offline / function unreachable — best-effort, never throws. Callers
      // treat this the same as "not found," matching the previous
      // behavior's failure mode.
      return null;
    }
  }

  Future<bool> phoneNumberIsTaken(String phoneE164) async {
    return await _lookupUid(type: 'phone', value: phoneE164) != null;
  }

  /// Used to attribute a "failed login attempt" log entry to the right
  /// account, AND to gate Forgot Password (see submitForgotPassword
  /// below), never to bypass the real Firebase Auth check. Returns null
  /// (never throws) on any failure/offline case. Case-insensitive by
  /// construction (the Edge Function uses `ilike`) — see `_lookupUid`'s
  /// doc for the full root-cause story.
  Future<String?> getUidByEmail(String email) async {
    return _lookupUid(type: 'email', value: email.trim());
  }

  Future<String?> getUidByPhone(String phoneE164) async {
    return _lookupUid(type: 'phone', value: phoneE164);
  }

  /// SQLite-first, matching every other write path in this app (see
  /// getUserProfile's doc above for the general rationale). This used to
  /// call the Supabase upsert directly with no try/catch and seed SQLite
  /// only afterward — meaning a registration completed OFFLINE (or hitting
  /// any transient Supabase error right after the Firebase account was
  /// created and the phone number linked) threw out of here, was caught by
  /// AuthFlowController.submitVerify()'s try/catch, and surfaced as a
  /// generic error — while the user was left with a real, phone-verified
  /// Firebase account and NO profile row anywhere (not Supabase, not
  /// SQLite). Retrying registration from that state could even fail
  /// outright (Firebase already has that email/uid). Writing SQLite FIRST
  /// means the profile the user just typed can never be lost to a network
  /// hiccup — the Supabase mirror is retried later by SyncEngine via
  /// [resyncPendingProfile] exactly like every other offline-queued write
  /// in this app (health, expenses, pig, avatar).
  Future<void> createUserProfile(
    String uid, {
    required String fullName,
    required String phoneNumber,
    required String municipality,
    required String email,
    String? province,
    String? farmName,
    String? farmerType,
  }) async {
    // Normalized once here so every downstream write (SQLite + Supabase)
    // and every future getUidByEmail/login-failure lookup agrees on the
    // same casing — see getUidByEmail's doc for the "No account was found"
    // bug this, plus that method's ilike match, fixes together.
    final normalizedEmail = email.trim().toLowerCase();
    final nowMs = SqliteService.nowMs();
    final sqliteRow = {
      'id': uid,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'municipality': municipality,
      'email': normalizedEmail,
      'province': province,
      'farmName': farmName,
      'farmerType': farmerType ?? 'Backyard Raiser',
      'role': 'raiser',
      'profileImage': null,
      'verified': 1,
      // createUserProfile only ever runs after linkWithCredential()/
      // signInWithCredential() has already succeeded (see
      // AuthFlowController._finishRegistration) — the phone number this
      // row records was, by construction, already OTP-verified.
      'phoneVerified': 1,
      'lastLogin': nowMs,
      'onboardingCompleted': 0,
      'createdAt': nowMs,
      'updatedAt': nowMs,
      'synced': 0,
    };
    // Seed the local SQLite users row FIRST — this is what makes the
    // just-typed profile durable even if every step below fails (offline,
    // Supabase outage, RLS claim race). `synced: 0` until the mirror below
    // actually confirms.
    await _sqlite.upsertUser(sqliteRow);

    try {
      // Firebase-as-Supabase-third-party-auth: the `role: authenticated`
      // custom claim is stamped by an onCreate Cloud Function that runs
      // asynchronously, shortly AFTER this user's account was created — so
      // the ID token already cached on-device from sign-up may predate the
      // claim. Force a refresh (and retry briefly if the claim hasn't
      // landed yet) before this, the very first authenticated write this
      // user makes, so Postgres RLS sees `role: authenticated` rather than
      // falling back to `anon` and getting denied by the real per-user
      // policies. Harmless no-op once Third-Party Auth isn't configured yet
      // (getIdToken() still succeeds; it just carries no extra claim).
      await _forceRefreshIdTokenWithRetry();

      await supabase.from('profiles').upsert({
        'firebase_uid': uid,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'municipality': municipality,
        'email': normalizedEmail,
        'province': province,
        'farm_name': farmName,
        'farmer_type': farmerType ?? 'Backyard Raiser',
        'verified': true,
        'phone_verified': true,
        'last_login': DateTime.now().toUtc().toIso8601String(),
        'role': 'raiser',
        'profile_image_url': null,
        'onboarding_completed': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(nowMs),
      }, onConflict: 'firebase_uid');

      await _sqlite.upsertUser({...sqliteRow, 'synced': 1});
    } catch (_) {
      // Offline or Supabase unreachable — the row stays synced:0 and
      // resyncPendingProfile() (wired into SyncEngine.syncNow) retries it
      // on the next reconnect/periodic pass. The user's account and typed
      // profile data are never lost: SQLite already has everything.
    }
  }

  /// Stamps `lastLogin`/`last_login` for [uid] — called on every
  /// successful sign-in (email/password, phone OTP manual entry, AND
  /// Android auto-verification), matching the audit's requirement that a
  /// login updates this field regardless of which method was used.
  /// SQLite-first (never blocks/fails the sign-in the user is already
  /// mid-flow completing), best-effort Supabase mirror — a failure here
  /// only means the timestamp is stale on the server until the next sync
  /// pass, never a reason to fail the login itself.
  Future<void> stampLastLogin(String uid) async {
    final nowMs = SqliteService.nowMs();
    try {
      final existing = await _sqlite.getUser(uid);
      if (existing != null) {
        await _sqlite.upsertUser({...existing, 'lastLogin': nowMs});
      }
    } catch (_) {}
    try {
      await supabase.from('profiles').update({
        'last_login': DateTime.now().toUtc().toIso8601String(),
      }).eq('firebase_uid', uid);
    } catch (_) {
      // offline, or last_login/phone_verified columns not migrated onto
      // this Supabase project yet (see supabase_schema.sql) — non-fatal,
      // never blocks sign-in.
    }
  }

  /// Sync engine support — retries the profile mirror for a user whose
  /// [createUserProfile] Supabase write never landed (registered offline,
  /// or a transient failure right after the Firebase account was created).
  /// No-op if there's no local row yet or it's already synced.
  Future<void> resyncPendingProfile(String uid) async {
    try {
      final local = await _sqlite.getUser(uid);
      if (local == null || (local['synced'] as int? ?? 1) == 1) return;
      await _forceRefreshIdTokenWithRetry();
      await supabase.from('profiles').upsert({
        'firebase_uid': uid,
        'full_name': local['fullName'],
        'phone_number': local['phoneNumber'],
        'municipality': local['municipality'],
        'email': local['email'],
        'province': local['province'],
        'farm_name': local['farmName'],
        'farmer_type': local['farmerType'] ?? 'Backyard Raiser',
        'verified': true,
        'role': local['role'] ?? 'raiser',
        'profile_image_url':
            (local['profileImage'] as String?)?.startsWith('http') == true
                ? local['profileImage']
                : null,
        'onboarding_completed':
            (local['onboardingCompleted'] as int? ?? 0) == 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'firebase_uid');
      await _sqlite.upsertUser({...local, 'synced': 1});
    } catch (_) {
      // still offline / still failing — stays synced:0 for the next pass
    }
  }

  /// Forces a fresh Firebase ID token, retrying briefly if the
  /// `role: authenticated` custom claim hasn't landed yet. Never throws —
  /// this is best-effort synchronization, not a correctness requirement; if
  /// it times out, the caller's own Supabase write still proceeds with
  /// whatever token is current (and RLS will simply deny it until the claim
  /// does land on a later attempt).
  ///
  /// The claim itself is stamped by the `stamp-claim` Supabase Edge
  /// Function, not a Firebase Cloud Function — this project intentionally
  /// stays on Firebase's free Spark plan, and Cloud Functions cannot deploy
  /// at all on Spark regardless of usage. See stamp-claim/index.ts's file
  /// header for the full design. This method calls it lazily, once, the
  /// first time it notices the claim missing — which is what makes this
  /// self-healing for every account: a brand-new registration gets stamped
  /// on its very first authenticated write (no separate "wire into signup"
  /// step needed), and any pre-existing account that predates this function
  /// gets stamped the same way on its next sign-in (no separate one-time
  /// backfill script/run needed either).
  Future<void> _forceRefreshIdTokenWithRetry({
    int maxAttempts = 8,
    Duration delay = const Duration(milliseconds: 1500),
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    var askedToStamp = false;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final token = await user.getIdTokenResult(true);
        if (token.claims?['role'] == 'authenticated') return;
        if (!askedToStamp) {
          askedToStamp = true;
          try {
            await supabase.functions.invoke('stamp-claim');
          } catch (_) {
            // Best-effort — if this call itself fails (offline, function
            // not yet deployed, etc.) the retry loop below still runs its
            // course and simply times out with the claim still missing.
          }
        }
      } catch (_) {
        // fall through to retry/backoff below
      }
      if (attempt < maxAttempts - 1) {
        await Future.delayed(delay);
      }
    }
  }

  /// SQLite-first, matching the write path (updateProfileFields/
  /// createUserProfile both write locally immediately and mirror to
  /// Supabase best-effort). This used to read Supabase only, which meant a
  /// profile edit made offline — or where the Supabase mirror write
  /// silently failed on a transient network hiccup, a real possibility on
  /// mobile data — would appear to "not save": the local SQLite row had
  /// the new value, but the next read re-fetched the stale Supabase row
  /// and the screen showed the old data again. Reading local-first makes
  /// the UI reflect whatever was actually saved on this device. Supabase
  /// is still consulted (a) when there's no local row yet — a fresh
  /// device signing into an existing account — and (b) as a background
  /// refresh afterward, so edits made on a *different* device eventually
  /// show up here too, without ever clobbering an unsynced local edit
  /// (skipped whenever the local row's `synced` flag is 0).
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final local = await _sqlite.getUser(uid);
    if (local != null) {
      unawaited(_refreshProfileCacheFromSupabase(uid));
      return _profileFromSqliteRow(local);
    }
    final res = await supabase
        .from('profiles')
        .select()
        .eq('firebase_uid', uid)
        .maybeSingle();
    if (res == null) return null;
    final profile = _profileFromSupabaseRow(res);
    try {
      await _sqlite.upsertUser(_sqliteRowFromProfile(uid, profile, synced: 1));
    } catch (_) {}
    return profile;
  }

  /// Pulls the latest Supabase row into the local cache — but only when
  /// there's no pending unsynced local edit (synced == 0), so a
  /// still-offline edit on this device never gets silently overwritten by
  /// older remote data. Best-effort: any failure (offline, etc.) is
  /// swallowed, same as every other background sync path in this app.
  Future<void> _refreshProfileCacheFromSupabase(String uid) async {
    try {
      final local = await _sqlite.getUser(uid);
      if (local != null && (local['synced'] as int? ?? 1) == 0) return;
      final res = await supabase
          .from('profiles')
          .select()
          .eq('firebase_uid', uid)
          .maybeSingle();
      if (res == null) return;
      final profile = _profileFromSupabaseRow(res);
      await _sqlite.upsertUser(_sqliteRowFromProfile(uid, profile, synced: 1));
    } catch (_) {}
  }

  Map<String, dynamic> _profileFromSupabaseRow(Map<String, dynamic> res) {
    return {
      'fullName': res['full_name'],
      'phoneNumber': res['phone_number'],
      'municipality': res['municipality'],
      'email': res['email'],
      'province': res['province'],
      'farmName': res['farm_name'],
      'farmerType': res['farmer_type'],
      'role': res['role'],
      'profileImage': res['profile_image_url'],
      'verified': res['verified'] == true,
      'onboardingCompleted': res['onboarding_completed'] == true,
      // Settings redesign's "Member Since" field — created_at has always
      // been written on the profiles row (see createUserProfile below), it
      // was just never read back out until now. Additive only: no schema
      // change, no new write path.
      'createdAt': res['created_at'],
    };
  }

  Map<String, dynamic> _profileFromSqliteRow(Map<String, dynamic> row) {
    return {
      'fullName': row['fullName'],
      'phoneNumber': row['phoneNumber'],
      'municipality': row['municipality'],
      'email': row['email'],
      'province': row['province'],
      'farmName': row['farmName'],
      'farmerType': row['farmerType'],
      'role': row['role'],
      'profileImage': row['profileImage'],
      'verified': row['verified'] == 1,
      'onboardingCompleted': row['onboardingCompleted'] == 1,
      // See the matching comment in _profileFromSupabaseRow above — same
      // already-stored createdAt column (sqlite_service.dart's `users`
      // table), just newly surfaced here.
      'createdAt': row['createdAt'],
    };
  }

  Map<String, dynamic> _sqliteRowFromProfile(
      String uid, Map<String, dynamic> profile,
      {required int synced}) {
    return {
      'id': uid,
      'fullName': profile['fullName'],
      'phoneNumber': profile['phoneNumber'],
      'municipality': profile['municipality'],
      'email': profile['email'],
      'province': profile['province'],
      'farmName': profile['farmName'],
      'farmerType': profile['farmerType'],
      'role': profile['role'],
      'profileImage': profile['profileImage'],
      'verified': profile['verified'] == true ? 1 : 0,
      'onboardingCompleted': profile['onboardingCompleted'] == true ? 1 : 0,
      // Kept as whatever type the source gave us (epoch-ms int from a local
      // insert, ISO-8601 string from a Supabase cache refresh) — SQLite's
      // dynamic typing stores either fine; the UI-side "Member Since"
      // formatter handles both. See _profileFromSupabaseRow's doc.
      if (profile['createdAt'] != null) 'createdAt': profile['createdAt'],
      'updatedAt': SqliteService.nowMs(),
      'synced': synced,
    };
  }

  /// Settings screen's Profile editor — updates the subset of profile
  /// fields the user can change post-registration.
  ///
  /// C1/C2 fix: [phoneNumber] and [email] are now accepted and persisted
  /// here. Previously `ProfileFormController.save()` only ever passed
  /// fullName/municipality/province/farmName/farmerType to this method —
  /// phoneNumber and email were loaded into the form's initial state but
  /// had no way back into storage, so the Profile screen showed them as
  /// permanently `enabled: false` fields with no save path at all. That
  /// matches the user's report that "phone number... wasn't explicitly
  /// covered before."
  ///
  /// Important distinction: this updates the app's own profile RECORD
  /// (the `users` table locally / `profiles` table in Supabase) — the same
  /// record every screen's userProfileProvider reads for display. It does
  /// NOT change the Firebase Auth identity itself (the credential actually
  /// used to sign in). Changing the Firebase Auth email/phone would need a
  /// re-verification flow (email link confirmation / a brand new OTP) that
  /// is out of scope for a plain profile-details edit — if this app ever
  /// needs "change your login phone number" as a distinct security-
  /// sensitive action, that should be its own flow, not bundled into this
  /// general profile form.
  /// SQLite-first, best-effort Supabase mirror, same as every other
  /// repository in this app.
  Future<void> updateProfileFields(
    String uid, {
    required String fullName,
    required String municipality,
    String? province,
    String? farmName,
    String? farmerType,
    String? phoneNumber,
    String? email,
  }) async {
    final updatedAt = SqliteService.nowMs();
    // Same normalization as createUserProfile — see getUidByEmail's doc.
    final normalizedEmail = email?.trim().toLowerCase();
    // upsertUser() does a raw INSERT OR REPLACE — any column left out of the
    // map would come back NULL, not "unchanged" — so the existing row is
    // read first and merged, never partially overwritten.
    Map<String, dynamic> merged = {
      'id': uid,
      'fullName': fullName,
      'municipality': municipality,
      'province': province,
      'farmName': farmName,
      'farmerType': farmerType,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (normalizedEmail != null) 'email': normalizedEmail,
      'updatedAt': updatedAt,
      'synced': 0,
    };
    try {
      final existing = await _sqlite.getUser(uid);
      if (existing != null) merged = {...existing, ...merged};
    } catch (_) {}
    try {
      await _sqlite.upsertUser(merged);
    } catch (_) {}
    try {
      // Bug A10 fix: without this, a profile edit made shortly after
      // registration/login can silently fail its Supabase write (the ID
      // token cached on-device may predate the `role: authenticated` custom
      // claim — see createUserProfile's identical guard above) and then
      // sits at synced:0 until SyncEngine's periodic retry timer next fires
      // (every ~25 minutes) — that wait is exactly the "~30 minute delay
      // before a profile name change takes effect" the user reported, not
      // a deliberate delay anywhere in this method. Refreshing the token
      // first closes that race so the write succeeds on this first attempt
      // instead of silently deferring to the next periodic pass.
      await _forceRefreshIdTokenWithRetry();
      await supabase.from('profiles').update({
        'full_name': fullName,
        'municipality': municipality,
        'province': province,
        'farm_name': farmName,
        'farmer_type': farmerType,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (normalizedEmail != null) 'email': normalizedEmail,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }).eq('firebase_uid', uid);
      merged['synced'] = 1;
      try {
        await _sqlite.upsertUser(merged);
      } catch (_) {}
    } catch (_) {
      // offline — the row above stays synced:0 for a future sync pass
    }
  }

  /// Uploads a new profile photo — same compress-then-upload shape as
  /// PigRepository's weekly photos (3 MB cap via ImageCompressionService,
  /// best-effort Supabase Storage mirror). Requires a matching
  /// `profile-photos` public bucket in Supabase Storage (see
  /// supabase_schema.sql's Storage section) — falls back to a
  /// locally-visible-only avatar (still saved, just not yet synced) if the
  /// bucket/network isn't reachable, same offline-first stance as every
  /// other upload in this app. Returns null only when compression itself
  /// couldn't get the image under the 3 MB cap (caller shows the same
  /// friendly message pig photo uploads already use).
  Future<String?> updateProfileImage(String uid, String localImagePath) async {
    final compressedPath = await ImageCompressionService.compressToPath(
      sourcePath: localImagePath,
      subfolder: 'profile_photos',
      fileName: '${uid}_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      maxEdge: 512,
    );
    if (compressedPath == null) return null;

    String displayPath = compressedPath;
    var synced = 0;
    try {
      // Bug A10 fix: same ID-token-claim race as updateProfileFields above —
      // without this, a photo picked shortly after registration/login can
      // fail its Storage upload/RLS check on the first attempt and only
      // actually reach Supabase up to ~25 minutes later on the next
      // periodic sync pass, which is exactly the reported "~30 minute
      // delay before photo/data upload to Supabase."
      await _forceRefreshIdTokenWithRetry();
      final bytes = await File(compressedPath).readAsBytes();
      final storagePath = '$uid/avatar.jpg';
      await supabase.storage.from('profile-photos').uploadBinary(
            storagePath,
            bytes,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      // Cache-bust so the CircleAvatar actually shows the new photo instead
      // of a CDN/ImageProvider-cached copy of the previous one at the same
      // URL.
      final publicUrl =
          '${supabase.storage.from('profile-photos').getPublicUrl(storagePath)}?v=${DateTime.now().millisecondsSinceEpoch}';
      await supabase.from('profiles').update({
        'profile_image_url': publicUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }).eq('firebase_uid', uid);
      displayPath = publicUrl;
      synced = 1;
    } catch (_) {
      // Offline/upload failure — keep the local compressed file as the
      // display path; resyncPendingAvatar() below retries the upload.
    }

    try {
      final existing = await _sqlite.getUser(uid);
      final merged = {
        ...?existing,
        'id': uid,
        'profileImage': displayPath,
        'updatedAt': SqliteService.nowMs(),
        'synced': synced,
      };
      await _sqlite.upsertUser(merged);
    } catch (_) {}
    return displayPath;
  }

  /// Sync engine support — retries an avatar upload that saved locally but
  /// never reached Supabase (e.g. picked while offline). No-op if the
  /// local profileImage is already a remote URL (nothing pending) or
  /// there's no local row yet.
  Future<void> resyncPendingAvatar(String uid) async {
    try {
      final local = await _sqlite.getUser(uid);
      if (local == null || (local['synced'] as int? ?? 1) == 1) return;
      final path = local['profileImage'] as String?;
      if (path == null || path.startsWith('http')) return;
      await updateProfileImage(uid, path);
    } catch (_) {}
  }

  // ── Registration: email/password creates + signs in, phone OTP LINKS
  // onto that same user (see file header for why). ──

  Future<void> createEmailPasswordUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await credential.user?.updateDisplayName(displayName);
    // Best-effort: email verification runs alongside the phone-OTP step,
    // not instead of it — registration still requires completing the SMS
    // code (see file header). A failure here (e.g. offline, quota) must
    // never block account creation, so it's deliberately swallowed.
    try {
      await credential.user?.sendEmailVerification();
    } catch (_) {}
  }

  /// Re-sends the verification email to the currently signed-in user, for
  /// a "Resend verification email" action in Settings/a verify-email banner.
  /// Returns false (never throws) if there's no signed-in user or the send
  /// fails, so callers can show a neutral message either way.
  Future<bool> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.sendEmailVerification();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Firebase caches `emailVerified` on the local User object — reload()
  /// forces a fresh fetch so a verification completed in another tab/device
  /// is picked up without requiring a full re-login.
  Future<bool> refreshEmailVerifiedStatus() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
    } catch (_) {}
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// True while a verifyPhoneNumber() call is already running — exposed so
  /// the UI/controller layer can disable "Send code"/"Resend" buttons
  /// instead of allowing a second overlapping request (see
  /// PhoneAuthService's class doc for why that matters).
  bool get isPhoneVerificationInFlight => _phoneAuth.isVerificationInFlight;

  /// Starts (or, via [resendToken], resumes) phone verification. Delegates
  /// entirely to [PhoneAuthService] — the sole place in this app that
  /// calls FirebaseAuth.verifyPhoneNumber(), implementing all four
  /// official callbacks. On success, `onCodeSent` fires with both the
  /// verificationId the UI needs to pass to `confirmLinkPhoneCredential`/
  /// `confirmSignInPhoneCredential`, AND a resend token to pass back into
  /// a later call's [resendToken] for a proper "Resend code" (rather than
  /// starting an unrelated new verification session). `onFailed` fires
  /// with a FirebaseAuthException for the UI to map via
  /// mapFirebaseAuthError() — including the Android-only
  /// FirebaseAuthMissingActivityForRecaptchaException case, already
  /// normalized into a stable `missing-activity-for-recaptcha` code by
  /// PhoneAuthService so this layer (and the UI) only ever handles one
  /// exception type.
  Future<void> startPhoneVerification({
    required String phoneE164,
    required void Function(PhoneVerificationCodeSent codeSent) onCodeSent,
    required void Function(FirebaseAuthException error) onFailed,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
    void Function()? onCodeAutoRetrievalTimeout,
    int? resendToken,
  }) {
    return _phoneAuth.verifyPhoneNumber(
      phoneE164: phoneE164,
      resendToken: resendToken,
      onCodeSent: onCodeSent,
      onFailed: onFailed,
      onAutoVerified: (credential) => onAutoVerified?.call(credential),
      onCodeAutoRetrievalTimeout: (_) => onCodeAutoRetrievalTimeout?.call(),
    );
  }

  /// Registration path — LINKS the phone credential onto the currently
  /// signed-in (email/password) user. Never switches the session.
  Future<void> confirmLinkPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
        verificationId: verificationId, smsCode: smsCode);
    return linkPhoneCredential(credential);
  }

  /// Same as [confirmLinkPhoneCredential], but for a [PhoneAuthCredential]
  /// Firebase already built itself — the case when Android's SMS
  /// auto-retrieval verifies the code before the user ever types it (see
  /// startPhoneVerification's verificationCompleted callback). Without this
  /// path, an auto-verified registration would silently do nothing and
  /// leave the user stuck looking at a code-entry screen for a code
  /// they'll never need to type.
  Future<void> linkPhoneCredential(PhoneAuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError(
          'linkPhoneCredential called with no signed-in user — registration flow was interrupted.');
    }
    await user.linkWithCredential(credential);
  }

  /// Login-with-mobile path — a REAL independent sign-in, unlike the
  /// registration link step above.
  Future<UserCredential> confirmSignInPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
        verificationId: verificationId, smsCode: smsCode);
    return signInWithPhoneCredential(credential);
  }

  /// Same as [confirmSignInPhoneCredential], for an already-built
  /// [PhoneAuthCredential] from Android's auto-verification — see
  /// [linkPhoneCredential]'s doc for why this path exists.
  Future<UserCredential> signInWithPhoneCredential(
      PhoneAuthCredential credential) {
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithEmailPassword(
      {required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Forgot Password — pre-checks against Supabase's `profiles` table
  /// before ever calling Firebase, because Firebase's client SDK has
  /// "email enumeration protection" on by default: sendPasswordResetEmail
  /// resolves successfully even for an email with no account. That's
  /// normally good, but it's exactly what would make every email show
  /// "reset link sent!" regardless of whether it's registered. So: only
  /// call Firebase when a real account is found in `profiles` first.
  ///
  /// Returns null if no account was found (caller shows the
  /// "no account was found" message and must NOT call Firebase).
  /// Returns the uid if an account was found and the reset email was sent.
  Future<String?> submitForgotPassword(String email) async {
    final uid = await getUidByEmail(email);
    if (uid == null) return null;
    await _auth.sendPasswordResetEmail(email: email);
    return uid;
  }

  Future<void> signOut() => _auth.signOut();

  // ── Immutable activity log (audit trail) — writes to SQLite first,
  // exactly like recordActivityLog() in auth-main.js. Pushing these rows
  // to Supabase (activity_logs table, insert-only RLS) is the sync
  // engine's job — that's a later slice; this local write already makes
  // every auth event durable and offline-safe, and readable by a future
  // Activity Log screen the moment that slice exists. ──
  //
  // [action]/[status] are the structured fields from the logging system
  // audit's fix #1 — e.g. action: 'LOGIN', status: 'FAILED', paired with
  // a short human-readable [description] ('Wrong password') instead of
  // burying the outcome inside the description text itself
  // ('failed login attempt (wrong password)'). Both are optional and
  // default safely so every one of this method's existing call sites
  // across pigs/expenses/health/settings/notifications keeps compiling
  // and behaving exactly as before without being touched: an omitted
  // [status] defaults to 'SUCCESS' (matching what every one of those
  // call sites already implicitly meant — they only ever fire after the
  // action they describe has already succeeded), and an omitted [action]
  // is derived from [actionType] (e.g. 'expense' -> 'EXPENSE') so every
  // row still gets a real, queryable action value with zero call-site
  // changes required.
  Future<void> recordActivityLog({
    required String uid,
    required String actionType,
    required String description,
    String? username,
    String? action,
    String status = 'SUCCESS',
  }) async {
    if (uid.isEmpty || description.isEmpty) return;
    final id =
        '${uid}_${SqliteService.nowMs()}_${DateTime.now().microsecondsSinceEpoch % 1000000}';
    try {
      await _sqlite.upsertRow('activityLogs', {
        'id': id,
        'uid': uid,
        'actionType': actionType,
        'description': description,
        'username': username ?? '',
        'createdAt': SqliteService.nowMs(),
        'synced': 0,
        'action': action ?? actionType.toUpperCase(),
        'status': status,
      });
    } catch (_) {
      // non-fatal — a missed log entry never blocks the actual auth action
    }
  }
}
