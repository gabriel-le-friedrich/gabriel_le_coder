import { initializeApp } from 'firebase/app';
import {
  initializeFirestore, persistentLocalCache, persistentMultipleTabManager,
  doc, getDoc, setDoc, serverTimestamp,
} from 'firebase/firestore';
import { getStorage } from 'firebase/storage';
import { FirebaseAuthentication } from '@capacitor-firebase/authentication';
import { Network } from '@capacitor/network';

import { firebaseConfig, isFirebaseConfigured } from './firebase-config.js';
import * as SqliteDB from './sqlite-db.js';
import * as SyncEngine from './sync-engine.js';

const app = initializeApp(firebaseConfig);
const db = initializeFirestore(app, {
  localCache: persistentLocalCache({ tabManager: persistentMultipleTabManager() }),
});
const storage = getStorage(app);

SqliteDB.initSqlite();

const $ = (id) => document.getElementById(id);
const T = (key, vars) => (window.t ? window.t(key, vars) : key);
const toast = (msg) => { if (window.showSyncToast) window.showSyncToast(msg); };
const loading = (btnId, on) => { if (window.setBtnLoading) window.setBtnLoading(btnId, on); };

function formatPhoneE164(raw){
  let s = String(raw || '').trim().replace(/[\s-()]/g, '');
  if (s.startsWith('+')) return s;
  s = s.replace(/^0+/, '');
  if (s.startsWith('63')) return '+' + s;
  return '+63' + s;
}
function isValidPhone(e164){
  return /^\+[1-9]\d{7,14}$/.test(e164);
}

function mapAuthError(err){
  const code = err && err.code ? String(err.code).replace(/^auth\//, '') : '';
  const map = {
    'invalid-phone-number': 'auth-fb-invalid-phone',
  };
  return T(map[code] || 'auth-fb-generic') + (code ? ` (${code})` : '');
}

async function phoneNumberIsTaken(phoneE164){
  const snap = await getDoc(doc(db, 'phoneIndex', phoneE164));
  return snap.exists();
}
async function createUserProfile(uid, { fullName, phoneNumber, municipality, email }){
  await setDoc(doc(db, 'users', uid), {
    fullName, phoneNumber, municipality, email,
    createdAt: serverTimestamp(),
    verified: true,
    role: 'raiser',
    profileImage: null,
  });
  await setDoc(doc(db, 'phoneIndex', phoneNumber), { uid });
  try {
    await SqliteDB.upsertUser({
      id: uid, fullName, phoneNumber, municipality, email,
      role: 'raiser', profileImage: null, verified: 1,
      createdAt: SqliteDB.nowMs(), updatedAt: SqliteDB.nowMs(), synced: 1,
    });
  } catch (err){
    console.warn('[ASF SQLite] failed to seed local user row after registration:', err);
  }
}
async function getUserProfile(uid){
  const snap = await getDoc(doc(db, 'users', uid));
  return snap.exists() ? snap.data() : null;
}

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
const LOCALSTATE_KEYS = new Set([
  'farmerProfile', 'notifPrefs', 'currentDay', 'dayLogs', 'weeklyTasks', 'vetContacts', 'appLang',
]);
const ALL_SYNCED_KEYS = [...Object.keys(COLLECTION_DOC_MAP), ...LOCALSTATE_KEYS];

let liveUid = null;

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

let syncDebounceTimer = null;
function scheduleDebouncedSync(uid){
  clearTimeout(syncDebounceTimer);
  syncDebounceTimer = setTimeout(() => SyncEngine.runSync(uid, { silent: true }), 800);
}

let originalDbSet = null;
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
    return value;
  };
  window.DB.__asfSyncInstalled = true;
}

function applyRemoteUpdateLocally(logicalKey, value){
  if (!window.ck) return;
  const fullKey = window.ck(logicalKey);
  if (originalDbSet) originalDbSet(fullKey, value);
  else if (window.DB) window.DB.set(fullKey, value);
}

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

async function hydrateFromSqlite(uid){
  const localUser = await SqliteDB.getUser(uid);
  if (localUser){
    window.DB.set(window.ck('farmerProfile'), {
      name: localUser.fullName || 'Farmer',
      municipality: (localUser.municipality || '').split(',')[0]?.trim() || '',
      province: (localUser.municipality || '').split(',').slice(1).join(',').trim() || '',
      farmerType: 'Backyard Raiser',
      photo: localUser.profileImage || null,
    });
  }
  if (!window.DB.get(window.ck('pigBatchProfile'))){
    const cached = await SqliteDB.getAggregate('settings', uid, 'pigBatchProfile');
    window.DB.set(window.ck('pigBatchProfile'), cached || {
      pigName: 'Bigas', numPigs: 1, startWeight: 20, startDate: new Date().toISOString().slice(0,10), feedPrice: 22.50,
    });
  }
  for (const subkey of SETTINGS_KEYS_SET){
    if (subkey === 'pigBatchProfile') continue;
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
}

async function enrichFromFirestoreInBackground(uid){
  try {
    const profile = await getUserProfile(uid);
    if (profile){
      await SqliteDB.upsertUser({
        id: uid, fullName: profile.fullName || '', phoneNumber: profile.phoneNumber || '',
        municipality: profile.municipality || '', email: profile.email || '',
        role: profile.role || 'raiser', profileImage: profile.profileImage || null,
        verified: profile.verified ? 1 : 0, createdAt: SqliteDB.nowMs(), updatedAt: SqliteDB.nowMs(), synced: 1,
      });
    }
  } catch (err){
    console.warn('[ASF] background profile enrichment skipped (likely offline):', err);
  }
  SyncEngine.runSync(uid);
}

async function hydrateAppFromProfile(uid){
  window.setCurrentUid(uid);
  liveUid = uid;
  installOfflineSync();
  SyncEngine.setActiveUid(uid);

  await hydrateFromSqlite(uid);
  window.applyLang();
  window.checkDailyReset();
  window.loadData();

  enrichFromFirestoreInBackground(uid);
}

let pendingRegistration = null;
let verificationId = null;
let verifyMode = 'register';
let phoneListenersBound = false;

function bindPhoneListenersOnce(){
  if (phoneListenersBound) return;
  phoneListenersBound = true;
  FirebaseAuthentication.addListener('phoneCodeSent', (event) => {
    verificationId = event.verificationId;
  });
  FirebaseAuthentication.addListener('phoneVerificationFailed', (event) => {
    console.error('[ASF] phoneVerificationFailed:', event?.message);
    toast(`${T('auth-fb-generic')}${event?.message ? ' — ' + event.message : ''}`);
    loading('reg-submit-btn', false); loading('login-mobile-btn', false);
  });
}

const AsfAuth = {

  async init(){
    if (!isFirebaseConfigured()){
      console.error('placeholder config');
    }
    bindPhoneListenersOnce();

    await SyncEngine.init({
      db, storage,
      onRemoteUpdate(logicalKey, value){
        applyRemoteUpdateLocally(logicalKey, value);
        if (typeof window.loadData === 'function') window.loadData();
      },
    });

    FirebaseAuthentication.addListener('authStateChange', async (change) => {
      if (change.user){
        try {
          await hydrateAppFromProfile(change.user.uid);
        } catch (e){
          console.error('[ASF] Failed to load profile from Firestore:', e);
        }
        window.showAppShell();
      } else {
        liveUid = null;
        SyncEngine.setActiveUid(null);
        window.setCurrentUid(null);
        window.showAuthShell();
      }
    });

    try {
      const { user } = await FirebaseAuthentication.getCurrentUser();
      if (!user) window.showAuthShell();
    } catch (e){
      window.showAuthShell();
    }
  },

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

      await FirebaseAuthentication.createUserWithEmailAndPassword({ email, password });
      await FirebaseAuthentication.updateProfile({ displayName: name });

      pendingRegistration = { name, mobile: phone, municipality, email, password };
      verifyMode = 'register';
      verificationId = null;

      await FirebaseAuthentication.signInWithPhoneNumber({ phoneNumber: phone });
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
      await FirebaseAuthentication.signInWithPhoneNumber({ phoneNumber: formatPhoneE164(phone) });
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
        try {
          await FirebaseAuthentication.linkWithEmailAndPassword({ email, password });
        } catch (linkErr){
          console.warn('[ASF] linkWithEmailAndPassword failed:', linkErr);
        }
        const { user } = await FirebaseAuthentication.getCurrentUser();
        await createUserProfile(user.uid, { fullName: name, phoneNumber: mobile, municipality, email });
        pendingRegistration = null;
        toast(T('auth-welcome-user', { name: name.split(' ')[0] }));
      } else {
        toast(T('auth-welcome-back'));
      }
    } catch (err){
      console.error('[ASF] submitVerify failed:', err);
      toast(mapAuthError(err));
    } finally {
      loading('verify-submit-btn', false);
    }
  },

  async submitLoginEmail({ email, password }){
    loading('login-email-btn', true);
    try {
      await FirebaseAuthentication.signInWithEmailAndPassword({ email, password });
      toast(T('auth-welcome-back'));
    } catch (err){
      console.error('[ASF] submitLoginEmail failed:', err);
      toast(mapAuthError(err));
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
    } finally {
      loading('login-mobile-btn', false);
    }
  },

  async submitForgot(email){
    loading('forgot-send-btn', true);
    try {
      await FirebaseAuthentication.sendPasswordResetEmail({ email });
      $('forgot-email-row').style.display = 'none';
      $('forgot-send-btn').style.display = 'none';
      $('forgot-success-box').style.display = 'flex';
    } catch (err){
      console.error('[ASF] submitForgot failed:', err);
      toast(mapAuthError(err));
    } finally {
      loading('forgot-send-btn', false);
    }
  },

  async logout(){
    try {
      await FirebaseAuthentication.signOut();
    } catch (err){
      console.error('[ASF] logout failed:', err);
      toast(mapAuthError(err));
    }
  },
};

window.AsfAuth = AsfAuth;

if (document.readyState === 'loading'){
  document.addEventListener('DOMContentLoaded', () => AsfAuth.init());
} else {
  AsfAuth.init();
}
