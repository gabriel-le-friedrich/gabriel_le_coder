/* ══════════════════════════════════════════════════════════════════════
   ASF — Offline Sync Engine (SQLite ⇄ Supabase)
   ══════════════════════════════════════════════════════════════════════
   Bridges the local SQLite database (src/sqlite-db.js) and Supabase
   (Postgres + Storage). Firebase is used only for Authentication (see
   src/auth-main.js) — this file never talks to Firestore or Firebase
   Storage, per integration_prompt.md's hybrid-backend design.

   Design (unchanged from the original Firestore-backed version):
     - SQLite is always the read source for the app (via window.DB, see
       auth-main.js). This engine's only job is keeping SQLite and
       Supabase eventually consistent — it never blocks a UI action.
     - Runs automatically whenever connectivity is detected, and can also
       be triggered manually (e.g. right after a successful login).
     - Conflict resolution is intentionally simple, matching
       integration_prompt.md §5's own stated scope ("last-write-wins is
       acceptable for a capstone scope"):
         • Per-row tables (pigs, notifications, weekly_pig_images) use a
           real last-write-wins check against each row's own updated_at.
         • The four "whole array" categories (feeding logs, health logs,
           weight logs, expenses) resolve at the sync-run level: if this
           device has local unsynced changes, its copy is pushed as the
           new truth for that category; otherwise anything new on
           Supabase is pulled in. Documented here rather than building
           full per-entry three-way merging.
     - Every push is an upsert against a stable, deterministic key (see
       supabase_schema_addendum.sql's sync_key / app_entry_id columns) —
       retrying a sync run after a partial failure never creates
       duplicate rows.
   ══════════════════════════════════════════════════════════════════════ */

import { Network } from '@capacitor/network';
import { supabase } from './supabase-config.js';
import * as SqliteDB from './sqlite-db.js';

const PHOTOS_BUCKET = 'pig-photos';

const SETTINGS_SUBS = ['farmerProfile', 'pigBatchProfile', 'notifPrefs', 'currentDay', 'dayLogs', 'weeklyTasks', 'vetContacts', 'appLang'];

const uploadedPhotoIds = new Set(); // avoids re-uploading the same photo on every unrelated sync run

function safeParse(str, fallback = null) {
  try { return JSON.parse(str); } catch (_) { return fallback; }
}

function dataUriToBlob(dataUri) {
  const [header, base64] = dataUri.split(',');
  const mimeMatch = /data:(.*?);base64/.exec(header || '');
  const mime = mimeMatch ? mimeMatch[1] : 'image/jpeg';
  const binary = atob(base64 || '');
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return new Blob([bytes], { type: mime });
}

/* Uploads a single base64 data-URI image to the Supabase "pig-photos"
   bucket (once per cache key) and returns a durable public URL. Returns
   the value unchanged if it isn't a data URI. Non-fatal on failure — the
   caller keeps the base64 around and this gets retried on the next sync
   run. The bucket is public (see supabase_schema (1).sql), so a plain
   public URL is all that's needed — no signed-URL refresh logic. */
async function maybeUploadPhoto(dataUri, storagePath, cacheKey) {
  if (!dataUri || typeof dataUri !== 'string' || !dataUri.startsWith('data:')) return dataUri;
  if (cacheKey && uploadedPhotoIds.has(cacheKey)) {
    const { data } = supabase.storage.from(PHOTOS_BUCKET).getPublicUrl(storagePath);
    if (data?.publicUrl) return data.publicUrl;
  }
  const blob = dataUriToBlob(dataUri);
  const { error } = await supabase.storage.from(PHOTOS_BUCKET).upload(storagePath, blob, {
    upsert: true, contentType: blob.type || 'image/jpeg',
  });
  if (error) throw error;
  const { data } = supabase.storage.from(PHOTOS_BUCKET).getPublicUrl(storagePath);
  if (cacheKey) uploadedPhotoIds.add(cacheKey);
  return data?.publicUrl || dataUri;
}

const state = {
  status: 'offline',   // 'offline' | 'online' | 'syncing' | 'synced' | 'error'
  uid: null,
  onRemoteUpdate: null, // (logicalKey, value) => void — lets the app refresh its UI
  networkBound: false,
  retryTimer: null,
  periodicTimer: null,
  syncing: false,      // re-entrancy guard
};

function setStatus(status) {
  state.status = status;
  try {
    window.dispatchEvent(new CustomEvent('asf-sync-status', { detail: { status } }));
    if (typeof window.AsfUpdateSyncBadge === 'function') window.AsfUpdateSyncBadge(status);
  } catch (_) { /* non-fatal — badge is a UI nicety, never block sync over it */ }
}

export function getStatus() { return state.status; }

/* Call once, after Supabase is initialized. Sets up connectivity
   monitoring and a periodic background retry — nothing here requires a
   signed-in user yet (that comes via setActiveUid). */
export async function init({ onRemoteUpdate } = {}) {
  state.onRemoteUpdate = onRemoteUpdate || null;

  try {
    const net = await Network.getStatus();
    setStatus(net.connected ? 'online' : 'offline');
  } catch (err) {
    console.warn('[ASF Sync] Network.getStatus failed, assuming online:', err);
    setStatus('online');
  }

  if (!state.networkBound) {
    state.networkBound = true;
    Network.addListener('networkStatusChange', (status) => {
      const wasOffline = state.status === 'offline';
      setStatus(status.connected ? 'online' : 'offline');
      if (status.connected && wasOffline && state.uid) {
        runSync(state.uid);
      }
    });
    // Safety-net retry loop — catches anything a single failed push left
    // unsynced, without needing the user to do anything ("retry
    // automatically later without user intervention").
    state.periodicTimer = setInterval(() => {
      if (state.status !== 'offline' && state.uid && !state.syncing) {
        runSync(state.uid, { silent: true });
      }
    }, 60000);
  }
}

export function setActiveUid(uid) {
  state.uid = uid;
}

/* Main entry point — safe to call repeatedly (re-entrancy guarded) and
   safe to call while offline (it just no-ops back to 'offline' status). */
export async function runSync(uid, { silent = false } = {}) {
  if (!uid) return;
  if (state.syncing) return;
  let net;
  try { net = await Network.getStatus(); } catch (_) { net = { connected: true }; }
  if (!net.connected) { setStatus('offline'); return; }

  state.syncing = true;
  if (!silent) setStatus('syncing');
  try {
    await syncPigs(uid);
    await syncFeedLogs(uid);
    await syncHealthLogs(uid);
    await syncBatchWeightLogs(uid);
    await syncPigWeightLogs(uid);
    await syncExpenses(uid);
    await syncSettings(uid);
    await syncNotifications(uid);
    await syncActivityLogs(uid);
    await syncImages(uid);
    await SqliteDB.setSyncMeta(uid, 'success');
    setStatus('synced');
    setTimeout(() => { if (state.status === 'synced') setStatus('online'); }, 3000);
  } catch (err) {
    console.error('[ASF Sync] sync run failed:', err);
    await SqliteDB.setSyncMeta(uid, 'error');
    setStatus('error');
    scheduleRetry(uid);
  } finally {
    state.syncing = false;
  }
}

function scheduleRetry(uid) {
  clearTimeout(state.retryTimer);
  state.retryTimer = setTimeout(() => runSync(uid, { silent: true }), 30000);
}

/* ── Pigs: per-row sync + last-write-wins conflict check ──
   pigs.id in Supabase is `text primary key` — GLOBAL across every
   account, not scoped by firebase_uid. The app's own local pig ids
   (generatePigId() in index.html) are only ever guaranteed unique WITHIN
   one account — and worse, every fresh account's very first onboarding
   pig is literally always 'BIGAS-01' (see submitOnboardStart()). Two
   different users therefore very easily generate the identical pig id,
   and a plain upsert(onConflict:'id') would silently reassign that row's
   firebase_uid to whichever account synced second — after which the
   FIRST account's next syncPigs() "refresh from Supabase" (below) finds
   its pig no longer belongs to it and wipes it from the local UI. This
   is the root cause behind "pig disappears after saving" reported in
   real multi-account testing.
   Fix: never store the app-facing id directly as the Supabase primary
   key. Prefix it with the owning uid at the sync boundary only — the
   local id (SQLite, UI, growth history, image pig_id links) is
   completely unchanged; only the value actually sent to/read from
   Supabase's `pigs.id` column is namespaced, which makes cross-account
   collisions structurally impossible without any schema migration. */
function remotePigId(uid, localId) { return `${uid}:${localId}`; }
function localPigIdFromRemote(remoteId) {
  const i = String(remoteId).indexOf(':');
  return i === -1 ? remoteId : remoteId.slice(i + 1);
}
function pigToRow(p, uid) {
  return {
    id: remotePigId(uid, p.id), firebase_uid: uid,
    name: p.name || null, tag_number: p.id || null,
    gender: p.gender || null, breed: p.breed || null,
    birth_date: p.birthDate || null, arrival_date: p.arrivalDate || null,
    initial_weight_kg: p.initialWeight ?? null, pen_number: p.penNumber || null,
    notes: p.notes || null, status: p.status || 'active',
  };
}
function rowToPig(r) {
  return {
    id: localPigIdFromRemote(r.id), name: r.name, gender: r.gender, breed: r.breed,
    birthDate: r.birth_date, arrivalDate: r.arrival_date,
    initialWeight: r.initial_weight_kg, penNumber: r.pen_number,
    notes: r.notes, photo: r.photo_url, status: r.status,
    createdAt: r.created_at,
  };
}
async function syncPigs(uid) {
  const unsynced = await SqliteDB.getUnsyncedRows('pigs', uid);
  for (const row of unsynced) {
    const rid = remotePigId(uid, row.id);
    try {
      const { data: remote } = await supabase.from('pigs').select('updated_at')
        .eq('id', rid).eq('firebase_uid', uid).maybeSingle();
      const remoteUpdatedAt = remote ? new Date(remote.updated_at).getTime() : 0;

      if (row.updatedAt >= remoteUpdatedAt) {
        if (row.deleted) {
          await supabase.from('pigs').delete().eq('id', rid).eq('firebase_uid', uid);
        } else {
          const p = safeParse(row.data, {});
          if (p.photo && String(p.photo).startsWith('data:')) {
            p.photo = await maybeUploadPhoto(p.photo, `${uid}/${row.id}.jpg`, `${uid}:pig:${row.id}`);
          }
          const payload = { ...pigToRow(p, uid), photo_url: p.photo || null, updated_at: new Date(row.updatedAt).toISOString() };
          const { error } = await supabase.from('pigs').upsert(payload, { onConflict: 'id' });
          if (error) throw error;
        }
        await SqliteDB.markRowSynced('pigs', row.id);
      } else {
        const { data: full } = await supabase.from('pigs').select('*').eq('id', rid).eq('firebase_uid', uid).maybeSingle();
        if (full) {
          await SqliteDB.upsertRow('pigs', {
            id: row.id, uid, data: JSON.stringify(rowToPig(full)),
            updatedAt: remoteUpdatedAt, synced: 1, deleted: 0,
          });
        }
      }
    } catch (err) {
      console.warn('[ASF Sync] pig sync failed for', row.id, '— will retry:', err);
    }
  }
  // Refresh the whole pigs list from Supabase so anything pulled/pushed
  // (including from another device) is reflected in the UI immediately.
  // Defensive merge: a pig that is still sitting in SQLite as unsynced
  // (its push above may have failed, be mid-retry, or simply not have
  // replicated yet) must NEVER be dropped from what the user sees just
  // because this particular snapshot doesn't have it yet — this exact
  // "overwrite local with an incomplete remote snapshot" was the mechanism
  // behind pigs vanishing after being saved. Confirmed-synced local rows
  // always defer to the fresh remote copy (normal last-write-wins).
  try {
    const { data: allRemote } = await supabase.from('pigs').select('*').eq('firebase_uid', uid);
    if (allRemote && state.onRemoteUpdate) {
      const merged = allRemote.map(rowToPig);
      const remoteIds = new Set(merged.map(p => p.id));
      const stillUnsynced = await SqliteDB.getUnsyncedRows('pigs', uid);
      for (const row of stillUnsynced) {
        if (row.deleted) continue;
        if (!remoteIds.has(row.id)) {
          const p = safeParse(row.data, null);
          if (p) merged.push(p);
        }
      }
      state.onRemoteUpdate('pigs', merged);
    }
  } catch (err) {
    console.warn('[ASF Sync] pig list refresh failed:', err);
  }
}

/* ── Feed logs (whole-batch, day-numbered — see header comment for the
   "whole array" conflict-resolution scope decision). ── */
async function syncFeedLogs(uid) {
  try {
    const localArr = (await SqliteDB.getAggregate('feedingLogs', uid, 'main')) || [];
    const isDirty = (await SqliteDB.getUnsyncedAggregates('feedingLogs', uid)).some(u => u.subkey === 'main');

    if (isDirty) {
      const rows = localArr.map(e => ({
        firebase_uid: uid, sync_key: `batch:d${e.day}`,
        pig_id: null, feed_type: null, quantity_kg: e.feedKg, fed_at: e.date, day_number: e.day,
      }));
      if (rows.length) {
        const { error } = await supabase.from('feeding_logs').upsert(rows, { onConflict: 'firebase_uid,sync_key' });
        if (error) throw error;
      }
      const keep = new Set(rows.map(r => r.sync_key));
      const { data: remoteAll } = await supabase.from('feeding_logs').select('sync_key').eq('firebase_uid', uid).not('sync_key', 'is', null);
      const toDelete = (remoteAll || []).map(r => r.sync_key).filter(k => !keep.has(k));
      if (toDelete.length) await supabase.from('feeding_logs').delete().eq('firebase_uid', uid).in('sync_key', toDelete);
      await SqliteDB.markAggregateSynced('feedingLogs', uid, 'main');
    } else {
      const { data: remoteRows } = await supabase.from('feeding_logs').select('*').eq('firebase_uid', uid).not('day_number', 'is', null);
      if (remoteRows && remoteRows.length && remoteRows.length !== localArr.length) {
        const entries = remoteRows
          .sort((a, b) => (a.day_number || 0) - (b.day_number || 0))
          .map(r => ({ day: r.day_number, date: r.fed_at, feedKg: r.quantity_kg }));
        await SqliteDB.setAggregate('feedingLogs', uid, 'main', entries, { synced: true });
        if (state.onRemoteUpdate) state.onRemoteUpdate('feedLogs', entries);
      }
    }
  } catch (err) {
    console.warn('[ASF Sync] feed logs sync failed:', err);
  }
}

/* ── Health logs — each entry already has a real app-assigned id, packed
   whole into condition_notes as JSON so no observation field is lost even
   though the relational table only has one text column for it. ── */
async function syncHealthLogs(uid) {
  try {
    const localArr = (await SqliteDB.getAggregate('healthLogs', uid, 'main')) || [];
    const isDirty = (await SqliteDB.getUnsyncedAggregates('healthLogs', uid)).some(u => u.subkey === 'main');

    if (isDirty) {
      const rows = localArr.map(e => ({
        firebase_uid: uid, app_entry_id: String(e.id),
        pig_id: null, condition_notes: JSON.stringify(e), attachment_url: null,
        recorded_at: e.timestamp || null,
      }));
      if (rows.length) {
        const { error } = await supabase.from('health_records').upsert(rows, { onConflict: 'firebase_uid,app_entry_id' });
        if (error) throw error;
      }
      const keep = new Set(rows.map(r => r.app_entry_id));
      const { data: remoteAll } = await supabase.from('health_records').select('app_entry_id').eq('firebase_uid', uid).not('app_entry_id', 'is', null);
      const toDelete = (remoteAll || []).map(r => r.app_entry_id).filter(id => !keep.has(id));
      if (toDelete.length) await supabase.from('health_records').delete().eq('firebase_uid', uid).in('app_entry_id', toDelete);
      await SqliteDB.markAggregateSynced('healthLogs', uid, 'main');
    } else {
      const { data: remoteRows } = await supabase.from('health_records').select('*').eq('firebase_uid', uid).not('app_entry_id', 'is', null);
      if (remoteRows && remoteRows.length && remoteRows.length !== localArr.length) {
        const entries = remoteRows.map(r => safeParse(r.condition_notes)).filter(Boolean).sort((a, b) => (a.id || 0) - (b.id || 0));
        await SqliteDB.setAggregate('healthLogs', uid, 'main', entries, { synced: true });
        if (state.onRemoteUpdate) state.onRemoteUpdate('healthLogs', entries);
      }
    }
  } catch (err) {
    console.warn('[ASF Sync] health logs sync failed:', err);
  }
}

/* ── Weight logs — whole-batch chart ("weightLogs" subkey of growthLogs,
   the app's conventional default-pig BIGAS-01 series). ── */
async function syncBatchWeightLogs(uid) {
  try {
    const localArr = (await SqliteDB.getAggregate('growthLogs', uid, 'weightLogs')) || [];
    const isDirty = (await SqliteDB.getUnsyncedAggregates('growthLogs', uid)).some(u => u.subkey === 'weightLogs');

    if (isDirty) {
      const rows = localArr.map(e => ({
        firebase_uid: uid, sync_key: `batch:d${e.day}`,
        pig_id: null, weight_kg: e.weight, recorded_at: e.date, day_number: e.day, week_number: null,
      }));
      if (rows.length) {
        const { error } = await supabase.from('weight_records').upsert(rows, { onConflict: 'firebase_uid,sync_key' });
        if (error) throw error;
      }
      const keep = new Set(rows.map(r => r.sync_key));
      const { data: remoteAll } = await supabase.from('weight_records').select('sync_key').eq('firebase_uid', uid).is('pig_id', null).not('sync_key', 'is', null);
      const toDelete = (remoteAll || []).map(r => r.sync_key).filter(k => !keep.has(k));
      if (toDelete.length) await supabase.from('weight_records').delete().eq('firebase_uid', uid).in('sync_key', toDelete);
      await SqliteDB.markAggregateSynced('growthLogs', uid, 'weightLogs');
    } else {
      const { data: remoteRows } = await supabase.from('weight_records').select('*').eq('firebase_uid', uid).is('pig_id', null).not('day_number', 'is', null);
      if (remoteRows && remoteRows.length && remoteRows.length !== localArr.length) {
        const entries = remoteRows
          .sort((a, b) => (a.day_number || 0) - (b.day_number || 0))
          .map(r => ({ day: r.day_number, weight: r.weight_kg, date: r.recorded_at }));
        await SqliteDB.setAggregate('growthLogs', uid, 'weightLogs', entries, { synced: true });
        if (state.onRemoteUpdate) state.onRemoteUpdate('weightLogs', entries);
      }
    }
  } catch (err) {
    console.warn('[ASF Sync] batch weight logs sync failed:', err);
  }
}

/* ── Per-pig weigh-ins ("perPigWeights" subkey) — a dict keyed by pigId,
   each value an array of {week, weight, date}. Flattened for the sync,
   rebuilt into the dict shape on pull. ── */
async function syncPigWeightLogs(uid) {
  try {
    const dict = (await SqliteDB.getAggregate('growthLogs', uid, 'perPigWeights')) || {};
    const isDirty = (await SqliteDB.getUnsyncedAggregates('growthLogs', uid)).some(u => u.subkey === 'perPigWeights');
    const flatCount = Object.values(dict).reduce((n, arr) => n + arr.length, 0);

    if (isDirty) {
      const rows = [];
      for (const pigId of Object.keys(dict)) {
        for (const e of dict[pigId]) {
          rows.push({
            firebase_uid: uid, sync_key: `pig:${pigId}:wk${e.week}`,
            pig_id: pigId, weight_kg: e.weight, recorded_at: e.date, week_number: e.week, day_number: null,
          });
        }
      }
      if (rows.length) {
        const { error } = await supabase.from('weight_records').upsert(rows, { onConflict: 'firebase_uid,sync_key' });
        if (error) throw error;
      }
      const keep = new Set(rows.map(r => r.sync_key));
      const { data: remoteAll } = await supabase.from('weight_records').select('sync_key').eq('firebase_uid', uid).not('pig_id', 'is', null).not('sync_key', 'is', null);
      const toDelete = (remoteAll || []).map(r => r.sync_key).filter(k => !keep.has(k));
      if (toDelete.length) await supabase.from('weight_records').delete().eq('firebase_uid', uid).in('sync_key', toDelete);
      await SqliteDB.markAggregateSynced('growthLogs', uid, 'perPigWeights');
    } else {
      const { data: remoteRows } = await supabase.from('weight_records').select('*').eq('firebase_uid', uid).not('pig_id', 'is', null);
      if (remoteRows && remoteRows.length && remoteRows.length !== flatCount) {
        const rebuilt = {};
        for (const r of remoteRows.sort((a, b) => (a.week_number || 0) - (b.week_number || 0))) {
          (rebuilt[r.pig_id] || (rebuilt[r.pig_id] = [])).push({ week: r.week_number, weight: r.weight_kg, date: r.recorded_at });
        }
        await SqliteDB.setAggregate('growthLogs', uid, 'perPigWeights', rebuilt, { synced: true });
        if (state.onRemoteUpdate) state.onRemoteUpdate('pigWeightLogs', rebuilt);
      }
    }
  } catch (err) {
    console.warn('[ASF Sync] per-pig weight logs sync failed:', err);
  }
}

/* ── Expenses — each entry already has a real app-assigned id. ── */
async function syncExpenses(uid) {
  try {
    const localArr = (await SqliteDB.getAggregate('expenses', uid, 'main')) || [];
    const isDirty = (await SqliteDB.getUnsyncedAggregates('expenses', uid)).some(u => u.subkey === 'main');

    if (isDirty) {
      const rows = localArr.map(e => ({
        firebase_uid: uid, app_entry_id: String(e.id),
        category: e.category, description: e.description, amount: e.amount,
        expense_date: e.date, note: e.note || null,
      }));
      if (rows.length) {
        const { error } = await supabase.from('expenses').upsert(rows, { onConflict: 'firebase_uid,app_entry_id' });
        if (error) throw error;
      }
      const keep = new Set(rows.map(r => r.app_entry_id));
      const { data: remoteAll } = await supabase.from('expenses').select('app_entry_id').eq('firebase_uid', uid).not('app_entry_id', 'is', null);
      const toDelete = (remoteAll || []).map(r => r.app_entry_id).filter(id => !keep.has(id));
      if (toDelete.length) await supabase.from('expenses').delete().eq('firebase_uid', uid).in('app_entry_id', toDelete);
      await SqliteDB.markAggregateSynced('expenses', uid, 'main');
    } else {
      const { data: remoteRows } = await supabase.from('expenses').select('*').eq('firebase_uid', uid).not('app_entry_id', 'is', null);
      if (remoteRows && remoteRows.length && remoteRows.length !== localArr.length) {
        const entries = remoteRows
          .sort((a, b) => Number(a.app_entry_id) - Number(b.app_entry_id))
          .map(r => ({ id: Number(r.app_entry_id), category: r.category, description: r.description, amount: r.amount, date: r.expense_date, note: r.note || '' }));
        await SqliteDB.setAggregate('expenses', uid, 'main', entries, { synced: true });
        if (state.onRemoteUpdate) state.onRemoteUpdate('expenses', entries);
      }
    }
  } catch (err) {
    console.warn('[ASF Sync] expenses sync failed:', err);
  }
}

/* farmerProfile carries a photo that needs a real Storage upload before
   the Supabase mirror, exactly like weekly pig photos and pig photos. */
async function uploadSettingsPhotoIfNeeded(uid, subkey, data) {
  if (subkey !== 'farmerProfile' || !data || !data.photo) return data;
  if (!String(data.photo).startsWith('data:')) return data;
  try {
    const url = await maybeUploadPhoto(data.photo, `${uid}/profile.jpg`, `${uid}:profile`);
    return { ...data, photo: url };
  } catch (err) {
    console.warn('[ASF Sync] profile photo upload failed, will retry next sync:', err);
    return data;
  }
}

/* ── Dedicated-table mirrors for pigBatchProfile / notifPrefs ──
   The generic settings table (one JSON blob per firebase_uid+subkey) stays
   the source of truth the rest of the app already reads/writes through
   ck('pigBatchProfile')/ck('notifPrefs') — these two just ALSO mirror the
   same data into farm_batches / notification_settings as real typed
   columns, per the auth/onboarding spec ("store in a farm_batches table" /
   "notification_settings table"), so both are directly queryable in
   Supabase without unpacking JSON. Called from syncSettings() right after
   each subkey's normal push succeeds — never on the pull branch, since
   pulled data is already in Supabase by definition. */
async function pushFarmBatchMirror(uid, profile) {
  if (!profile) return;
  try {
    const { error } = await supabase.from('farm_batches').upsert({
      firebase_uid: uid,
      batch_name: profile.pigName ?? null,
      number_of_pigs: profile.numPigs ?? null,
      starting_weight: profile.startWeight ?? null,
      start_date: profile.startDate || null,
      feed_price: profile.feedPrice ?? null,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'firebase_uid' });
    if (error) throw error;
  } catch (err) {
    console.warn('[ASF Sync] farm_batches mirror failed (non-fatal):', err);
  }
}
// No time-of-day picker exists for the Supplement Reminder in the current
// UI (only a frequency dropdown) — mirrors src/notifications.js's own
// internal default so the two stay consistent with each other.
const SUPPLEMENT_DEFAULT_TIME = '9:00 AM';
async function pushNotificationSettingsMirror(uid, prefs) {
  if (!prefs) return;
  try {
    const { error } = await supabase.from('notification_settings').upsert({
      firebase_uid: uid,
      morning_enabled: !!prefs.morning?.enabled,
      morning_time: prefs.morning?.time || null,
      afternoon_enabled: !!prefs.afternoon?.enabled,
      afternoon_time: prefs.afternoon?.time || null,
      weekly_enabled: !!prefs.weighin?.enabled,
      weekly_day: prefs.weighin?.day ?? null,
      supplement_enabled: !!prefs.supplement?.enabled,
      supplement_time: SUPPLEMENT_DEFAULT_TIME,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'firebase_uid' });
    if (error) throw error;
  } catch (err) {
    console.warn('[ASF Sync] notification_settings mirror failed (non-fatal):', err);
  }
}

/* ── Settings: one row per (firebase_uid, subkey) — a cleaner fit for
   Supabase than the old single-Firestore-doc-with-nested-fields shape,
   since each subkey now gets its own real updated_at for conflict
   checking. ── */
async function syncSettings(uid) {
  for (const subkey of SETTINGS_SUBS) {
    try {
      const local = await SqliteDB.getAggregate('settings', uid, subkey);
      const localUnsynced = (await SqliteDB.getUnsyncedAggregates('settings', uid)).find(u => u.subkey === subkey);

      const { data: remote } = await supabase.from('settings').select('data, updated_at')
        .eq('firebase_uid', uid).eq('subkey', subkey).maybeSingle();
      const remoteUpdatedAt = remote ? new Date(remote.updated_at).getTime() : 0;

      if (localUnsynced) {
        if (localUnsynced.updatedAt >= remoteUpdatedAt) {
          const pushData = await uploadSettingsPhotoIfNeeded(uid, subkey, localUnsynced.data);
          const { error } = await supabase.from('settings').upsert({
            firebase_uid: uid, subkey, data: pushData, updated_at: new Date(localUnsynced.updatedAt).toISOString(),
          }, { onConflict: 'firebase_uid,subkey' });
          if (error) throw error;
          await SqliteDB.markAggregateSynced('settings', uid, subkey);
          if (subkey === 'pigBatchProfile') await pushFarmBatchMirror(uid, pushData);
          if (subkey === 'notifPrefs') await pushNotificationSettingsMirror(uid, pushData);
        } else if (remote) {
          await SqliteDB.setAggregate('settings', uid, subkey, remote.data, { updatedAt: remoteUpdatedAt, synced: true });
          if (state.onRemoteUpdate) state.onRemoteUpdate(subkey, remote.data);
        }
      } else if (local == null && remote) {
        await SqliteDB.setAggregate('settings', uid, subkey, remote.data, { updatedAt: remoteUpdatedAt, synced: true });
        if (state.onRemoteUpdate) state.onRemoteUpdate(subkey, remote.data);
      }
    } catch (err) {
      console.warn(`[ASF Sync] settings/${subkey} sync failed:`, err);
    }
  }
}

/* ── Notifications: push-only (critical alerts are events, not editable
   records — there's nothing to pull/merge, just deliver once). ── */
async function syncNotifications(uid) {
  const unsynced = await SqliteDB.getUnsyncedRows('notifications', uid);
  for (const row of unsynced) {
    try {
      const { error } = await supabase.from('notifications').upsert({
        id: row.id, firebase_uid: uid, type: row.type,
        data: safeParse(row.data, {}), read: !!row.read,
        created_at: new Date(row.createdAt).toISOString(),
      }, { onConflict: 'id' });
      if (error) throw error;
      await SqliteDB.markRowSynced('notifications', row.id);
    } catch (err) {
      console.warn('[ASF Sync] notification sync failed for', row.id, err);
    }
  }
}

/* ── Activity logs: push-only, exactly like syncNotifications() — each
   entry is a durable EVENT record, created once and never edited/deleted
   anywhere in the app, so there's nothing to pull/merge/conflict-check,
   just deliver once. The Settings ▸ Activity Log screen reads its list
   straight from Supabase (self-uid scoped) via
   src/auth-main.js's getActivityLogsCombined(), falling back to/merging
   with these same local rows when offline — it does NOT go through
   state.onRemoteUpdate, since a log is an append-only event feed, not app
   state the rest of the UI re-renders around. ── */
async function syncActivityLogs(uid) {
  const unsynced = await SqliteDB.getUnsyncedRows('activityLogs', uid);
  for (const row of unsynced) {
    try {
      // upsert + ignoreDuplicates (ON CONFLICT ... DO NOTHING) rather than a
      // plain insert, so a retried push after a partial failure (row landed
      // in Supabase last time, the local synced=1 write just never happened)
      // silently no-ops instead of erroring OR needing UPDATE privileges —
      // this table's RLS deliberately has no update policy at all (see
      // supabase_schema.sql), and DO NOTHING never modifies an existing row,
      // so it works fine under insert-only RLS.
      const { error } = await supabase.from('activity_logs').upsert({
        firebase_uid: uid, app_entry_id: row.id, username: row.username || null,
        action_type: row.actionType || null, description: row.description || '',
        created_at: new Date(row.createdAt).toISOString(),
      }, { onConflict: 'firebase_uid,app_entry_id', ignoreDuplicates: true });
      if (error) throw error;
      await SqliteDB.markRowSynced('activityLogs', row.id);
    } catch (err) {
      console.warn('[ASF Sync] activity log sync failed for', row.id, '— will retry:', err);
    }
  }
}

/* ── Weekly pig images: upload to Storage (retries automatically via the
   normal unsynced-row mechanism if a previous attempt failed), then mirror
   the resulting public URL into Supabase. ── */
async function syncImages(uid) {
  const unsynced = await SqliteDB.getUnsyncedRows('weeklyPigImages', uid);
  let anyProcessed = false;
  for (const row of unsynced) {
    // weekly_pig_images.id is also a GLOBAL text primary key in Supabase
    // (see the pigs.id comment above syncPigs — same root cause), and the
    // local id is just an incrementing in-memory counter (nextPhotoId in
    // index.html) that restarts fresh per account, so two different
    // accounts' first weekly photo would otherwise collide on row id and
    // silently swap ownership. Namespaced the same way as pigs, at the
    // sync boundary only — local id/UI/SQLite are unaffected.
    const rid = `${uid}:${row.id}`;
    try {
      if (row.deleted) {
        await supabase.from('weekly_pig_images').delete().eq('id', rid).eq('firebase_uid', uid);
        await SqliteDB.markRowSynced('weeklyPigImages', row.id);
        anyProcessed = true;
        continue;
      }
      let remoteUrl = row.remoteUrl;
      if (!remoteUrl && row.localUri && String(row.localUri).startsWith('data:')) {
        const path = `${uid}/pig_${row.pigId}_wk${row.weekNumber}_${row.id}.jpg`;
        remoteUrl = await maybeUploadPhoto(row.localUri, path, `${uid}:img:${row.id}`);
      }
      const { error } = await supabase.from('weekly_pig_images').upsert({
        id: rid, firebase_uid: uid, pig_id: row.pigId || null, week_number: row.weekNumber,
        image_url: remoteUrl || null, capture_date: row.captureDate, notes: row.notes || null,
        updated_at: new Date(row.updatedAt).toISOString(),
      }, { onConflict: 'id' });
      if (error) throw error;
      await SqliteDB.markRowSynced('weeklyPigImages', row.id, { remoteUrl: remoteUrl || null });
      anyProcessed = true;
    } catch (err) {
      // Left as synced=0 on purpose — the periodic retry loop and the next
      // connectivity-restored event will pick this up automatically, per
      // "retry automatically later without user intervention."
      console.warn('[ASF Sync] image sync failed for', row.id, '— will retry:', err);
    }
  }
  // Push the REAL post-sync state (which rows actually finished uploading,
  // and their real Storage URL) back into the UI-facing cache, the same
  // way syncPigs()/syncHealthLogs() do. index.html's savePhoto() used to
  // fake this with a bare setTimeout that always flipped `synced: true`
  // after ~1.8s regardless of whether the upload actually succeeded (or
  // was even online) — that's replaced by this real callback, so the
  // "queued → synced" badge in Weekly Pig Images only ever reflects what
  // Supabase Storage actually has.
  if (anyProcessed && state.onRemoteUpdate) {
    try {
      const rows = await SqliteDB.getRows('weeklyPigImages', uid);
      const images = rows.map(r => ({
        id: Number(r.id) || r.id, pig_id: r.pigId, week_number: r.weekNumber,
        image_url: r.remoteUrl || r.localUri, capture_date: r.captureDate, notes: r.notes || '',
        created_at: null, updated_at: new Date(r.updatedAt).toISOString(), synced: !!r.synced,
      }));
      state.onRemoteUpdate('pigWeeklyImages', images);
    } catch (err) {
      console.warn('[ASF Sync] failed to refresh UI cache after image sync:', err);
    }
  }
}
