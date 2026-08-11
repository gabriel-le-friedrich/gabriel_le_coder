-- ═══════════════════════════════════════════════════════════════════════
-- ASF (Administration for Swine Finisher) — Supabase Schema
-- ═══════════════════════════════════════════════════════════════════════
-- Single, self-contained, production-ready schema. Paste this whole file
-- into Supabase Dashboard → SQL Editor → "New query" → Run. Every
-- statement is idempotent (IF NOT EXISTS / OR REPLACE / DROP ... IF
-- EXISTS first) — safe to run again after a partial failure, and safe to
-- run against a project that already has some of this from an earlier
-- version of this file.
--
-- Backend model (per integration_prompt.md): Firebase Authentication is
-- the ONLY identity provider — there is no Supabase Auth user here.
-- firebase_uid (the Firebase Auth uid, a plain string, not a uuid) is the
-- ownership column on every table.
--
-- Identity via Third-Party Auth (Firebase): Supabase's Firebase
-- Third-Party Auth integration is registered for this project (Dashboard
-- → Authentication → Sign In / Providers → Third-Party Auth), and the
-- Flutter app's Supabase client passes the current Firebase ID token as
-- its accessToken on every request (see
-- flutter_app/lib/core/config/supabase_config.dart). That makes
-- `auth.jwt()->>'sub'` a cryptographically verified Firebase uid inside
-- every RLS policy below — real per-user row-level security, not just an
-- app-enforced convention. `auth.jwt()->>'sub'` is used rather than
-- `auth.uid()` deliberately: `auth.uid()` casts the JWT's sub claim to
-- Postgres's uuid type, which errors/returns null for Firebase's
-- non-UUID string uids, whereas `->>'sub'` extracts it as plain text —
-- exactly the type firebase_uid columns already use throughout this
-- schema. See FIREBASE_THIRDPARTY_AUTH_SETUP.md (repo root) for the full
-- setup this depends on: the dashboard integration, the `role:
-- authenticated` custom-claim Cloud Function + backfill script, and the
-- Flutter accessToken wiring. Until every piece of that is live for a
-- given user, requests from that user carry no verifiable identity, so
-- `auth.jwt()->>'sub'` is null and these policies correctly deny access
-- rather than falling back to "allow everything" — the previous
-- `using (true)` behavior is gone, not just supplemented.
--
-- pigs.id is TEXT, not uuid: the app doesn't generate UUIDs for pigs — a
-- pig's id is a short code the farmer types on the Add Pig form (e.g.
-- "BIGAS-01"). Every foreign key that references pigs.id is text too, and
-- nullable, because two of the app's record types (daily feed logs, the
-- main weight chart) are recorded at the whole-batch level, not tied to
-- one individual pig — only per-pig weigh-ins from the Growth tab carry a
-- real pig_id.
-- ═══════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════
-- 1. TABLES (with all columns, constraints, and foreign keys inline —
--    nothing is added via a later ALTER TABLE in this file)
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.profiles (
  id                  uuid primary key default gen_random_uuid(),
  firebase_uid        text not null unique,
  full_name           text,
  email               text,
  phone_number        text,
  municipality        text,
  province            text,
  farm_name           text,
  farmer_type         text default 'Backyard Raiser',
  profile_image_url   text,
  verified            boolean not null default true,
  -- Phone Auth audit: explicit, unambiguous flag for "this account's phone
  -- number completed OTP verification" (verified above is a broader,
  -- pre-existing "account setup complete" flag) — set true by the app the
  -- moment linkWithCredential()/signInWithCredential() succeeds, never
  -- before. last_login is stamped on every successful sign-in, whether
  -- via email/password or phone OTP.
  phone_verified      boolean not null default true,
  last_login          timestamptz,
  role                text not null default 'raiser',
  onboarding_completed boolean not null default false,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- pigs.id is app-assigned text (see header note) — no default generator.
create table if not exists public.pigs (
  id                  text primary key,
  firebase_uid        text not null references public.profiles(firebase_uid) on delete cascade,
  tag_number          text,
  name                text,
  breed               text,
  gender              text,
  birth_date          date,
  arrival_date        date,
  initial_weight_kg   numeric(6,2),
  current_weight_kg   numeric(6,2),
  pen_number          text,
  status              text not null default 'active'
                       check (status in ('active','sold','deceased')),
  photo_url           text,
  notes               text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- ── Safety net for projects that already ran an earlier version of this
--    schema: CREATE TABLE IF NOT EXISTS above is a no-op if `pigs`
--    already existed (e.g. from before pigs.id was switched from uuid to
--    text) — it does NOT change an existing table's column types. Without
--    this fix-up, every table below that references pigs.id would fail
--    with "incompatible types: text and uuid" the moment its foreign key
--    is created. This block only does anything if pigs.id is still uuid;
--    on a fresh project (or one already fixed) it's a harmless no-op. ──
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'pigs'
      and column_name = 'id' and data_type = 'uuid'
  ) then
    execute 'alter table if exists public.feeding_logs drop constraint if exists feeding_logs_pig_id_fkey';
    execute 'alter table if exists public.weight_records drop constraint if exists weight_records_pig_id_fkey';
    execute 'alter table if exists public.health_records drop constraint if exists health_records_pig_id_fkey';
    execute 'alter table if exists public.weekly_pig_images drop constraint if exists weekly_pig_images_pig_id_fkey';

    execute 'alter table public.pigs alter column id drop default';
    execute 'alter table public.pigs alter column id type text using id::text';

    execute 'alter table if exists public.feeding_logs alter column pig_id type text using pig_id::text';
    execute 'alter table if exists public.weight_records alter column pig_id type text using pig_id::text';
    execute 'alter table if exists public.health_records alter column pig_id type text using pig_id::text';
    execute 'alter table if exists public.weekly_pig_images alter column pig_id type text using pig_id::text';
  end if;
end $$;

-- Whole-batch feed logs have pig_id = null (the app auto-logs one entry
-- per completed cycle day, not per pig); per-pig feeding isn't tracked
-- separately today, so pig_id exists for forward-compatibility. sync_key
-- is the natural, always-non-null upsert key the sync engine uses so a
-- dropped connection + retry never creates a duplicate row (day_number is
-- unique per batch cycle, but NULL pig_id values are never equal to each
-- other in a plain unique constraint, so a real natural key is needed).
create table if not exists public.feeding_logs (
  id                  uuid primary key default gen_random_uuid(),
  firebase_uid        text not null references public.profiles(firebase_uid) on delete cascade,
  pig_id              text references public.pigs(id) on delete set null,
  sync_key            text,
  day_number          integer,
  feed_type           text,
  quantity_kg         numeric(6,2),
  fed_at              timestamptz default now(),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- Two shapes in one table: batch-level weigh-ins (pig_id null, day_number
-- set) from the main growth chart, and per-pig weigh-ins (pig_id set,
-- week_number set) from the Growth tab's per-pig tracking.
create table if not exists public.weight_records (
  id                  uuid primary key default gen_random_uuid(),
  firebase_uid        text not null references public.profiles(firebase_uid) on delete cascade,
  pig_id              text references public.pigs(id) on delete set null,
  sync_key            text,
  day_number          integer,
  week_number         integer,
  weight_kg           numeric(6,2) not null,
  recorded_at         timestamptz default now(),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- The app's health observation (behavior/appetite/physical condition/
-- waste/status, all multi-select) doesn't fit relational columns cleanly,
-- so the whole entry is packed into condition_notes as JSON text — fully
-- queryable via Postgres's ->> operators on condition_notes::jsonb, and
-- nothing is lost. app_entry_id is the app's own numeric health log id
-- (kept so edits/deletes round-trip correctly and retries stay idempotent).
create table if not exists public.health_records (
  id                  uuid primary key default gen_random_uuid(),
  firebase_uid        text not null references public.profiles(firebase_uid) on delete cascade,
  pig_id              text references public.pigs(id) on delete set null,
  app_entry_id        text,
  condition_notes     text,
  attachment_url      text,
  recorded_at         timestamptz default now(),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create table if not exists public.expenses (
  id                  uuid primary key default gen_random_uuid(),
  firebase_uid        text not null references public.profiles(firebase_uid) on delete cascade,
  app_entry_id        text,  -- the app's own numeric expense id
  category            text,
  description         text,
  amount              numeric(10,2),
  expense_date        text,
  note                text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- id is app-assigned text (a numeric-string counter), same reasoning as
-- pigs.id — keeps retries idempotent without a second id scheme.
create table if not exists public.notifications (
  id                  text primary key,
  firebase_uid        text not null references public.profiles(firebase_uid) on delete cascade,
  type                text,
  data                jsonb,
  read                boolean not null default false,
  created_at          timestamptz not null default now()
);

-- One row per (firebase_uid, subkey) — mirrors farmerProfile,
-- pigBatchProfile, notifPrefs, currentDay, dayLogs, weeklyTasks,
-- vetContacts, appLang exactly as the app already stores them locally
-- (one whole object per settings category).
create table if not exists public.settings (
  id                  uuid primary key default gen_random_uuid(),
  firebase_uid        text not null references public.profiles(firebase_uid) on delete cascade,
  subkey              text not null,
  data                jsonb,
  updated_at          timestamptz not null default now(),
  unique (firebase_uid, subkey)
);

-- id is app-assigned text, same reasoning as pigs.id / notifications.id.
create table if not exists public.weekly_pig_images (
  id                  text primary key,
  firebase_uid        text not null references public.profiles(firebase_uid) on delete cascade,
  pig_id              text references public.pigs(id) on delete set null,
  week_number         integer,
  image_url           text,
  capture_date        text,
  notes               text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- One row per firebase_uid — this app tracks a single active batch per
-- raiser (no multi-batch switching UI), so firebase_uid is unique here
-- even though the table has its own uuid id, mirroring exactly the
-- Batch Name / Number of Pigs / Starting Weight / Start Date / Feed Price
-- fields already collected on the Pig Profile Setup screen (and editable
-- again later from Settings). The app's own local copy of this same data
-- (ck('pigBatchProfile')) remains the source of truth every calculation
-- on-device reads from; this table exists so the data is queryable
-- directly in Supabase too, per the app's auth/onboarding spec.
create table if not exists public.farm_batches (
  id                  uuid primary key default gen_random_uuid(),
  firebase_uid        text not null unique references public.profiles(firebase_uid) on delete cascade,
  batch_name          text,
  number_of_pigs      integer,
  starting_weight     numeric(6,2),
  start_date          date,
  feed_price          numeric(10,2),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- One row per firebase_uid, mirroring ck('notifPrefs') (morning/afternoon/
-- weekly weigh-in/supplement reminders) into queryable columns. supplement
-- reminders don't have their own time-picker in the existing Settings UI
-- (only a daily/weekly frequency selector) — supplement_time is populated
-- with a sensible internal default so the reminder can actually be
-- scheduled, without adding a new UI control that wasn't there before.
create table if not exists public.notification_settings (
  id                  uuid primary key default gen_random_uuid(),
  firebase_uid        text not null unique references public.profiles(firebase_uid) on delete cascade,
  morning_enabled     boolean not null default true,
  morning_time        text,
  afternoon_enabled   boolean not null default true,
  afternoon_time      text,
  weekly_enabled      boolean not null default true,
  weekly_day          integer,
  supplement_enabled  boolean not null default true,
  supplement_time     text,
  updated_at          timestamptz not null default now()
);

-- Immutable activity/audit trail — append-only by design (see §3 below,
-- which deliberately creates ONLY insert + select policies for this table:
-- with RLS enabled, any operation with no matching policy is refused
-- outright, so UPDATE/DELETE are structurally impossible through the app's
-- anon-key access path, not just hidden in the UI). One row per logged
-- user action (login, logout, task check, weigh-in, health log CRUD,
-- settings change, key page views) — see src/auth-main.js's
-- recordActivityLog()/window.AsfLogActivity for the only code path that
-- writes here. username is a display-name snapshot at the time of the
-- action (not a live join to profiles), so a later name change never
-- rewrites history — consistent with "immutable" meaning the log reflects
-- what was true at the time, not what's true now.
create table if not exists public.activity_logs (
  id                  uuid primary key default gen_random_uuid(),
  firebase_uid        text not null references public.profiles(firebase_uid) on delete cascade,
  app_entry_id        text,  -- the local SQLite row's own id — lets a retried
                             -- push after a partial failure use upsert with
                             -- ignoreDuplicates instead of a real UPDATE
                             -- (this table's RLS has no update policy at all)
  username            text,
  action_type         text not null,
  description         text not null,
  created_at          timestamptz not null default now()
);


-- ── Column safety net: every CREATE TABLE above is IF NOT EXISTS, which
--    is a no-op on a table that already exists from an earlier partial
--    run of this file — it does NOT add columns a stale table is missing
--    (this is exactly what caused the "column sync_key does not exist"
--    error). These ADD COLUMN IF NOT EXISTS statements are themselves
--    idempotent and guarantee every column below exists no matter what
--    state the table was already in. Harmless no-op on a fresh table. ──
alter table public.profiles           add column if not exists firebase_uid       text;
alter table public.profiles           add column if not exists full_name         text;
alter table public.profiles           add column if not exists email             text;
alter table public.profiles           add column if not exists phone_number      text;
alter table public.profiles           add column if not exists municipality      text;
alter table public.profiles           add column if not exists province          text;
alter table public.profiles           add column if not exists farm_name         text;
alter table public.profiles           add column if not exists farmer_type       text default 'Backyard Raiser';
alter table public.profiles           add column if not exists profile_image_url text;
alter table public.profiles           add column if not exists verified          boolean not null default true;
alter table public.profiles           add column if not exists phone_verified    boolean not null default true;
alter table public.profiles           add column if not exists last_login        timestamptz;
alter table public.profiles           add column if not exists role              text not null default 'raiser';
alter table public.profiles           add column if not exists onboarding_completed boolean not null default false;
alter table public.profiles           add column if not exists created_at        timestamptz not null default now();
alter table public.profiles           add column if not exists updated_at        timestamptz not null default now();

alter table public.pigs               add column if not exists firebase_uid      text;
alter table public.pigs               add column if not exists tag_number        text;
alter table public.pigs               add column if not exists name              text;
alter table public.pigs               add column if not exists breed             text;
alter table public.pigs               add column if not exists gender            text;
alter table public.pigs               add column if not exists birth_date        date;
alter table public.pigs               add column if not exists arrival_date      date;
alter table public.pigs               add column if not exists initial_weight_kg numeric(6,2);
alter table public.pigs               add column if not exists current_weight_kg numeric(6,2);
alter table public.pigs               add column if not exists pen_number        text;
alter table public.pigs               add column if not exists status            text not null default 'active';
alter table public.pigs               add column if not exists photo_url         text;
alter table public.pigs               add column if not exists notes             text;
alter table public.pigs               add column if not exists created_at        timestamptz not null default now();
alter table public.pigs               add column if not exists updated_at        timestamptz not null default now();

alter table public.feeding_logs       add column if not exists firebase_uid      text;
alter table public.feeding_logs       add column if not exists pig_id            text;
alter table public.feeding_logs       add column if not exists sync_key          text;
alter table public.feeding_logs       add column if not exists day_number        integer;
alter table public.feeding_logs       add column if not exists feed_type         text;
alter table public.feeding_logs       add column if not exists quantity_kg       numeric(6,2);
alter table public.feeding_logs       add column if not exists fed_at            timestamptz default now();
alter table public.feeding_logs       add column if not exists created_at        timestamptz not null default now();
alter table public.feeding_logs       add column if not exists updated_at        timestamptz not null default now();

alter table public.weight_records     add column if not exists firebase_uid      text;
alter table public.weight_records     add column if not exists pig_id            text;
alter table public.weight_records     add column if not exists sync_key          text;
alter table public.weight_records     add column if not exists day_number        integer;
alter table public.weight_records     add column if not exists week_number       integer;
alter table public.weight_records     add column if not exists weight_kg         numeric(6,2);
alter table public.weight_records     add column if not exists recorded_at       timestamptz default now();
alter table public.weight_records     add column if not exists created_at        timestamptz not null default now();
alter table public.weight_records     add column if not exists updated_at        timestamptz not null default now();

alter table public.health_records     add column if not exists firebase_uid      text;
alter table public.health_records     add column if not exists pig_id            text;
alter table public.health_records     add column if not exists app_entry_id      text;
alter table public.health_records     add column if not exists condition_notes   text;
alter table public.health_records     add column if not exists attachment_url    text;
alter table public.health_records     add column if not exists recorded_at       timestamptz default now();
alter table public.health_records     add column if not exists created_at        timestamptz not null default now();
alter table public.health_records     add column if not exists updated_at        timestamptz not null default now();

alter table public.expenses           add column if not exists firebase_uid      text;
alter table public.expenses           add column if not exists app_entry_id      text;
alter table public.expenses           add column if not exists category          text;
alter table public.expenses           add column if not exists description       text;
alter table public.expenses           add column if not exists amount            numeric(10,2);
alter table public.expenses           add column if not exists expense_date      text;
alter table public.expenses           add column if not exists note              text;
alter table public.expenses           add column if not exists created_at        timestamptz not null default now();
alter table public.expenses           add column if not exists updated_at        timestamptz not null default now();

alter table public.notifications      add column if not exists firebase_uid      text;
alter table public.notifications      add column if not exists type              text;
alter table public.notifications      add column if not exists data              jsonb;
alter table public.notifications      add column if not exists read              boolean not null default false;
alter table public.notifications      add column if not exists created_at        timestamptz not null default now();

alter table public.settings           add column if not exists firebase_uid      text;
alter table public.settings           add column if not exists subkey            text;
alter table public.settings           add column if not exists data              jsonb;
alter table public.settings           add column if not exists updated_at        timestamptz not null default now();

alter table public.weekly_pig_images  add column if not exists firebase_uid      text;
alter table public.weekly_pig_images  add column if not exists pig_id            text;
alter table public.weekly_pig_images  add column if not exists week_number       integer;
alter table public.weekly_pig_images  add column if not exists image_url         text;
alter table public.weekly_pig_images  add column if not exists capture_date      text;
alter table public.weekly_pig_images  add column if not exists notes             text;
alter table public.weekly_pig_images  add column if not exists created_at        timestamptz not null default now();
alter table public.weekly_pig_images  add column if not exists updated_at        timestamptz not null default now();

alter table public.farm_batches       add column if not exists firebase_uid      text;
alter table public.farm_batches       add column if not exists batch_name        text;
alter table public.farm_batches       add column if not exists number_of_pigs    integer;
alter table public.farm_batches       add column if not exists starting_weight   numeric(6,2);
alter table public.farm_batches       add column if not exists start_date        date;
alter table public.farm_batches       add column if not exists feed_price        numeric(10,2);
alter table public.farm_batches       add column if not exists created_at        timestamptz not null default now();
alter table public.farm_batches       add column if not exists updated_at        timestamptz not null default now();

alter table public.notification_settings add column if not exists firebase_uid      text;
alter table public.notification_settings add column if not exists morning_enabled   boolean not null default true;
alter table public.notification_settings add column if not exists morning_time      text;
alter table public.notification_settings add column if not exists afternoon_enabled boolean not null default true;
alter table public.notification_settings add column if not exists afternoon_time    text;
alter table public.notification_settings add column if not exists weekly_enabled    boolean not null default true;
alter table public.notification_settings add column if not exists weekly_day        integer;
alter table public.notification_settings add column if not exists supplement_enabled boolean not null default true;
alter table public.notification_settings add column if not exists supplement_time   text;
alter table public.notification_settings add column if not exists updated_at        timestamptz not null default now();

alter table public.activity_logs      add column if not exists firebase_uid      text;
alter table public.activity_logs      add column if not exists app_entry_id      text;
alter table public.activity_logs      add column if not exists username          text;
alter table public.activity_logs      add column if not exists action_type       text;
alter table public.activity_logs      add column if not exists description       text;
alter table public.activity_logs      add column if not exists created_at        timestamptz not null default now();

-- ── Sync conflict-resolution metadata (added for the "sync conflict
--    metadata" task): device_id identifies which app install last wrote
--    a row, sync_version is a monotonic per-row version stamp (the Flutter
--    app sends its local updated_at epoch-ms as this value, so it doubles
--    as a last-write-wins comparison key without a separate counter),
--    last_synced_at is when this exact write reached Supabase. All three
--    are additive/nullable so existing rows and the legacy Ionic/Capacitor
--    app (which doesn't send them) keep working unchanged.
--    notifications and activity_logs never had updated_at either — added
--    here too since every synced table gets the same three new columns.
--    activity_logs has no UPDATE policy (see §3 below), so its
--    sync_version/last_synced_at are effectively insert-time-only,
--    matching that table's intentionally immutable design. ──
alter table public.profiles           add column if not exists device_id        text;
alter table public.profiles           add column if not exists sync_version     bigint;
alter table public.profiles           add column if not exists last_synced_at   timestamptz;

alter table public.pigs               add column if not exists device_id        text;
alter table public.pigs               add column if not exists sync_version     bigint;
alter table public.pigs               add column if not exists last_synced_at   timestamptz;

alter table public.feeding_logs       add column if not exists device_id        text;
alter table public.feeding_logs       add column if not exists sync_version     bigint;
alter table public.feeding_logs       add column if not exists last_synced_at   timestamptz;

alter table public.weight_records     add column if not exists device_id        text;
alter table public.weight_records     add column if not exists sync_version     bigint;
alter table public.weight_records     add column if not exists last_synced_at   timestamptz;

alter table public.health_records     add column if not exists device_id        text;
alter table public.health_records     add column if not exists sync_version     bigint;
alter table public.health_records     add column if not exists last_synced_at   timestamptz;

alter table public.expenses           add column if not exists device_id        text;
alter table public.expenses           add column if not exists sync_version     bigint;
alter table public.expenses           add column if not exists last_synced_at   timestamptz;

alter table public.notifications      add column if not exists device_id        text;
alter table public.notifications      add column if not exists sync_version     bigint;
alter table public.notifications      add column if not exists last_synced_at   timestamptz;

alter table public.settings           add column if not exists device_id        text;
alter table public.settings           add column if not exists sync_version     bigint;
alter table public.settings           add column if not exists last_synced_at   timestamptz;

alter table public.weekly_pig_images  add column if not exists device_id        text;
alter table public.weekly_pig_images  add column if not exists sync_version     bigint;
alter table public.weekly_pig_images  add column if not exists last_synced_at   timestamptz;

alter table public.farm_batches       add column if not exists device_id        text;
alter table public.farm_batches       add column if not exists sync_version     bigint;
alter table public.farm_batches       add column if not exists last_synced_at   timestamptz;

alter table public.activity_logs      add column if not exists device_id        text;
alter table public.activity_logs      add column if not exists sync_version     bigint;
alter table public.activity_logs      add column if not exists last_synced_at   timestamptz;

-- ── Structured log fields (logging system audit fix #1): action (e.g.
--    LOGIN, LOGOUT, REGISTER, EXPENSE_ADD) and status (SUCCESS/FAILED) as
--    explicit columns, instead of only a free-text description that
--    narrated the outcome in prose (e.g. "failed login attempt (wrong
--    password)"). Both nullable/additive — rows written before the
--    SQLite-side app update that started populating them keep working
--    unchanged, action_type/description are untouched and still always
--    present. ──
alter table public.activity_logs      add column if not exists action           text;
alter table public.activity_logs      add column if not exists status           text;


-- ═══════════════════════════════════════════════════════════════════════
-- 2. INDEXES (after every table above exists)
-- ═══════════════════════════════════════════════════════════════════════

create unique index if not exists uniq_profiles_firebase_uid    on public.profiles(firebase_uid);

create index if not exists idx_pigs_firebase_uid                on public.pigs(firebase_uid);

create index if not exists idx_feeding_logs_firebase_uid        on public.feeding_logs(firebase_uid);
create index if not exists idx_feeding_logs_pig_id              on public.feeding_logs(pig_id);
create unique index if not exists uniq_feeding_logs_sync_key    on public.feeding_logs(firebase_uid, sync_key);

create index if not exists idx_weight_records_firebase_uid      on public.weight_records(firebase_uid);
create index if not exists idx_weight_records_pig_id            on public.weight_records(pig_id);
create unique index if not exists uniq_weight_records_sync_key  on public.weight_records(firebase_uid, sync_key);

create index if not exists idx_health_records_firebase_uid      on public.health_records(firebase_uid);
create index if not exists idx_health_records_pig_id            on public.health_records(pig_id);
create unique index if not exists uniq_health_records_entry     on public.health_records(firebase_uid, app_entry_id);

create index if not exists idx_expenses_firebase_uid            on public.expenses(firebase_uid);
create unique index if not exists uniq_expenses_entry           on public.expenses(firebase_uid, app_entry_id);

create index if not exists idx_notifications_firebase_uid       on public.notifications(firebase_uid);

create index if not exists idx_settings_firebase_uid            on public.settings(firebase_uid);
create unique index if not exists uniq_settings_subkey          on public.settings(firebase_uid, subkey);

create index if not exists idx_weekly_pig_images_firebase_uid   on public.weekly_pig_images(firebase_uid);

create unique index if not exists uniq_farm_batches_firebase_uid on public.farm_batches(firebase_uid);

create unique index if not exists uniq_notification_settings_firebase_uid on public.notification_settings(firebase_uid);

create index if not exists idx_activity_logs_firebase_uid       on public.activity_logs(firebase_uid);
create index if not exists idx_activity_logs_created_at         on public.activity_logs(created_at desc);
create unique index if not exists uniq_activity_logs_entry      on public.activity_logs(firebase_uid, app_entry_id);


-- ═══════════════════════════════════════════════════════════════════════
-- 3. ROW LEVEL SECURITY — Option A (permissive; app enforces firebase_uid)
-- ═══════════════════════════════════════════════════════════════════════

alter table public.profiles              enable row level security;
alter table public.pigs                  enable row level security;
alter table public.feeding_logs          enable row level security;
alter table public.weight_records        enable row level security;
alter table public.health_records        enable row level security;
alter table public.expenses              enable row level security;
alter table public.notifications         enable row level security;
alter table public.settings              enable row level security;
alter table public.weekly_pig_images     enable row level security;
alter table public.farm_batches          enable row level security;
alter table public.notification_settings enable row level security;
alter table public.activity_logs         enable row level security;

-- Real per-user row-level security: every policy below compares this
-- table's firebase_uid column against auth.jwt()->>'sub' — the verified
-- Firebase uid Postgres now sees once Third-Party Auth is configured (see
-- FIREBASE_THIRDPARTY_AUTH_SETUP.md). auth.jwt()->>'sub' is null for any
-- request that doesn't carry a verified Firebase token (signed-out app
-- state, a bare anon-key REST/curl call, a JWT from an unrelated
-- project), and `firebase_uid = null` is never true in SQL, so those
-- requests are correctly denied rather than falling through to "allow
-- everything" the way the old `using (true)` policies did.
drop policy if exists "Allow all (app-enforced access control)" on public.profiles;
create policy "Allow all (app-enforced access control)" on public.profiles
  for all using (firebase_uid = auth.jwt()->>'sub') with check (firebase_uid = auth.jwt()->>'sub');

drop policy if exists "Allow all (app-enforced access control)" on public.pigs;
create policy "Allow all (app-enforced access control)" on public.pigs
  for all using (firebase_uid = auth.jwt()->>'sub') with check (firebase_uid = auth.jwt()->>'sub');

drop policy if exists "Allow all (app-enforced access control)" on public.feeding_logs;
create policy "Allow all (app-enforced access control)" on public.feeding_logs
  for all using (firebase_uid = auth.jwt()->>'sub') with check (firebase_uid = auth.jwt()->>'sub');

drop policy if exists "Allow all (app-enforced access control)" on public.weight_records;
create policy "Allow all (app-enforced access control)" on public.weight_records
  for all using (firebase_uid = auth.jwt()->>'sub') with check (firebase_uid = auth.jwt()->>'sub');

drop policy if exists "Allow all (app-enforced access control)" on public.health_records;
create policy "Allow all (app-enforced access control)" on public.health_records
  for all using (firebase_uid = auth.jwt()->>'sub') with check (firebase_uid = auth.jwt()->>'sub');

drop policy if exists "Allow all (app-enforced access control)" on public.expenses;
create policy "Allow all (app-enforced access control)" on public.expenses
  for all using (firebase_uid = auth.jwt()->>'sub') with check (firebase_uid = auth.jwt()->>'sub');

drop policy if exists "Allow all (app-enforced access control)" on public.notifications;
create policy "Allow all (app-enforced access control)" on public.notifications
  for all using (firebase_uid = auth.jwt()->>'sub') with check (firebase_uid = auth.jwt()->>'sub');

drop policy if exists "Allow all (app-enforced access control)" on public.settings;
create policy "Allow all (app-enforced access control)" on public.settings
  for all using (firebase_uid = auth.jwt()->>'sub') with check (firebase_uid = auth.jwt()->>'sub');

drop policy if exists "Allow all (app-enforced access control)" on public.weekly_pig_images;
create policy "Allow all (app-enforced access control)" on public.weekly_pig_images
  for all using (firebase_uid = auth.jwt()->>'sub') with check (firebase_uid = auth.jwt()->>'sub');

drop policy if exists "Allow all (app-enforced access control)" on public.farm_batches;
create policy "Allow all (app-enforced access control)" on public.farm_batches
  for all using (firebase_uid = auth.jwt()->>'sub') with check (firebase_uid = auth.jwt()->>'sub');

drop policy if exists "Allow all (app-enforced access control)" on public.notification_settings;
create policy "Allow all (app-enforced access control)" on public.notification_settings
  for all using (firebase_uid = auth.jwt()->>'sub') with check (firebase_uid = auth.jwt()->>'sub');

-- activity_logs is deliberately DIFFERENT from every table above: only
-- INSERT and SELECT policies exist (same firebase_uid = auth.jwt()->>'sub'
-- scoping as everywhere else — see src/auth-main.js's
-- recordActivityLog()/getActivityLogsCombined()). There is NO UPDATE and
-- NO DELETE policy for this table, anywhere in this file, on purpose —
-- with row level security enabled, Postgres denies any operation that has
-- no matching policy, so this makes the log genuinely append-only at the
-- database level, not just hidden in the app's UI. If you ever need to
-- prune old entries, that must be a deliberate, separate admin action run
-- directly in the Supabase SQL editor (which bypasses RLS as the table
-- owner) — never something the app itself can do.
drop policy if exists "Allow insert (app-enforced access control)" on public.activity_logs;
create policy "Allow insert (app-enforced access control)" on public.activity_logs
  for insert with check (firebase_uid = auth.jwt()->>'sub');
drop policy if exists "Allow select (app-enforced access control)" on public.activity_logs;
create policy "Allow select (app-enforced access control)" on public.activity_logs
  for select using (firebase_uid = auth.jwt()->>'sub');


-- ═══════════════════════════════════════════════════════════════════════
-- 4. STORAGE — pig-photos bucket (public) + Option A-compatible policies
-- ═══════════════════════════════════════════════════════════════════════

insert into storage.buckets (id, name, public)
values ('pig-photos', 'pig-photos', true)
on conflict (id) do nothing;

-- Security fix (Supabase Storage advisor warning: "Two broad SELECT
-- policies on storage.objects allow clients to retrieve a full list of
-- files"). The previous `for all using (bucket_id = 'pig-photos')` policy
-- covered SELECT too, which is exactly what lets any client holding the
-- anon key call `.storage.from('pig-photos').list()` and enumerate every
-- user's file paths — the app's own uid-based folder naming
-- ("<uid>/<pigId>/week_N.jpg") was never actually enforced by anything,
-- it just relied on nobody calling list().
--
-- The app itself (see PigRepository) only ever calls uploadBinary()
-- (insert, or update when upsert:true replaces an existing week's photo)
-- and getPublicUrl() (a plain URL string construction that does NOT go
-- through Storage RLS at all — public-bucket reads are served directly,
-- bypassing storage.objects policies entirely). Grep confirms this app
-- never calls .list()/.download()/.select() on Storage anywhere. So
-- dropping SELECT here closes the enumeration hole with zero functional
-- change: uploads and existing public-URL image loads keep working
-- exactly as before, only bucket-wide file listing is now denied.
drop policy if exists "pig_photos_all (app-enforced access control)" on storage.objects;
-- Legacy policy name found on the live project by the Supabase linter
-- (public_bucket_allows_listing) that predates this schema file's own
-- tracked history — dropped defensively so this script fully cleans up
-- whichever broad-SELECT policy is actually present, not just the one
-- name this file happened to create originally.
drop policy if exists "Allow all uploads (app-enforced)" on storage.objects;
drop policy if exists "pig_photos_insert" on storage.objects;
drop policy if exists "pig_photos_update" on storage.objects;
-- Folder-scoped writes, now that Third-Party Auth makes auth.jwt()->>'sub'
-- a verified Firebase uid: the app always uploads to
-- "<uid>/<pigId>/week_N.jpg" (PigRepository), so requiring the path's
-- first folder segment to equal the caller's own uid means one user's
-- token can no longer overwrite/replace another user's photo, on top of
-- the existing "any signed-in caller can insert new objects" behavior
-- Storage needs for uploads to succeed at all. Reads are unaffected: the
-- app never calls list()/download() (see reasoning above) — only
-- getPublicUrl(), which bypasses these policies entirely via the public
-- bucket's unauthenticated read endpoint.
create policy "pig_photos_insert" on storage.objects
  for insert with check (
    bucket_id = 'pig-photos'
    and (storage.foldername(name))[1] = auth.jwt()->>'sub'
  );
create policy "pig_photos_update" on storage.objects
  for update
  using (bucket_id = 'pig-photos' and (storage.foldername(name))[1] = auth.jwt()->>'sub')
  with check (bucket_id = 'pig-photos' and (storage.foldername(name))[1] = auth.jwt()->>'sub');

-- profile-photos bucket — user avatars (AuthRepository.updateProfileImage()).
-- Same fix and same reasoning as pig-photos above: insert/update only, no
-- SELECT/list policy, since the app only uploads and reads via public URL.
insert into storage.buckets (id, name, public)
values ('profile-photos', 'profile-photos', true)
on conflict (id) do nothing;

drop policy if exists "profile_photos_all (app-enforced access control)" on storage.objects;
drop policy if exists "profile_photos_insert" on storage.objects;
drop policy if exists "profile_photos_update" on storage.objects;
create policy "profile_photos_insert" on storage.objects
  for insert with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.jwt()->>'sub'
  );
create policy "profile_photos_update" on storage.objects
  for update
  using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.jwt()->>'sub')
  with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.jwt()->>'sub');


-- ═══════════════════════════════════════════════════════════════════════
-- 5. APP RELEASES — in-app update checker (sideloaded APK, no Play Store)
-- ═══════════════════════════════════════════════════════════════════════
-- The app has no store to check for updates against, so it checks this
-- table directly on launch instead: whoever publishes a new build inserts
-- one row here (version + a public download URL for the new APK, e.g. a
-- Supabase Storage public link or any other host). The app compares its
-- own running version (native: @capacitor/app's App.getInfo(); web: a
-- hardcoded fallback) against the newest row here and prompts the user to
-- download + install if it's behind — never interrupts anyone already on
-- the latest version. Public, read-only, no user data — same "Option A"
-- style as the rest of this schema, just with no write access from the
-- app at all (publishing a release is a manual developer action, done
-- directly in the Supabase dashboard/SQL editor).
create table if not exists public.app_releases (
  id            uuid primary key default gen_random_uuid(),
  version       text not null,       -- e.g. '1.3.0' — compared numerically, dot-separated
  apk_url       text not null,       -- public, directly downloadable .apk link
  notes         text,                -- optional "what's new" shown in the prompt
  published_at  timestamptz not null default now()
);
create index if not exists idx_app_releases_published_at on public.app_releases(published_at desc);

alter table public.app_releases enable row level security;
drop policy if exists "Allow public read (no user data, read-only)" on public.app_releases;
create policy "Allow public read (no user data, read-only)" on public.app_releases
  for select using (true);
-- Deliberately no insert/update/delete policy — the app can only ever
-- read this table; publishing a release is a manual admin SQL action.
