/* ══════════════════════════════════════════════════════════════════════
   ASF — Real Firebase Authentication + Supabase (Postgres + Storage)
   ══════════════════════════════════════════════════════════════════════
   This is the ONLY file that talks to Firebase, and the only file (besides
   src/sync-engine.js) that talks to Supabase. It's a `type="module"`
   script (see the <script type="module" src="./src/auth-main.js"> tag near
   the end of index.html), bundled by Vite so it can `import` npm packages.

   Hybrid backend, per integration_prompt.md: Firebase Authentication is
   the ONLY Firebase product in use here — accounts, sessions, and OTP/
   password login. Firestore and Firebase Storage are NOT used; the
   cloud database and file storage are both Supabase (see
   src/supabase-config.js and src/sync-engine.js). This keeps the whole
   project on Firebase's free Spark plan (Cloud Firestore/Storage would
   otherwise nudge toward the paid Blaze plan) while still getting a real
   Postgres database and a real Storage bucket from Supabase's free tier.

   It exposes everything the classic inline script in index.html needs on
   `window.AsfAuth`, and reads a few things back from that classic script via
   `window.DB` / `window.ck` / `window.setCurrentUid` (see the "Bridge to
   src/auth-main.js" comment in index.html, right after `const ck = ...`).

   Why @capacitor-firebase/authentication instead of the plain Firebase Web
   SDK's `signInWithPhoneNumber` + `RecaptchaVerifier`?
   The web SDK's phone auth flow is designed for browsers — it shows a
   reCAPTCHA challenge and needs the page served from an authorized HTTPS
   domain. Inside a native Capacitor WebView that flow is unreliable across
   devices. @capacitor-firebase/authentication wraps the NATIVE Firebase
   Auth SDKs instead (Play Integrity on Android, silent APNs push on iOS),
   which is what real published apps use for phone auth. Email/password and
   session persistence go through the same plugin so the native and JS SDK
   layers never drift out of sync (that's what `skipNativeAuth: false` in
   capacitor.config.json enables).
   ══════════════════════════════════════════════════════════════════════ */

import { initializeApp } from 'firebase/app';
import { FirebaseAuthentication } from '@capacitor-firebase/authentication';
import { Preferences } from '@capacitor/preferences';
import { App } from '@capacitor/app';

import { firebaseConfig, isFirebaseConfigured } from './firebase-config.js';
import { supabase } from './supabase-config.js';
import * as SqliteDB from './sqlite-db.js';
import * as SyncEngine from './sync-engine.js';
import { scheduleAllReminders } from './notifications.js';

// "Remember Login" (spec §4): a plain Capacitor Preferences flag, separate
// from Firebase's own session persistence (which always persists — that's
// existing, unrelated behavior). When the user unchecks Remember Login on
// the Login screen, this is set to 'false' and checked once at the next
// app boot (see init() below) to force a sign-out BEFORE the
// authStateChange listener would otherwise auto-log them back in, so they
// land on the Login screen instead of the Dashboard. Any other value (or
// no stored value at all, e.g. a user who registered but never touched a
// login screen yet) is treated as "remembered", matching the app's
// pre-existing always-persist behavior.
const REMEMBER_KEY = 'asf_remember_login';

// Resolves to `null` instead of throwing/hanging if `promise` doesn't
// settle within `ms` — used so a first-login-detection Supabase read never
// stalls the boot path if the device is offline (see resolveOnboardingStatus).
function withTimeout(promise, ms){
  return Promise.race([
    promise,
    new Promise((resolve) => setTimeout(() => resolve(null), ms)),
  ]);
}

/* initializeApp() is still required even though Firestore/Storage aren't
   used — @capacitor-firebase/authentication's web implementation attaches
   to this same Firebase app instance for Auth to work in a browser (native
   Android/iOS use the platform's real Firebase SDK directly and don't
   strictly need this, but initializing it is harmless either way). */
const app = initializeApp(firebaseConfig);

/* Local SQLite is the app's real offline data store — start opening/
   creating it immediately, in parallel with everything else below, so
   it's ready by the time hydrateAppFromProfile() needs it. */
SqliteDB.initSqlite();

/* ── Small helpers ── */
const $ = (id) => document.getElementById(id);
const T = (key, vars) => (window.t ? window.t(key, vars) : key);
const toast = (msg) => { if (window.showSyncToast) window.showSyncToast(msg); };
const loading = (btnId, on) => { if (window.setBtnLoading) window.setBtnLoading(btnId, on); };

/* Default country for un-prefixed local numbers — Philippines (+63), since
   that's this app's audience. A number typed as "0917 123 4567" or
   "917 123 4567" becomes "+639171234567"; anything already starting with
   "+" is left as-is (just stripped of spaces/dashes). */
function formatPhoneE164(raw){
  let s = String(raw || '').trim().replace(/[\s-()]/g, '');
  if (s.startsWith('+')) return s;
  s = s.replace(/^0+/, '');           // drop leading 0 (local PH format)
  if (s.startsWith('63')) return '+' + s;
  return '+63' + s;
}
function isValidPhone(e164){
  return /^\+[1-9]\d{7,14}$/.test(e164); // E.164: + and 8–15 digits total
}

/* ── Firebase error → translation key ──
   Covers everything the spec calls out (invalid phone/OTP, expired OTP, too
   many requests, network error, Firebase unavailable, phone/email already in
   use, user not found) plus the other codes Firebase actually throws in
   practice, so nothing falls through to a raw, unfriendly error string. */
function mapAuthError(err){
  const code = err && err.code ? String(err.code).replace(/^auth\//, '') : '';
  const map = {
    'invalid-phone-number': 'auth-fb-invalid-phone',
    'missing-phone-number': 'auth-fb-invalid-phone',
    'invalid-verification-code': 'auth-fb-invalid-otp',
    'missing-verification-code': 'auth-fb-invalid-otp',
    'code-expired': 'auth-fb-otp-expired',
    'session-expired': 'auth-fb-otp-expired',
    'too-many-requests': 'auth-fb-too-many-requests',
    'quota-exceeded': 'auth-fb-too-many-requests',
    'network-request-failed': 'auth-fb-network',
    'unavailable': 'auth-fb-unavailable',
    'internal-error': 'auth-fb-unavailable',
    'phone-number-already-exists': 'auth-fb-phone-in-use',
    'credential-already-in-use': 'auth-fb-phone-in-use',
    'email-already-in-use': 'auth-fb-email-in-use',
    'account-exists-with-different-credential': 'auth-fb-email-in-use',
    'user-not-found': 'auth-fb-user-not-found',
    'user-disabled': 'auth-fb-user-disabled',
    'invalid-credential': 'auth-fb-wrong-password',
    'wrong-password': 'auth-fb-wrong-password',
    'weak-password': 'auth-fb-weak-password',
    'invalid-email': 'auth-fb-invalid-email',
    'requires-recent-login': 'auth-fb-requires-recent-login',
    'popup-closed-by-user': 'auth-fb-popup-closed',
    'cancelled': 'auth-fb-popup-closed',
  };
  return T(map[code] || 'auth-fb-generic') + (code ? ` (${code})` : '');
}

/* ── Supabase: profiles row + the phone-uniqueness lookup ──
   Row Level Security is currently permissive ("Option A" in
   supabase_schema (1).sql) — access control is enforced here in the app
   by always filtering/writing with the signed-in Firebase uid, per
   integration_prompt.md §3. Every query below does that explicitly. */
async function phoneNumberIsTaken(phoneE164){
  const { data, error } = await supabase.from('profiles').select('firebase_uid').eq('phone_number', phoneE164).maybeSingle();
  if (error) console.warn('[ASF] phoneNumberIsTaken query failed:', error);
  return !!data;
}
/* Best-effort uid lookups used ONLY to attribute a "failed login attempt"
   log entry to the right account (see recordActivityLog below) — never
   used to bypass or shortcut the real Firebase Auth check itself. Returns
   null (never throws) if the email/phone doesn't match any account, or if
   the lookup itself fails (e.g. offline), in which case the failed attempt
   simply isn't logged rather than blocking the login error from surfacing. */
async function getUidByEmail(email){
  try {
    const { data } = await supabase.from('profiles').select('firebase_uid').eq('email', email).maybeSingle();
    return data?.firebase_uid || null;
  } catch (_) { return null; }
}
async function getUidByPhone(phoneE164){
  try {
    const { data } = await supabase.from('profiles').select('firebase_uid').eq('phone_number', phoneE164).maybeSingle();
    return data?.firebase_uid || null;
  } catch (_) { return null; }
}
async function createUserProfile(uid, { fullName, phoneNumber, municipality, email }){
  const { error } = await supabase.from('profiles').upsert({
    firebase_uid: uid, full_name: fullName, phone_number: phoneNumber,
    municipality, email, verified: true, role: 'raiser',
    profile_image_url: null, onboarding_completed: false,
    updated_at: new Date().toISOString(),
  }, { onConflict: 'firebase_uid' });
  if (error) console.error('[ASF] Supabase profile create failed:', error);
  // Seed the local SQLite users row immediately too, so if the very next
  // launch happens to be offline, the profile is already there rather than
  // waiting on the next successful background enrichment.
  try {
    await SqliteDB.upsertUser({
      id: uid, fullName, phoneNumber, municipality, email,
      role: 'raiser', profileImage: null, verified: 1, onboardingCompleted: 0,
      createdAt: SqliteDB.nowMs(), updatedAt: SqliteDB.nowMs(), synced: 1,
    });
  } catch (err){
    console.warn('[ASF SQLite] failed to seed local user row after registration:', err);
  }
}
async function getUserProfile(uid){
  const { data, error } = await supabase.from('profiles').select('*').eq('firebase_uid', uid).maybeSingle();
  if (error){ console.warn('[ASF] getUserProfile failed:', error); return null; }
  if (!data) return null;
  return {
    fullName: data.full_name, phoneNumber: data.phone_number, municipality: data.municipality,
    email: data.email, role: data.role, profileImage: data.profile_image_url, verified: data.verified,
    onboardingCompleted: !!data.onboarding_completed,
  };
}

/* Marks onboarding as done both in Supabase (source of truth per spec §6)
   and in the local SQLite cache (so an offline relaunch right after
   onboarding still skips straight to the Dashboard). Called from
   index.html once the Pig Profile Setup + Set Reminders steps are saved. */
async function markOnboardingCompleted(uid){
  try {
    const { error } = await supabase.from('profiles')
      .update({ onboarding_completed: true, updated_at: new Date().toISOString() })
      .eq('firebase_uid', uid);
    if (error) console.warn('[ASF] markOnboardingCompleted Supabase update failed:', error);
  } catch (err){
    console.warn('[ASF] markOnboardingCompleted Supabase update threw:', err);
  }
  try {
    await SqliteDB.upsertUser({ id: uid, onboardingCompleted: 1, updatedAt: SqliteDB.nowMs() });
  } catch (err){
    console.warn('[ASF SQLite] markOnboardingCompleted local update failed:', err);
  }
}

/* First Login Detection (spec §6). Prefers a fresh Supabase read (the
   documented source of truth) so a returning user who completed
   onboarding on a DIFFERENT device still skips it here — but never lets a
   slow/unreachable network stall boot: falls back to the local SQLite
   cache (correct for a device that has seen this uid before) if Supabase
   doesn't answer within 3s, keeping "app must open normally offline" true. */
async function resolveOnboardingStatus(uid){
  try {
    const profile = await withTimeout(getUserProfile(uid), 3000);
    if (profile){
      SqliteDB.upsertUser({
        id: uid, onboardingCompleted: profile.onboardingCompleted ? 1 : 0, updatedAt: SqliteDB.nowMs(),
      }).catch(() => {});
      return !!profile.onboardingCompleted;
    }
  } catch (err){
    console.warn('[ASF] resolveOnboardingStatus Supabase check failed, using local cache:', err);
  }
  const localUser = await SqliteDB.getUser(uid);
  return !!(localUser && localUser.onboardingCompleted);
}

/* ══════════════════════════════════════════════════════════════════════
   LOGICAL KEY → TABLE MAP
   ══════════════════════════════════════════════════════════════════════
   The rest of the app (index.html's ~4500-line classic <script>) was built
   entirely around synchronous localStorage (window.DB.get/set), with 100+
   call sites reading and writing it directly. Rewriting every one of those
   into an async data layer would be a huge, high-risk change to code that
   already works. So localStorage/MEM (window.DB) stays the instant,
   always-available cache every existing call site reads from — and every
   write is ALSO mirrored into SQLite (see "SQLITE WRITE-THROUGH" below),
   which is the app's real offline-durable store and the only thing
   src/sync-engine.js talks to Supabase on behalf of.

   COLLECTION_DOC_MAP here is just the list of logical ck() keys this
   bridge watches for — writeToSqlite() below decides which SQLite table
   each one actually lands in (see src/sqlite-db.js for the table shapes,
   and src/sync-engine.js for how each table's rows eventually reach the
   matching Supabase table, per row or per (firebase_uid, subkey)). */
const COLLECTION_DOC_MAP = {
  pigs:            ['pigs', '_registry'],
  pigBatchProfile: ['pigs', '_batchProfile'],
  healthLogs:      ['healthLogs', '_all'],
  feedLogs:        ['feedingLogs', '_all'],
  expenses:        ['expenses', '_all'],
  weightLogs:      ['growthLogs', '_weightLogs'],
  pigWeightLogs:   ['growthLogs', '_perPigWeights'],
  adgFcrSnapshot:  ['growthLogs', '_adgFcrSnapshot'],
  pigWeeklyImages: ['pigs', '_weeklyImages'],
};
// Smaller, low-volume state that doesn't warrant its own collection — mirrored
// as nested fields on the users/{uid} doc itself instead (still fully
// per-uid-scoped and durable, just not one of the seven named collections).
const LOCALSTATE_KEYS = new Set([
  'farmerProfile', 'notifPrefs', 'currentDay', 'dayLogs', 'weeklyTasks', 'vetContacts', 'appLang',
]);
const ALL_SYNCED_KEYS = [...Object.keys(COLLECTION_DOC_MAP), ...LOCALSTATE_KEYS];

let liveUid = null;               // set/cleared by the authStateChange listener

/* ══════════════════════════════════════════════════════════════════════
   SQLITE WRITE-THROUGH — offline-first local persistence
   ══════════════════════════════════════════════════════════════════════
   Every window.DB.set() call is mirrored into SQLite (src/sqlite-db.js),
   marked synced=0, and a debounced sync run is scheduled. This REPLACES
   a direct-to-cloud push on every write, which would have no queue, no
   retry, and no conflict check — fine when always online, not good enough
   for "no user data should be lost because of network interruptions."
   Now: SQLite is written to immediately and unconditionally (works
   offline), and src/sync-engine.js is the ONLY thing that talks to
   Supabase for this data, whenever connectivity allows it. */
const AGGREGATE_TABLE_MAP = { healthLogs: 'healthLogs', feedLogs: 'feedingLogs', expenses: 'expenses' };
const GROWTH_SUBKEY_MAP = { weightLogs: 'weightLogs', pigWeightLogs: 'perPigWeights', adgFcrSnapshot: 'adgFcrSnapshot' };
const SETTINGS_KEYS_SET = new Set(['farmerProfile', 'pigBatchProfile', 'notifPrefs', 'currentDay', 'dayLogs', 'weeklyTasks', 'vetContacts', 'appLang']);

async function writeToSqlite(uid, logicalKey, value){
  const now = SqliteDB.nowMs();
  try {
    if (logicalKey === 'pigs' && Array.isArray(value)){
      for (const pig of value){
        if (!pig || pig.id == null) continue;
        await SqliteDB.upsertRow('pigs', { id: String(pig.id), uid, data: JSON.stringify(pig), updatedAt: now, synced: 0, deleted: 0 });
      }
      return;
    }
    if (logicalKey === 'pigWeeklyImages' && Array.isArray(value)){
      for (const img of value){
        if (!img || img.id == null) continue;
        const isRemote = typeof img.image_url === 'string' && img.image_url.startsWith('http');
        await SqliteDB.upsertRow('weeklyPigImages', {
          id: String(img.id), uid, pigId: img.pig_id || null, weekNumber: img.week_number ?? null,
          localUri: img.image_url || null, remoteUrl: isRemote ? img.image_url : null,
          captureDate: img.capture_date || null, notes: img.notes || '',
          updatedAt: now, synced: 0, uploadAttempts: 0, deleted: 0,
        });
      }
      return;
    }
    if (AGGREGATE_TABLE_MAP[logicalKey]){
      await SqliteDB.setAggregate(AGGREGATE_TABLE_MAP[logicalKey], uid, 'main', value, { updatedAt: now, synced: false });
      return;
    }
    if (GROWTH_SUBKEY_MAP[logicalKey]){
      await SqliteDB.setAggregate('growthLogs', uid, GROWTH_SUBKEY_MAP[logicalKey], value, { updatedAt: now, synced: false });
      return;
    }
    if (SETTINGS_KEYS_SET.has(logicalKey)){
      await SqliteDB.setAggregate('settings', uid, logicalKey, value, { updatedAt: now, synced: false });
      return;
    }
  } catch (err){
    console.warn('[ASF SQLite] writeToSqlite failed for', logicalKey, err);
  }
}

/* Batches rapid successive writes (e.g. typing in a field that saves on
   every keystroke) into one sync run instead of firing a network round
   trip per keystroke — "using batched synchronization where appropriate." */
let syncDebounceTimer = null;
function scheduleDebouncedSync(uid){
  clearTimeout(syncDebounceTimer);
  syncDebounceTimer = setTimeout(() => SyncEngine.runSync(uid, { silent: true }), 800);
}

/* Patches window.DB.set ONCE so every local write the app already makes is
   also written through to SQLite (always) and queued for background sync
   to Supabase (when a user is signed in and connectivity allows it).
   Idempotent — safe to call multiple times (e.g. across sign-in/sign-out). */
let originalDbSet = null; // the pre-patch window.DB.set — used by onRemoteUpdate below to
                           // apply data PULLED from Supabase without re-marking it dirty
                           // (which would otherwise create an endless pull→push→pull loop)
function installOfflineSync(){
  if (!window.DB || window.DB.__asfSyncInstalled) return;
  originalDbSet = window.DB.set.bind(window.DB);
  window.DB.set = function(fullKey, value){
    originalDbSet(fullKey, value);
    if (!liveUid) return value;
    for (const logicalKey of ALL_SYNCED_KEYS){
      if (fullKey === window.ck(logicalKey)){
        writeToSqlite(liveUid, logicalKey, value).then(() => scheduleDebouncedSync(liveUid));
        break;
      }
    }
    // Reminder prefs changed (Settings ▸ Notifications, or onboarding's Set
    // Reminders step) — reschedule real local notifications immediately.
    // scheduleAllReminders() itself checks OS permission and no-ops if it
    // hasn't been granted yet, so this is always safe to call.
    if (fullKey === window.ck('notifPrefs')){
      scheduleAllReminders(value).catch((err) => console.warn('[ASF Notifications] reschedule failed:', err));
    }
    return value;
  };
  window.DB.__asfSyncInstalled = true;
}

/* Applies data the sync engine just pulled from Supabase straight to the
   UI-facing cache (localStorage/MEM), bypassing the dirty-marking patch
   above — this data is already synced by definition (it just came FROM
   the cloud), so re-queuing it for another push would be pointless at
   best and a pull→push→pull loop at worst. */
function applyRemoteUpdateLocally(logicalKey, value){
  if (!window.ck) return;
  const fullKey = window.ck(logicalKey);
  if (originalDbSet) originalDbSet(fullKey, value);
  else if (window.DB) window.DB.set(fullKey, value); // installOfflineSync not run yet — safe fallback
}

/* Queues a single Critical health notification. Written to SQLite FIRST
   (synced=0) so it's captured even if this happens offline — the app's
   other notifications (weight alerts, pending tasks, weigh-in due) are
   derived live from current state rather than persisted, so there's
   nothing to queue for those; a Critical health alert is the one notable
   EVENT worth a durable, offline-safe record. */
async function recordCriticalNotification(uid, log){
  const id = String(log.id || Date.now());
  try {
    await SqliteDB.upsertRow('notifications', {
      id, uid, type: 'health-critical',
      data: JSON.stringify({ healthLogId: log.id ?? null, day: log.day ?? null }),
      read: 0, createdAt: SqliteDB.nowMs(), synced: 0,
    });
    scheduleDebouncedSync(uid);
  } catch (err){
    console.warn('[ASF SQLite] failed to queue critical notification:', err);
  }
}
window.AsfRecordCriticalNotification = (log) => { if (liveUid) recordCriticalNotification(liveUid, log); };

/* ══════════════════════════════════════════════════════════════════════
   IMMUTABLE ACTIVITY LOG (audit trail — Settings ▸ Activity Log)
   ══════════════════════════════════════════════════════════════════════
   Append-only by design end to end: written once here, never edited or
   deleted by any code path in this app, pushed with upsert+ignoreDuplicates
   (never a real UPDATE) in src/sync-engine.js's syncActivityLogs(), and
   backed by a Supabase table whose RLS has only INSERT + SELECT policies —
   there is no UPDATE/DELETE policy at all, so tampering through the app's
   own access path is structurally impossible, not just hidden in the UI
   (see supabase_schema.sql's activity_logs section for the full reasoning).

   Every entry is written to SQLite FIRST (synced=0), exactly like
   recordCriticalNotification() above, so an action logged while offline is
   never lost — it's picked up by the normal background sync loop the same
   way every other queued write is. */
function currentDisplayName(){
  try {
    const farmer = (window.DB && window.ck) ? window.DB.get(window.ck('farmerProfile')) : null;
    return (farmer && farmer.name) || '';
  } catch (_) { return ''; }
}
async function recordActivityLog(uid, actionType, description, usernameOverride){
  if (!uid || !description) return;
  const username = usernameOverride || currentDisplayName();
  const id = `${uid}_${SqliteDB.nowMs()}_${Math.random().toString(36).slice(2, 8)}`;
  try {
    await SqliteDB.upsertRow('activityLogs', {
      id, uid, actionType: actionType || 'other', description, username: username || '',
      createdAt: SqliteDB.nowMs(), synced: 0,
    });
    scheduleDebouncedSync(uid);
  } catch (err){
    console.warn('[ASF SQLite] failed to queue activity log:', err);
  }
}
// Called from index.html for every in-app action (task check, weigh-in,
// health log CRUD, settings change, dashboard view) — always the CURRENTLY
// signed-in user, so this is deliberately gated on liveUid rather than
// taking a uid parameter. Auth events (login/logout/registration/failed
// attempts) are logged directly from the functions below instead, since
// those happen right at the uid boundary (liveUid isn't set yet on login,
// or is about to be cleared on logout).
window.AsfLogActivity = (actionType, description) => { if (liveUid) recordActivityLog(liveUid, actionType, description); };

/* Merges the local SQLite copy (always available, including anything
   queued while offline) with a fresh Supabase read (self-uid scoped, so
   this also picks up actions logged from this same account on a DIFFERENT
   device) for the Settings ▸ Activity Log list. Deduplicates on the local
   row's own id (mirrored into Supabase as app_entry_id) so an
   already-synced local row never appears twice. Never throws — an offline
   Supabase fetch just falls back to local-only, matching this app's usual
   offline-first read pattern. */
async function getActivityLogsCombined(uid){
  if (!uid) return [];
  const localRows = await SqliteDB.getActivityLogs(uid);
  const localIds = new Set(localRows.map(r => r.id));
  const normalizedLocal = localRows.map(r => ({
    id: r.id, actionType: r.actionType || 'other', description: r.description || '',
    username: r.username || '', timestamp: r.createdAt,
  }));
  let normalizedRemote = [];
  try {
    const { data, error } = await supabase.from('activity_logs')
      .select('app_entry_id, username, action_type, description, created_at')
      .eq('firebase_uid', uid).order('created_at', { ascending: false }).limit(1000);
    if (error) throw error;
    normalizedRemote = (data || [])
      .filter(r => !r.app_entry_id || !localIds.has(r.app_entry_id))
      .map(r => ({
        id: r.app_entry_id || `remote_${r.created_at}_${Math.random().toString(36).slice(2, 6)}`,
        actionType: r.action_type || 'other', description: r.description || '',
        username: r.username || '', timestamp: new Date(r.created_at).getTime(),
      }));
  } catch (err){
    console.warn('[ASF] getActivityLogsCombined: Supabase read skipped (likely offline):', err);
  }
  return [...normalizedLocal, ...normalizedRemote].sort((a, b) => b.timestamp - a.timestamp);
}
window.AsfGetActivityLogs = () => getActivityLogsCombined(liveUid);

/* ══════════════════════════════════════════════════════════════════════
   IN-APP UPDATE CHECKER (sideloaded APK — no Play Store)
   ══════════════════════════════════════════════════════════════════════
   There's no store to check against, so this checks the app_releases
   table directly (see supabase_schema.sql §5) on every launch: whoever
   publishes a new build inserts one row there (version + a public APK
   download URL). If that row's version is newer than what's actually
   running, index.html shows a prompt with both version numbers and a
   Download & Install button that just opens the APK URL — Android's own
   download manager + package installer take it from there exactly like
   downloading an APK from any website, no extra native permissions or
   plugins needed. Never nags about a version the user already dismissed
   (tracked in Preferences, native-side, separate from any account), and
   never runs at all if there's no network — this is a nice-to-have
   check, never something that blocks or slows down opening the app. */
const DISMISSED_VERSION_KEY = 'asf_update_dismissed_version';
function compareVersions(a, b){
  const pa = String(a||'0').split('.').map(n => parseInt(n,10) || 0);
  const pb = String(b||'0').split('.').map(n => parseInt(n,10) || 0);
  const len = Math.max(pa.length, pb.length);
  for (let i=0; i<len; i++){
    const da = pa[i]||0, db = pb[i]||0;
    if (da !== db) return da - db;
  }
  return 0;
}
async function getRunningAppVersion(){
  try {
    const info = await App.getInfo();
    if (info && info.version) return info.version;
  } catch (_) {
    // Not running natively (plain web) — App.getInfo() isn't available.
  }
  return '1.0'; // web fallback — keep in sync with android/app/build.gradle's versionName
}
window.AsfCheckForUpdate = async function(){
  try {
    const currentVersion = await getRunningAppVersion();
    const { data: latest, error } = await supabase.from('app_releases')
      .select('version, apk_url, notes').order('published_at', { ascending: false }).limit(1).maybeSingle();
    if (error || !latest) return null;
    if (compareVersions(latest.version, currentVersion) <= 0) return null; // already on latest (or ahead, e.g. a dev build)

    const { value: dismissed } = await Preferences.get({ key: DISMISSED_VERSION_KEY });
    if (dismissed === latest.version) return null; // user already said "later" for this exact version

    return { currentVersion, latestVersion: latest.version, apkUrl: latest.apk_url, notes: latest.notes || '' };
  } catch (err){
    console.warn('[ASF] update check skipped (likely offline):', err);
    return null;
  }
};
window.AsfDismissUpdate = async function(version){
  try { await Preferences.set({ key: DISMISSED_VERSION_KEY, value: version }); } catch (_) {}
};

/* ══════════════════════════════════════════════════════════════════════
   BOOT HYDRATION — SQLite first, Supabase as best-effort enrichment
   ══════════════════════════════════════════════════════════════════════
   This is the core of "allow access while offline if a valid session
   exists": populate window.DB from SQLite (a local read, works with zero
   network) BEFORE calling showAppShell(), so the Dashboard renders
   immediately regardless of connectivity. Supabase is only consulted
   afterward, in the background, via SyncEngine.runSync() — if it fails or
   times out because the device is offline, the UI has already rendered
   from SQLite and is completely unaffected. */
async function hydrateFromSqlite(uid){
  const localUser = await SqliteDB.getUser(uid);
  if (localUser){
    window.DB.set(window.ck('farmerProfile'), {
      // Never a hardcoded placeholder name — an empty string here correctly
      // falls through to getFarmerProfile()'s own '' default (index.html),
      // which every display site (Dashboard greeting, Settings, drawer,
      // avatar initial) already treats as "no name yet" rather than
      // rendering a fake identity like "Farmer" or "Juan dela Cruz".
      name: localUser.fullName || '',
      municipality: (localUser.municipality || '').split(',')[0]?.trim() || '',
      province: (localUser.municipality || '').split(',').slice(1).join(',').trim() || '',
      farmerType: 'Backyard Raiser',
      photo: localUser.profileImage || null,
    });
  }
  // Tells hydrateAppFromProfile() whether it already has a real name to
  // render, or whether it should wait on a bounded Supabase fetch first
  // (see the "no name yet" branch there) instead of painting a blank
  // greeting and silently fixing it a second or two later.
  const hasLocalName = !!(localUser && localUser.fullName);
  if (!window.DB.get(window.ck('pigBatchProfile'))){
    // No hardcoded fallback here — if nothing was ever synced for this uid
    // (a brand-new account before onboarding has run), leave this key unset
    // entirely. index.html's getPigBatchProfile() already defaults to a
    // blank/zeroed profile in that case, never a fictional one like Bigas.
    const cached = await SqliteDB.getAggregate('settings', uid, 'pigBatchProfile');
    if (cached) window.DB.set(window.ck('pigBatchProfile'), cached);
  }
  // Restore every other settings subkey + the 4 aggregate log categories +
  // the pig registry from SQLite, if present — a previously-synced
  // returning user sees their real data instantly, fully offline.
  for (const subkey of SETTINGS_KEYS_SET){
    if (subkey === 'pigBatchProfile') continue; // handled above
    const cached = await SqliteDB.getAggregate('settings', uid, subkey);
    if (cached !== null) window.DB.set(window.ck(subkey), cached);
  }
  const feedLogs = await SqliteDB.getAggregate('feedingLogs', uid, 'main');
  if (feedLogs !== null) window.DB.set(window.ck('feedLogs'), feedLogs);
  const healthLogs = await SqliteDB.getAggregate('healthLogs', uid, 'main');
  if (healthLogs !== null) window.DB.set(window.ck('healthLogs'), healthLogs);
  const expenses = await SqliteDB.getAggregate('expenses', uid, 'main');
  if (expenses !== null) window.DB.set(window.ck('expenses'), expenses);
  const weightLogs = await SqliteDB.getAggregate('growthLogs', uid, 'weightLogs');
  if (weightLogs !== null) window.DB.set(window.ck('weightLogs'), weightLogs);
  const pigWeightLogs = await SqliteDB.getAggregate('growthLogs', uid, 'perPigWeights');
  if (pigWeightLogs !== null) window.DB.set(window.ck('pigWeightLogs'), pigWeightLogs);
  const adgFcrSnapshot = await SqliteDB.getAggregate('growthLogs', uid, 'adgFcrSnapshot');
  if (adgFcrSnapshot !== null) window.DB.set(window.ck('adgFcrSnapshot'), adgFcrSnapshot);

  const pigRows = await SqliteDB.getRows('pigs', uid);
  if (pigRows.length){
    const pigs = pigRows.map(r => { try { return JSON.parse(r.data); } catch(_) { return null; } }).filter(Boolean);
    if (pigs.length) window.DB.set(window.ck('pigs'), pigs);
  }
  const imageRows = await SqliteDB.getRows('weeklyPigImages', uid);
  if (imageRows.length){
    const images = imageRows.map(r => ({
      id: Number(r.id) || r.id, pig_id: r.pigId, week_number: r.weekNumber,
      image_url: r.remoteUrl || r.localUri, capture_date: r.captureDate, notes: r.notes || '',
      created_at: null, updated_at: null, synced: !!r.synced,
    }));
    window.DB.set(window.ck('pigWeeklyImages'), images);
  }

  return hasLocalName;
}

/* Best-effort background enrichment from Supabase — only fills in the
   farmer-profile fields the FIRST time a device ever sees this uid (i.e.
   nothing local yet); on every subsequent launch SQLite is already the
   source of truth and this just confirms nothing's missing. Never awaited
   by the boot path — a slow or failed network call here must never delay
   or break rendering the app from local data. */
async function enrichFromCloudInBackground(uid){
  try {
    const profile = await getUserProfile(uid);
    if (profile){
      await SqliteDB.upsertUser({
        id: uid, fullName: profile.fullName || '', phoneNumber: profile.phoneNumber || '',
        municipality: profile.municipality || '', email: profile.email || '',
        role: profile.role || 'raiser', profileImage: profile.profileImage || null,
        verified: profile.verified ? 1 : 0, createdAt: SqliteDB.nowMs(), updatedAt: SqliteDB.nowMs(), synced: 1,
      });
      // Also push straight into the live UI-facing cache (window.DB), not
      // just SQLite. Closes the registration race where the
      // authStateChange-triggered hydrateFromSqlite() can run BEFORE
      // createUserProfile()'s Supabase/SQLite writes finish (nothing is
      // shown in that split second either way, since blank is the safe
      // fallback — see hydrateFromSqlite() — but this makes sure the
      // account's real data appears as soon as it exists, without waiting
      // for a manual refresh or app restart). Guarded by uid === liveUid so
      // a slow background fetch can never clobber a DIFFERENT account's
      // data if the user has since logged out/switched accounts.
      if (uid === liveUid && window.DB && window.ck){
        const parts = (profile.municipality || '').split(',');
        window.DB.set(window.ck('farmerProfile'), {
          name: profile.fullName || '',
          municipality: (parts[0] || '').trim(),
          province: parts.slice(1).join(',').trim(),
          farmerType: 'Backyard Raiser',
          photo: profile.profileImage || null,
        });
        if (typeof window.loadData === 'function') window.loadData();
      }
    }
  } catch (err){
    console.warn('[ASF] background profile enrichment skipped (likely offline):', err);
  }
  // Kick off the full sync engine run — pushes anything queued while
  // offline and pulls any newer remote data, entirely in the background.
  SyncEngine.runSync(uid);
}

/* Pull the local (then, best-effort, cloud) profile into the existing
   app's local data layer (window.DB / window.ck — see the bridge in
   index.html) so the rest of the app, which was built around
   localStorage, keeps working unmodified. */
async function hydrateAppFromProfile(uid){
  window.setCurrentUid(uid);   // re-namespaces every ck() key to this uid
  liveUid = uid;
  installOfflineSync();
  SyncEngine.setActiveUid(uid);

  // SQLite hydration is awaited — it's a fast local read, and the UI
  // should never render with stale/missing data if a local copy exists.
  const hasLocalName = await hydrateFromSqlite(uid);

  // If this device has never cached this account's profile yet (a fresh
  // install, a cleared app, or a first login on a new device — the
  // account itself may be months old on Supabase), don't paint the first
  // frame with a blank "Good morning, 👋" and quietly fix it a second or
  // two later via enrichFromCloudInBackground(). Instead, block on ONE
  // bounded Supabase fetch (same 3s budget used elsewhere in this file,
  // e.g. resolveOnboardingStatus) and seed SQLite + the live UI cache from
  // it before the first render, exactly per the Login → SQLite → (miss) →
  // Supabase → save → render sequence. Fully offline-safe: withTimeout()
  // resolves to null (never throws) on timeout/no-network, so a first
  // login with no connectivity still falls through to the normal blank
  // defaults instead of hanging.
  if (!hasLocalName && uid === liveUid){
    try {
      // Fetched together, within the SAME 3s budget, rather than fetching
      // the farmer profile alone: a cold device (no local SQLite cache for
      // this uid) previously only pre-rendered the farmer's name/photo
      // this way, leaving Pig/Batch Profile (Number of Pigs, Starting
      // Weight, etc.) and the pigs[] list to whatever
      // enrichFromCloudInBackground()'s fire-and-forget sync produced —
      // which could still be empty/zero for the first render or two right
      // after login. That's the concrete mechanism behind "Number of pigs
      // incorrect immediately after login" — fixed by blocking on all
      // three together before the first loadData() call below.
      const [profile, batchRow, pigRows] = await withTimeout(Promise.all([
        getUserProfile(uid),
        supabase.from('settings').select('data').eq('firebase_uid', uid).eq('subkey', 'pigBatchProfile').maybeSingle().then(r => r.data?.data || null).catch(() => null),
        supabase.from('pigs').select('*').eq('firebase_uid', uid).then(r => r.data || []).catch(() => []),
      ]), 3000) || [null, null, []];

      if (uid === liveUid && profile){
        await SqliteDB.upsertUser({
          id: uid, fullName: profile.fullName || '', phoneNumber: profile.phoneNumber || '',
          municipality: profile.municipality || '', email: profile.email || '',
          role: profile.role || 'raiser', profileImage: profile.profileImage || null,
          verified: profile.verified ? 1 : 0, createdAt: SqliteDB.nowMs(), updatedAt: SqliteDB.nowMs(), synced: 1,
        });
        const parts = (profile.municipality || '').split(',');
        window.DB.set(window.ck('farmerProfile'), {
          name: profile.fullName || '',
          municipality: (parts[0] || '').trim(),
          province: parts.slice(1).join(',').trim(),
          farmerType: 'Backyard Raiser',
          photo: profile.profileImage || null,
        });
      }
      if (uid === liveUid && batchRow){
        await SqliteDB.setAggregate('settings', uid, 'pigBatchProfile', batchRow, { updatedAt: SqliteDB.nowMs(), synced: true });
        window.DB.set(window.ck('pigBatchProfile'), batchRow);
      }
      if (uid === liveUid && pigRows && pigRows.length){
        const pigs = pigRows.map(r => ({
          id: String(r.id).includes(':') ? String(r.id).slice(String(r.id).indexOf(':')+1) : r.id,
          name: r.name, gender: r.gender, breed: r.breed,
          birthDate: r.birth_date, arrivalDate: r.arrival_date,
          initialWeight: r.initial_weight_kg, penNumber: r.pen_number,
          notes: r.notes, photo: r.photo_url, status: r.status, createdAt: r.created_at,
        }));
        for (const p of pigs){
          await SqliteDB.upsertRow('pigs', { id: p.id, uid, data: JSON.stringify(p), updatedAt: SqliteDB.nowMs(), synced: 1, deleted: 0 });
        }
        window.DB.set(window.ck('pigs'), pigs);
      }
    } catch (err){
      console.warn('[ASF] pre-render Supabase fetch skipped (likely offline):', err);
    }
  }

  window.applyLang();
  window.checkDailyReset();
  window.loadData();

  // Re-arm real local notifications on every boot (not just when prefs are
  // edited) — a reinstall wipes the OS's own notification schedule even
  // though SQLite/Supabase still remember the user's saved preferences, so
  // without this a reinstalled app would silently stop reminding. No-ops
  // instantly if permission hasn't been granted yet.
  const notifPrefs = window.DB.get(window.ck('notifPrefs'));
  if (notifPrefs) scheduleAllReminders(notifPrefs).catch((err) => console.warn('[ASF Notifications] boot reschedule failed:', err));

  // Supabase enrichment + full sync run happen AFTER the UI is already
  // showing — deliberately not awaited by hydrateAppFromProfile, so a slow
  // or offline network never delays showAppShell().
  enrichFromCloudInBackground(uid);
}

/* ── Module-scoped state for the in-flight OTP flow ── */
let pendingRegistration = null;   // { name, mobile, municipality, email, password } — Register → Verify
let verificationId = null;        // returned by the plugin's phoneCodeSent event
let verifyMode = 'register';      // 'register' | 'login' — which flow the Verify screen is completing
let phoneListenersBound = false;

function bindPhoneListenersOnce(){
  if (phoneListenersBound) return;
  phoneListenersBound = true;
  FirebaseAuthentication.addListener('phoneCodeSent', (event) => {
    verificationId = event.verificationId;
  });
  FirebaseAuthentication.addListener('phoneVerificationFailed', (event) => {
    // The plugin's event payload here is just a free-text `message`, not a
    // structured `code` like the promise-rejection errors elsewhere in this
    // file, so it can't be run through mapAuthError()'s code lookup — surface
    // it plainly instead of guessing at a code from the message text.
    console.error('[ASF] phoneVerificationFailed:', event?.message);
    toast(`${T('auth-fb-generic')}${event?.message ? ' — ' + event.message : ''}`);
    loading('reg-submit-btn', false); loading('login-mobile-btn', false);
  });
}

/* ── Public API — attached to window.AsfAuth, called from index.html ── */
const AsfAuth = {

  async init(){
    if (!isFirebaseConfigured()){
      console.error(
        '[ASF] firebase-config.js still has placeholder values. ' +
        'Real Firebase Auth cannot work until you paste in your ' +
        'own project config — see SETUP.md.'
      );
    }
    bindPhoneListenersOnce();

    // "Remember Login" (spec §4): if the user explicitly unchecked it on
    // their last login, force a sign-out BEFORE registering the
    // authStateChange listener below, so its very first firing already
    // sees a signed-out state and correctly shows the Login screen instead
    // of auto-entering the Dashboard. Any other stored value (including
    // none at all) leaves Firebase's own session persistence untouched.
    try {
      const { value } = await Preferences.get({ key: REMEMBER_KEY });
      if (value === 'false') await FirebaseAuthentication.signOut();
    } catch (err){
      console.warn('[ASF] remember-login check failed (non-fatal):', err);
    }

    // Connectivity monitoring + the background push/pull sync loop —
    // started before auth resolves so the Online/Offline indicator is
    // correct from the very first frame. onRemoteUpdate re-renders the
    // app in place when the sync engine pulls newer data from another
    // device, without interrupting whatever the user is doing.
    await SyncEngine.init({
      onRemoteUpdate(logicalKey, value){
        applyRemoteUpdateLocally(logicalKey, value);
        if (typeof window.loadData === 'function') window.loadData();
      },
    });

    /* This is the actual auth-state-persistence requirement: Firebase's own
       session (kept in the Keychain/EncryptedSharedPreferences on native,
       IndexedDB on web) is checked here, once, on every app launch. If it
       reports a signed-in user, we go straight to the Dashboard and never
       show Welcome/Login — no matter how many times the app is restarted —
       until the user explicitly signs out. */
    FirebaseAuthentication.addListener('authStateChange', async (change) => {
      if (change.user){
        let onboardingCompleted = true; // fail open to the Dashboard rather than trapping a user in onboarding on error
        try {
          await hydrateAppFromProfile(change.user.uid);
          onboardingCompleted = await resolveOnboardingStatus(change.user.uid);
        } catch (e){
          console.error('[ASF] Failed to load profile from Supabase:', e);
        }
        // First Login Detection (spec §6): a brand-new registration or any
        // account that hasn't finished Pig Profile Setup + Set Reminders
        // yet goes to onboarding; every returning, fully-set-up user goes
        // straight to the Dashboard.
        if (!onboardingCompleted && typeof window.showOnboarding === 'function'){
          window.showOnboarding();
        } else {
          window.showAppShell();
        }
      } else {
        liveUid = null;
        SyncEngine.setActiveUid(null);
        window.setCurrentUid(null);
        window.showAuthShell();
      }
    });

    // In case the listener above doesn't fire an initial event on some
    // platforms/versions, explicitly check once too.
    try {
      const { user } = await FirebaseAuthentication.getCurrentUser();
      if (!user) window.showAuthShell();
    } catch (e){
      window.showAuthShell();
    }
  },

  /* ── Create Account: email/password creates the Firebase user AND signs
     into it — that sign-in is what stays current for the rest of
     registration. The phone OTP step then LINKS the phone number onto
     THIS SAME already-signed-in user via linkWithPhoneNumber(), instead of
     the old signInWithPhoneNumber(), which independently signs in (Firebase
     Phone Auth is a real sign-in method, keyed permanently by phone number —
     calling it here used to SWITCH the active session away from the
     just-created email/password user onto whichever Firebase user that
     phone number resolves to: a brand-new orphaned user the first time a
     number is used, or — critically — a PRE-EXISTING account the moment
     that same phone number is ever reused (e.g. two different registration
     attempts sharing a test number), silently logging the "new" user into
     someone else's existing account. linkWithPhoneNumber() never switches
     the session; it attaches the phone credential to the current user, so
     one registration = exactly one Firebase user, always. ── */
  async submitRegister({ name, mobile, municipality, email, password }){
    const phone = formatPhoneE164(mobile);
    if (!isValidPhone(phone)){ toast(T('auth-fb-invalid-phone')); return; }

    loading('reg-submit-btn', true);
    try {
      if (await phoneNumberIsTaken(phone)){
        toast(T('auth-fb-phone-in-use'));
        window.navAuth('login');
        return;
      }

      /* Pre-check the email too, same pattern as the phone check above —
         gives a clear, specific message and stops registration BEFORE
         Firebase account creation or phone-linking even starts, rather
         than relying solely on createUserWithEmailAndPassword() throwing
         'email-already-in-use' after already doing partial work. */
      if (await getUidByEmail(email)){
        toast(T('auth-email-in-use'));
        window.navAuth('login');
        return;
      }

      await FirebaseAuthentication.createUserWithEmailAndPassword({ email, password });
      await FirebaseAuthentication.updateProfile({ displayName: name });

      pendingRegistration = { name, mobile: phone, municipality, email, password };
      verifyMode = 'register';
      verificationId = null;

      await FirebaseAuthentication.linkWithPhoneNumber({ phoneNumber: phone });
      $('verify-mobile-display').textContent = phone;
      window.navAuth('verify');
      window.startOtpCountdown();
      setTimeout(() => document.querySelector('#otp-row .otp-box')?.focus(), 50);
    } catch (err){
      console.error('[ASF] submitRegister failed:', err);
      toast(mapAuthError(err));
    } finally {
      loading('reg-submit-btn', false);
    }
  },

  verifyOrigin(){ return verifyMode; },

  async resendOtp(){
    const phone = verifyMode === 'register'
      ? pendingRegistration?.mobile
      : $('login-mobile')?.value;
    if (!phone) return;
    try {
      // Register flow is still linking the phone onto the current
      // email/password user (see submitRegister's comment above); only the
      // Login-with-mobile flow (verifyMode === 'login') is a real
      // independent sign-in.
      if (verifyMode === 'register'){
        await FirebaseAuthentication.linkWithPhoneNumber({ phoneNumber: formatPhoneE164(phone) });
      } else {
        await FirebaseAuthentication.signInWithPhoneNumber({ phoneNumber: formatPhoneE164(phone) });
      }
      window.startOtpCountdown();
      toast(T('auth-resend'));
    } catch (err){
      console.error('[ASF] resendOtp failed:', err);
      toast(mapAuthError(err));
    }
  },

  async submitVerify(code){
    if (!verificationId){ toast(T('auth-fb-otp-expired')); return; }
    loading('verify-submit-btn', true);
    try {
      await FirebaseAuthentication.confirmVerificationCode({ verificationId, verificationCode: code });

      if (verifyMode === 'register' && pendingRegistration){
        const { name, mobile, municipality, email, password } = pendingRegistration;
        // No separate linkWithEmailAndPassword call needed here — email/
        // password was already the credential that created AND signed into
        // this Firebase user back in submitRegister(); confirmVerificationCode()
        // just above finished LINKING the phone number onto that same
        // still-current user (see submitRegister's comment). One user, both
        // credentials attached, no session switch ever happened.
        const { user } = await FirebaseAuthentication.getCurrentUser();
        await createUserProfile(user.uid, { fullName: name, phoneNumber: mobile, municipality, email });
        // Populate this brand-new account's real profile into the live
        // UI-facing cache RIGHT NOW, synchronously — closes the race where
        // Firebase's authStateChange listener (fired by the sign-in above)
        // triggers hydrateAppFromProfile()/hydrateFromSqlite() before this
        // registration's own SQLite/Supabase writes have finished. Without
        // this, that race is still SAFE (blank is the fallback, never fake
        // identity data — see hydrateFromSqlite()), but this makes the
        // user's actual name/municipality available immediately instead of
        // waiting on enrichFromCloudInBackground()'s later re-render.
        if (window.DB && window.ck){
          window.DB.set(window.ck('farmerProfile'), {
            name, municipality, province: '', farmerType: 'Backyard Raiser', photo: null,
          });
        }
        pendingRegistration = null;
        toast(T('auth-welcome-user', { name: name.split(' ')[0] }));
        recordActivityLog(user.uid, 'auth', 'registered account', name);
      } else {
        toast(T('auth-welcome-back'));
        try {
          const { user } = await FirebaseAuthentication.getCurrentUser();
          if (user?.uid) recordActivityLog(user.uid, 'auth', 'logged in');
        } catch (_){ /* non-fatal — a missed login log entry never blocks the actual sign-in */ }
      }
      // hydrateAppFromProfile() + showAppShell() run automatically via the
      // authStateChange listener registered in init() — no need to duplicate here.
    } catch (err){
      console.error('[ASF] submitVerify failed:', err);
      toast(mapAuthError(err));
      if (verifyMode === 'login'){
        const phone = $('login-mobile')?.value ? formatPhoneE164($('login-mobile').value) : null;
        const failedUid = phone ? await getUidByPhone(phone) : null;
        if (failedUid) recordActivityLog(failedUid, 'auth', 'failed login attempt (invalid or expired OTP)', phone);
      }
    } finally {
      loading('verify-submit-btn', false);
    }
  },

  async submitLoginEmail({ email, password, remember = true }){
    loading('login-email-btn', true);
    try {
      const { user } = await FirebaseAuthentication.signInWithEmailAndPassword({ email, password });
      // Persist the Remember Login choice for the NEXT app launch (see the
      // REMEMBER_KEY check near the top of init()). Written after a
      // successful sign-in so an unchecked box on a failed login attempt
      // never overwrites a previously-remembered session.
      try {
        await Preferences.set({ key: REMEMBER_KEY, value: remember ? 'true' : 'false' });
      } catch (prefErr){
        console.warn('[ASF] Preferences.set(remember-login) failed (non-fatal):', prefErr);
      }
      toast(T('auth-welcome-back'));
      // Logged directly against this uid (not via window.AsfLogActivity —
      // liveUid isn't set until hydrateAppFromProfile runs a moment later
      // via the authStateChange listener). usernameOverride falls back to
      // the email itself since the local farmerProfile cache isn't
      // populated yet at this exact instant either.
      if (user?.uid) recordActivityLog(user.uid, 'auth', 'logged in', email);
    } catch (err){
      console.error('[ASF] submitLoginEmail failed:', err);
      toast(mapAuthError(err));
      const failedUid = await getUidByEmail(email);
      if (failedUid) recordActivityLog(failedUid, 'auth', 'failed login attempt (wrong password)', email);
    } finally {
      loading('login-email-btn', false);
    }
  },

  async submitLoginPhone(mobileRaw){
    const phone = formatPhoneE164(mobileRaw);
    if (!isValidPhone(phone)){ toast(T('auth-fb-invalid-phone')); return; }
    loading('login-mobile-btn', true);
    try {
      if (!(await phoneNumberIsTaken(phone))){ toast(T('auth-fb-user-not-found')); return; }
      verifyMode = 'login';
      verificationId = null;
      await FirebaseAuthentication.signInWithPhoneNumber({ phoneNumber: phone });
      $('verify-mobile-display').textContent = phone;
      window.navAuth('verify');
      window.startOtpCountdown();
      setTimeout(() => document.querySelector('#otp-row .otp-box')?.focus(), 50);
    } catch (err){
      console.error('[ASF] submitLoginPhone failed:', err);
      toast(mapAuthError(err));
      const failedUid = await getUidByPhone(phone);
      if (failedUid) recordActivityLog(failedUid, 'auth', 'failed login attempt (mobile OTP send failed)', phone);
    } finally {
      loading('login-mobile-btn', false);
    }
  },

  async submitForgot(email){
    loading('forgot-send-btn', true);
    try {
      // Firebase's client SDK has "email enumeration protection" enabled by
      // default: sendPasswordResetEmail() resolves successfully even for an
      // email with no account, specifically so a caller can't probe which
      // emails are registered. That's normally a good thing, but it's
      // exactly what caused the bug here (every email showed "reset link
      // sent!", registered or not). So we do our own existence check first,
      // against the profiles table we already control, and only call
      // Firebase when a real account is found.
      const resetUid = await getUidByEmail(email);
      if (!resetUid){
        // No matching account — nothing to send, and (per the activity_logs
        // schema) nothing to log either: activity_logs.firebase_uid is a
        // NOT NULL foreign key into profiles, so a "failed reset" event for
        // an email that matches no account has no valid uid to attach to.
        console.warn('[ASF] submitForgot: no account found for', email);
        toast(T('auth-reset-no-account'));
        return;
      }
      await FirebaseAuthentication.sendPasswordResetEmail({ email });
      recordActivityLog(resetUid, 'auth', 'requested password reset', email);
      $('forgot-email-row').style.display = 'none';
      $('forgot-send-btn').style.display = 'none';
      $('forgot-success-box').style.display = 'flex';
    } catch (err){
      console.error('[ASF] submitForgot failed:', err);
      // A real account was found (resetUid above), but Firebase itself
      // rejected the reset call (invalid-email/too-many-requests/network) —
      // this DOES have a valid uid to log against.
      try {
        const failedUid = await getUidByEmail(email);
        if (failedUid) recordActivityLog(failedUid, 'auth', `failed password reset request (${err && err.code ? err.code : 'unknown error'})`, email);
      } catch (_) {}
      toast(mapAuthError(err));
    } finally {
      loading('forgot-send-btn', false);
    }
  },

  async logout(){
    try {
      // Captured BEFORE signOut() — the authStateChange listener clears
      // liveUid to null the moment sign-out completes, so logging through
      // window.AsfLogActivity (gated on liveUid) would silently no-op here.
      const uidBeforeSignOut = liveUid;
      if (uidBeforeSignOut) recordActivityLog(uidBeforeSignOut, 'auth', 'logged out');
      await FirebaseAuthentication.signOut();
      // authStateChange listener handles setCurrentUid(null) + showAuthShell()
      // Local session state is cleared, but SQLite's cached data for this
      // uid is deliberately left in place (spec §14 — "Keep SQLite cached
      // data") so a re-login on the same device is instantly ready offline.
    } catch (err){
      console.error('[ASF] logout failed:', err);
      toast(mapAuthError(err));
    }
  },


  /* Called from index.html once onboarding (Pig Profile Setup + Set
     Reminders) is saved — persists onboarding_completed=true to Supabase
     + the local SQLite cache so this account never sees onboarding again. */
  async markOnboardingCompleted(uid){
    await markOnboardingCompleted(uid || liveUid);
  },

  getLiveUid(){ return liveUid; },
};

window.AsfAuth = AsfAuth;

if (document.readyState === 'loading'){
  document.addEventListener('DOMContentLoaded', () => AsfAuth.init());
} else {
  AsfAuth.init();
}
