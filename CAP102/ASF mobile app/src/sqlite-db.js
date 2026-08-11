/* ══════════════════════════════════════════════════════════════════════
   ASF — Local SQLite Database (offline-first storage layer)
   ══════════════════════════════════════════════════════════════════════
   This is the durable, offline-capable local database. It sits BELOW the
   app's existing synchronous window.DB (localStorage/in-memory) layer —
   see the "SQLite bridge" section in src/auth-main.js for how the two are
   connected. Nothing in the huge classic <script> in index.html talks to
   this file directly; it only ever goes through window.DB.get/set, which
   auth-main.js has taught to also write through to SQLite in the
   background. This file has no knowledge of the UI at all.

   Why a separate file: @capacitor-community/sqlite is fully async (every
   call is a Promise, even on native), while window.DB.get/set are used
   synchronously in 100+ places across the existing app. Rewriting all of
   those call sites to be async would be a huge, high-risk change to code
   that already works — so instead SQLite is a background-durable mirror,
   exactly like the Firestore write-through sync added earlier, just one
   layer closer to the device.

   Platform behavior:
     - Android / iOS: @capacitor-community/sqlite talks to a real native
       SQLite database file on-disk — this is what makes offline storage
       durable across app restarts and reinstalls-with-backup.
     - Web (npm run dev, or any browser): there is no native SQLite, so the
       plugin uses "jeep-sqlite" — a Stencil web component that runs SQLite
       compiled to WebAssembly (sql.js) and persists it to IndexedDB. This
       is what lets `npm run dev` and a plain browser tab exercise the same
       offline code paths as the native apps.
   ══════════════════════════════════════════════════════════════════════ */

import { CapacitorSQLite, SQLiteConnection } from '@capacitor-community/sqlite';
import { Capacitor } from '@capacitor/core';
import { defineCustomElements as defineJeepSqlite } from 'jeep-sqlite/loader';

const DB_NAME = 'asf_offline';

/* Every table follows one of two shapes:
   - AGGREGATE tables (feedingLogs, healthLogs, expenses, growthLogs,
     settings, reports): the existing app already reads/writes each of
     these as ONE whole JSON array/object per category (see the ck() keys
     in index.html — 'feedLogs', 'healthLogs', 'expenses', 'weightLogs',
     etc.). Mirroring that same shape into one row per (uid, subkey) is a
     deliberate, honest scope choice: it's what the existing code already
     does, it's correct for this app's scale (a backyard/small commercial
     raiser's records, not a fleet), and it avoids inventing a normalized
     per-record schema the rest of the app was never built around. A real
     `id` primary key, `uid` relationship, `updatedAt` timestamp, and
     `synced` flag are still present on every row for correct offline
     tracking and conflict resolution.
   - PER-ROW tables (pigs, weeklyPigImages, notifications): each record
     already has its own stable id and genuinely independent lifecycle
     (one pig can be edited while another isn't touched; one photo can
     fail to upload without blocking the others) — these get one row per
     record, exactly like the Firestore per-doc mirror added earlier. */
const SCHEMA_STATEMENTS = [
  `CREATE TABLE IF NOT EXISTS users (
     id TEXT PRIMARY KEY,
     fullName TEXT, phoneNumber TEXT, municipality TEXT, email TEXT,
     role TEXT, profileImage TEXT, verified INTEGER DEFAULT 0,
     onboardingCompleted INTEGER DEFAULT 0,
     createdAt INTEGER, updatedAt INTEGER NOT NULL, synced INTEGER DEFAULT 0
   );`,
  `CREATE TABLE IF NOT EXISTS pigs (
     id TEXT PRIMARY KEY,
     uid TEXT NOT NULL,
     data TEXT NOT NULL,
     updatedAt INTEGER NOT NULL,
     synced INTEGER DEFAULT 0,
     deleted INTEGER DEFAULT 0
   );`,
  `CREATE INDEX IF NOT EXISTS idx_pigs_uid ON pigs(uid);`,
  `CREATE TABLE IF NOT EXISTS feedingLogs (
     id TEXT PRIMARY KEY, uid TEXT NOT NULL, subkey TEXT NOT NULL,
     data TEXT NOT NULL, updatedAt INTEGER NOT NULL, synced INTEGER DEFAULT 0
   );`,
  `CREATE INDEX IF NOT EXISTS idx_feedingLogs_uid ON feedingLogs(uid);`,
  `CREATE TABLE IF NOT EXISTS healthLogs (
     id TEXT PRIMARY KEY, uid TEXT NOT NULL, subkey TEXT NOT NULL,
     data TEXT NOT NULL, updatedAt INTEGER NOT NULL, synced INTEGER DEFAULT 0
   );`,
  `CREATE INDEX IF NOT EXISTS idx_healthLogs_uid ON healthLogs(uid);`,
  `CREATE TABLE IF NOT EXISTS growthLogs (
     id TEXT PRIMARY KEY, uid TEXT NOT NULL, subkey TEXT NOT NULL,
     data TEXT NOT NULL, updatedAt INTEGER NOT NULL, synced INTEGER DEFAULT 0
   );`,
  `CREATE INDEX IF NOT EXISTS idx_growthLogs_uid ON growthLogs(uid);`,
  `CREATE TABLE IF NOT EXISTS expenses (
     id TEXT PRIMARY KEY, uid TEXT NOT NULL, subkey TEXT NOT NULL,
     data TEXT NOT NULL, updatedAt INTEGER NOT NULL, synced INTEGER DEFAULT 0
   );`,
  `CREATE INDEX IF NOT EXISTS idx_expenses_uid ON expenses(uid);`,
  `CREATE TABLE IF NOT EXISTS notifications (
     id TEXT PRIMARY KEY,
     uid TEXT NOT NULL,
     type TEXT,
     data TEXT,
     read INTEGER DEFAULT 0,
     createdAt INTEGER NOT NULL,
     synced INTEGER DEFAULT 0
   );`,
  `CREATE INDEX IF NOT EXISTS idx_notifications_uid ON notifications(uid);`,
  `CREATE TABLE IF NOT EXISTS reports (
     id TEXT PRIMARY KEY, uid TEXT NOT NULL, subkey TEXT NOT NULL,
     data TEXT NOT NULL, updatedAt INTEGER NOT NULL, synced INTEGER DEFAULT 0
   );`,
  `CREATE TABLE IF NOT EXISTS weeklyPigImages (
     id TEXT PRIMARY KEY,
     uid TEXT NOT NULL,
     pigId TEXT,
     weekNumber INTEGER,
     localUri TEXT,
     remoteUrl TEXT,
     captureDate TEXT,
     notes TEXT,
     updatedAt INTEGER NOT NULL,
     synced INTEGER DEFAULT 0,
     uploadAttempts INTEGER DEFAULT 0,
     deleted INTEGER DEFAULT 0
   );`,
  `CREATE INDEX IF NOT EXISTS idx_images_uid ON weeklyPigImages(uid);`,
  `CREATE TABLE IF NOT EXISTS settings (
     id TEXT PRIMARY KEY, uid TEXT NOT NULL, subkey TEXT NOT NULL,
     data TEXT, updatedAt INTEGER NOT NULL, synced INTEGER DEFAULT 0
   );`,
  `CREATE INDEX IF NOT EXISTS idx_settings_uid ON settings(uid);`,
  `CREATE TABLE IF NOT EXISTS sync_meta (
     id TEXT PRIMARY KEY, lastSyncAt INTEGER, lastSyncStatus TEXT
   );`,
  // Immutable activity/audit trail — one row per logged user action (login,
  // logout, task check, weigh-in, health log CRUD, settings change, key page
  // views). Push-only, exactly like `notifications` above: entries are
  // created once and never edited/deleted anywhere in the app, so there's no
  // "unsynced update" case to handle, only "unsynced insert". The real
  // immutability guarantee lives in Supabase's RLS (insert+select policies
  // only, no update/delete — see supabase_schema.sql) — this local copy is
  // just the offline-durable staging area before that push happens, plus the
  // fast local read source for the Settings ▸ Activity Log screen.
  `CREATE TABLE IF NOT EXISTS activityLogs (
     id TEXT PRIMARY KEY,
     uid TEXT NOT NULL,
     actionType TEXT,
     description TEXT,
     username TEXT,
     createdAt INTEGER NOT NULL,
     synced INTEGER DEFAULT 0
   );`,
  `CREATE INDEX IF NOT EXISTS idx_activityLogs_uid ON activityLogs(uid);`,
];

let sqlite = null;
let db = null;
let readyPromise = null;

async function ensureWebStore() {
  if (Capacitor.getPlatform() !== 'web') return;
  defineJeepSqlite(window);
  await customElements.whenDefined('jeep-sqlite');
  let el = document.querySelector('jeep-sqlite');
  if (!el) {
    el = document.createElement('jeep-sqlite');
    document.body.appendChild(el);
  }
  // Points the component at /assets/sql-wasm.wasm (copied into place via
  // the public/assets/ folder — see vite.config.js comment + that file).
  el.wasmPath = 'assets';
  await customElements.whenDefined('jeep-sqlite');
  await sqlite.initWebStore();
}

/* Idempotent — safe to call from multiple places (auth-main.js calls this
   once at module load; anything else that needs the DB just awaits the
   same promise). Never throws: on any failure it logs and resolves false,
   so the rest of the app can keep working off window.DB/localStorage
   alone rather than crashing the whole boot sequence over a SQLite issue. */
export function initSqlite() {
  if (readyPromise) return readyPromise;
  readyPromise = (async () => {
    try {
      sqlite = new SQLiteConnection(CapacitorSQLite);
      await ensureWebStore();
      const consistency = await sqlite.checkConnectionsConsistency();
      const isConn = (await sqlite.isConnection(DB_NAME, false)).result;
      db = (consistency.result && isConn)
        ? await sqlite.retrieveConnection(DB_NAME, false)
        : await sqlite.createConnection(DB_NAME, false, 'no-encryption', 1, false);
      await db.open();
      for (const stmt of SCHEMA_STATEMENTS) {
        await db.execute(stmt);
      }
      // Safety net for installs that already had a `users` table before
      // onboardingCompleted existed — CREATE TABLE IF NOT EXISTS above is a
      // no-op on an existing table (same lesson as supabase_schema.sql's
      // "column safety net"). SQLite has no ADD COLUMN IF NOT EXISTS, so
      // this just swallows the "duplicate column name" error on installs
      // that already have it (including brand-new ones created via the
      // statement above, which already includes the column).
      try {
        await db.execute('ALTER TABLE users ADD COLUMN onboardingCompleted INTEGER DEFAULT 0;');
      } catch (migErr) {
        // Expected on every install that already has the column — only log
        // if it's something unexpected, to avoid noisy console spam.
        if (!/duplicate column/i.test(String(migErr?.message || migErr))) {
          console.warn('[ASF SQLite] onboardingCompleted migration warning:', migErr);
        }
      }
      return true;
    } catch (err) {
      console.error('[ASF SQLite] initialization failed — offline SQLite layer disabled, falling back to localStorage only:', err);
      db = null;
      return false;
    }
  })();
  return readyPromise;
}

export async function sqliteIsReady() {
  return await initSqlite();
}

const nowMs = () => Date.now();

/* ── Aggregate table helpers (feedingLogs / healthLogs / expenses /
   growthLogs / reports / settings — one row per uid+subkey) ── */
export async function getAggregate(table, uid, subkey = 'main') {
  if (!(await sqliteIsReady())) return null;
  const id = `${uid}:${subkey}`;
  try {
    const res = await db.query(`SELECT data FROM ${table} WHERE id = ?`, [id]);
    const row = res.values && res.values[0];
    if (!row || row.data == null) return null;
    try {
      return JSON.parse(row.data);
    } catch (parseErr) {
      console.warn(`[ASF SQLite] corrupted row in ${table} (${id}) — ignoring and treating as empty:`, parseErr);
      return null;
    }
  } catch (err) {
    console.warn(`[ASF SQLite] getAggregate(${table}) failed:`, err);
    return null;
  }
}

export async function setAggregate(table, uid, subkey, value, opts = {}) {
  if (!(await sqliteIsReady())) return false;
  const id = `${uid}:${subkey}`;
  const updatedAt = opts.updatedAt || nowMs();
  const synced = opts.synced ? 1 : 0;
  try {
    await db.run(
      `INSERT INTO ${table} (id, uid, subkey, data, updatedAt, synced) VALUES (?,?,?,?,?,?)
       ON CONFLICT(id) DO UPDATE SET data=excluded.data, updatedAt=excluded.updatedAt, synced=excluded.synced`,
      [id, uid, subkey, JSON.stringify(value), updatedAt, synced]
    );
    return true;
  } catch (err) {
    console.warn(`[ASF SQLite] setAggregate(${table}) failed:`, err);
    return false;
  }
}

export async function getUnsyncedAggregates(table, uid) {
  if (!(await sqliteIsReady())) return [];
  try {
    const res = await db.query(`SELECT id, subkey, data, updatedAt FROM ${table} WHERE uid = ? AND synced = 0`, [uid]);
    return (res.values || []).map(r => ({ ...r, data: safeParse(r.data) }));
  } catch (err) {
    console.warn(`[ASF SQLite] getUnsyncedAggregates(${table}) failed:`, err);
    return [];
  }
}

export async function markAggregateSynced(table, uid, subkey) {
  if (!(await sqliteIsReady())) return;
  try {
    await db.run(`UPDATE ${table} SET synced = 1 WHERE id = ?`, [`${uid}:${subkey}`]);
  } catch (err) {
    console.warn(`[ASF SQLite] markAggregateSynced(${table}) failed:`, err);
  }
}

/* ── Per-row table helpers (pigs / weeklyPigImages / notifications) ── */
export async function upsertRow(table, row) {
  if (!(await sqliteIsReady())) return false;
  const cols = Object.keys(row);
  const placeholders = cols.map(() => '?').join(',');
  const updates = cols.filter(c => c !== 'id').map(c => `${c}=excluded.${c}`).join(',');
  try {
    await db.run(
      `INSERT INTO ${table} (${cols.join(',')}) VALUES (${placeholders})
       ON CONFLICT(id) DO UPDATE SET ${updates}`,
      cols.map(c => row[c])
    );
    return true;
  } catch (err) {
    console.warn(`[ASF SQLite] upsertRow(${table}) failed:`, err);
    return false;
  }
}

export async function getRows(table, uid, { includeDeleted = false } = {}) {
  if (!(await sqliteIsReady())) return [];
  try {
    const sql = includeDeleted
      ? `SELECT * FROM ${table} WHERE uid = ?`
      : `SELECT * FROM ${table} WHERE uid = ? AND (deleted IS NULL OR deleted = 0)`;
    const res = await db.query(sql, [uid]);
    return res.values || [];
  } catch (err) {
    console.warn(`[ASF SQLite] getRows(${table}) failed:`, err);
    return [];
  }
}

export async function getUnsyncedRows(table, uid) {
  if (!(await sqliteIsReady())) return [];
  try {
    const res = await db.query(`SELECT * FROM ${table} WHERE uid = ? AND synced = 0`, [uid]);
    return res.values || [];
  } catch (err) {
    console.warn(`[ASF SQLite] getUnsyncedRows(${table}) failed:`, err);
    return [];
  }
}

export async function markRowSynced(table, id, extra = {}) {
  if (!(await sqliteIsReady())) return;
  const sets = ['synced = 1', ...Object.keys(extra).map(k => `${k} = ?`)];
  try {
    await db.run(`UPDATE ${table} SET ${sets.join(', ')} WHERE id = ?`, [...Object.values(extra), id]);
  } catch (err) {
    console.warn(`[ASF SQLite] markRowSynced(${table}) failed:`, err);
  }
}

export async function softDeleteRow(table, id) {
  if (!(await sqliteIsReady())) return;
  try {
    await db.run(`UPDATE ${table} SET deleted = 1, synced = 0, updatedAt = ? WHERE id = ?`, [nowMs(), id]);
  } catch (err) {
    console.warn(`[ASF SQLite] softDeleteRow(${table}) failed:`, err);
  }
}

/* ── activityLogs (immutable audit trail) — its own reader since the table
   has no `deleted` column (nothing here is ever deleted, so getRows()'s
   soft-delete filter doesn't apply) and the Settings ▸ Activity Log screen
   wants newest-first ordering straight from SQLite. ── */
export async function getActivityLogs(uid) {
  if (!(await sqliteIsReady())) return [];
  try {
    const res = await db.query(`SELECT * FROM activityLogs WHERE uid = ? ORDER BY createdAt DESC`, [uid]);
    return res.values || [];
  } catch (err) {
    console.warn('[ASF SQLite] getActivityLogs failed:', err);
    return [];
  }
}

/* ── users table (single profile row per uid) ── */
export async function upsertUser(profile) {
  return upsertRow('users', profile);
}
export async function getUser(uid) {
  if (!(await sqliteIsReady())) return null;
  try {
    const res = await db.query(`SELECT * FROM users WHERE id = ?`, [uid]);
    return (res.values && res.values[0]) || null;
  } catch (err) {
    console.warn('[ASF SQLite] getUser failed:', err);
    return null;
  }
}

export async function setSyncMeta(uid, status) {
  if (!(await sqliteIsReady())) return;
  try {
    await db.run(
      `INSERT INTO sync_meta (id, lastSyncAt, lastSyncStatus) VALUES (?,?,?)
       ON CONFLICT(id) DO UPDATE SET lastSyncAt=excluded.lastSyncAt, lastSyncStatus=excluded.lastSyncStatus`,
      [uid, nowMs(), status]
    );
  } catch (err) {
    console.warn('[ASF SQLite] setSyncMeta failed:', err);
  }
}

function safeParse(str) {
  try { return JSON.parse(str); } catch (_) { return null; }
}

export { nowMs };
