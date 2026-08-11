# ASF — Offline-First SQLite + Firebase Sync: Implementation Report

Firebase has **not** been removed. SQLite is now the app's real offline data
store; Firebase (Auth + Firestore + Storage) remains the cloud backend, and a
new sync engine keeps the two in agreement whenever the device is online.

## 1. What changed

**Architecture — three layers, each with one job:**

1. **localStorage / in-memory cache (`window.DB`)** — unchanged. Every one
   of the app's 100+ existing read/write call sites (Dashboard, Pig
   Management, Health Monitor, Feeding, Growth, Expenses, Settings,
   Notifications) still reads and writes this exact same way, synchronously.
   Zero risk to existing features.
2. **SQLite (new, `src/sqlite-db.js`)** — the real, durable offline store.
   Every `DB.set()` call is now also written through to SQLite in the
   background. Ten tables were created exactly as specified: `users`,
   `pigs`, `feedingLogs`, `healthLogs`, `growthLogs`, `expenses`,
   `notifications`, `reports`, `weeklyPigImages`, `settings`. Each row
   carries an `updatedAt` timestamp and a `synced` flag.
3. **Firestore (cloud)** — no longer written to directly by the UI. Only
   the new sync engine (`src/sync-engine.js`) talks to it, in the
   background, when connectivity allows.

**New files:**
- `src/sqlite-db.js` — SQLite schema + generic get/set/upsert helpers for
  both "one row per record" tables (pigs, weeklyPigImages, notifications)
  and "one JSON blob per category" tables (feedingLogs, healthLogs,
  expenses, growthLogs, settings — matching how the app already stores
  these as whole arrays/objects).
- `src/sync-engine.js` — connectivity monitoring, push/pull sync logic,
  conflict resolution, photo uploads, retry loop.
- `public/assets/sql-wasm.wasm` — the WASM SQLite engine used for the web
  build (native Android/iOS use the device's real SQLite instead).

**Modified files:**
- `src/auth-main.js` — boot sequence now hydrates the UI from SQLite first
  (instant, works offline), then enriches from Firestore in the background.
  Direct Firestore writes were replaced with SQLite write-through.
- `index.html` — added a small, non-blocking sync-status strip (reusing the
  pre-existing "Synced with mobile app" bar) that now shows real Online /
  Offline / Syncing / Sync Complete / Sync Failed states, plus a
  `<jeep-sqlite>` element required for the web build's SQLite fallback.
- `package.json` — added `@capacitor-community/sqlite`, `@capacitor/network`,
  `jeep-sqlite`.
- `firestore.rules` / `storage.rules` — reviewed; the existing generic
  per-uid rules already cover the new `weeklyPigImages` and `notifications`
  paths, no rule changes were required.

## 2. Synchronization workflow

- **Every local change** (add/edit/delete a pig, health log, feeding log,
  growth entry, expense, weekly photo, settings change) is written to
  SQLite immediately and marked `synced = 0`. This happens whether the
  device is online or offline — the UI never waits on a network call.
- **Debounced push**: 800ms after the last change, a sync run starts
  (collapses rapid edits — e.g. typing — into one network round trip).
- **Connectivity-triggered push**: going from offline → online also
  triggers an immediate sync run.
- **Periodic retry**: every 60 seconds, any still-unsynced rows (e.g. a
  photo upload that failed mid-transfer) are retried automatically — no
  user action needed.
- **Conflict resolution**: before pushing a local record, the sync engine
  checks the remote copy's `updatedAt`. Newer wins — if local is newer, it
  pushes; if remote is newer, it pulls that into SQLite instead and updates
  the on-screen data in place (never overwrites what the user is actively
  looking at, never duplicates records).
- **Weekly pig photos**: saved to SQLite immediately (visible offline right
  away). Once online, the image uploads to Firebase Storage, the resulting
  URL is saved to Firestore, and the local row is marked synced. A failed
  upload is left unsynced and retried automatically by the periodic loop.
- **Pull-side updates** (e.g. a change made on another device) are applied
  back into the UI without re-marking them dirty, so pulling data never
  triggers a duplicate re-push.

## 3. Manual setup steps (cannot be automated here)

1. **Install dependencies on your own machine** — this sandbox could
   install and build against the new packages, but your real project
   folder's `node_modules` needs the same: run `npm install` in the project
   folder once before your next build.
2. **Native sync** — after `npm run build`, run `npx cap sync` (or
   `npm run sync`) on your own machine so Android Studio / Xcode pick up
   the new SQLite plugin's native code. This sandbox cannot run
   `npx cap sync` reliably (a pre-existing environment limitation, not
   specific to this change).
3. **Two harmless leftover files**: `src/_synccheck.mjs` and
   `src/_authcheck.mjs` were created earlier this session as temporary
   syntax-verification scratch files. They are not imported by anything and
   Vite will not bundle them, but this sandbox's OneDrive-mounted filesystem
   would not allow deleting them (`Operation not permitted`). Feel free to
   delete both from the `src/` folder manually — nothing depends on them.
4. **No SQLite encryption is configured** (matches the spec — this is an
   offline cache, not a place for secrets). If you later want the local
   database encrypted at rest, that's an optional `CapacitorSQLite` config
   block in `capacitor.config.json`, not required for this feature to work.

## 4. Offline operation — confirmed by design and static verification

- A user with a **valid existing Firebase session** launches the app: the
  boot sequence now hydrates the entire Dashboard from SQLite *before*
  touching the network, so the app is fully usable offline immediately.
  Firestore is only consulted afterward, in the background, and never
  blocks or delays the UI.
- Adding/editing/deleting pigs, health logs, feeding logs, growth entries,
  expenses, and weekly photos all write to SQLite synchronously — none of
  it depends on connectivity.
- A **user who has never signed in** still requires internet for that
  first sign-in (Firebase Auth itself needs the network to verify OTP /
  email+password) — this matches the spec exactly.
- Reconnecting triggers an automatic, silent sync — no dialogs, no
  interrupting whatever page the user is on.

Caveat: this sandbox has no real browser (IndexedDB), no Android emulator,
and no iOS simulator, and Google/Firebase domains are network-blocked here —
so the above is verified through code review, a clean Vite production build,
and translation/schema consistency checks, not a live runtime test. I'd
recommend a quick manual pass on your device (airplane mode → use the app →
reconnect → confirm the sync badge goes Syncing → Sync Complete) before
treating this as fully production-verified.

## 5. Build status

- **Web**: `npm install && npm run build` completed cleanly in an isolated
  environment — 44 modules bundled, output includes `dist/assets/sql-wasm.wasm`
  (659,730 bytes, required for the web SQLite fallback) and the jeep-sqlite
  component bundle. One informational (non-blocking) warning about a
  `crypto` module being externalized for browser use — expected and normal
  for this kind of package, not an error.
- **Android / iOS**: `index.html` (which both platforms load) was verified
  byte-for-byte identical across the root project, `android/app/src/main/
  assets/public/`, and `ios/App/App/public/`. Native builds themselves need
  `npx cap sync` run on your machine per the manual step above.

### A note on an environment issue hit during this session

Partway through, this sandbox's file-mount briefly served a truncated,
several-hours-stale copy of `index.html` and `src/auth-main.js` to shell
commands (while the file-editing tools themselves had the correct, current
content — a known quirk of the OneDrive-synced folder mount in this
environment). I caught it via a UTF-8/line-count check before it could
affect your files, reconstructed the correct content, and re-verified the
build against it. Your actual files are correct; flagging this only so it's
not a mystery if you notice odd sync delays from OneDrive after a large
edit session like this one.
