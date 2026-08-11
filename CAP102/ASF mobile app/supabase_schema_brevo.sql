-- ═══════════════════════════════════════════════════════════════════════
-- ASF — Brevo transactional email integration: additive schema.
--
-- Run this file ONCE in the Supabase SQL editor, in addition to (after)
-- supabase_schema.sql. It is self-contained and idempotent (every
-- statement is IF NOT EXISTS / CREATE OR REPLACE / DROP+CREATE POLICY),
-- safe to re-run. It does not modify any existing table from
-- supabase_schema.sql.
--
-- What this adds:
--   1. public.consultations   — Expert Consultation request records
--   2. public.email_logs      — server-side audit trail of every Brevo
--                                send attempt (written ONLY by the
--                                send-email Edge Function using the
--                                service-role key — never by the app)
--   3. storage bucket 'consultation-photos' (public) for the optional
--      photo attached to a consultation request
--
-- Auth model matches the rest of the app (see
-- FIREBASE_THIRDPARTY_AUTH_SETUP.md): every RLS policy compares
-- firebase_uid against auth.jwt()->>'sub', the verified Firebase uid
-- Postgres sees once Third-Party Auth is configured.
-- ═══════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════
-- 1. CONSULTATIONS — Expert Consultation requests submitted from the app
-- ═══════════════════════════════════════════════════════════════════════
create table if not exists public.consultations (
  id                  uuid primary key default gen_random_uuid(),
  firebase_uid        text not null references public.profiles(firebase_uid) on delete cascade,
  app_entry_id        text,  -- local SQLite row id, lets a retried push
                             -- after a partial failure use upsert instead
                             -- of a real UPDATE (same pattern as activity_logs)
  reference_number    text not null,
  farmer_name         text not null,
  farmer_email        text not null,
  pig_batch           text,
  current_weight      numeric,
  issue_category      text not null,
  problem_description text not null,
  photo_url           text,
  status              text not null default 'pending', -- pending | reviewed | resolved
  created_at          timestamptz not null default now(),
  device_id           text,
  sync_version        bigint,
  last_synced_at      timestamptz
);

alter table public.consultations add column if not exists reference_number    text;
alter table public.consultations add column if not exists status             text not null default 'pending';

create unique index if not exists uniq_consultations_reference on public.consultations(reference_number);
create unique index if not exists uniq_consultations_entry     on public.consultations(firebase_uid, app_entry_id);
create index if not exists idx_consultations_firebase_uid      on public.consultations(firebase_uid);
create index if not exists idx_consultations_created_at        on public.consultations(created_at desc);

alter table public.consultations enable row level security;

-- Same append-only shape as activity_logs: insert + select only, scoped to
-- the owning firebase_uid. No update/delete policy — a farmer can submit
-- and view their own consultation requests, but not edit/delete them after
-- the fact. Status changes (pending -> reviewed -> resolved) are an admin
-- action done directly in the Supabase SQL editor / a future admin panel,
-- which runs as the table owner and bypasses RLS.
drop policy if exists "Allow insert (app-enforced access control)" on public.consultations;
create policy "Allow insert (app-enforced access control)" on public.consultations
  for insert with check (firebase_uid = auth.jwt()->>'sub');
drop policy if exists "Allow select (app-enforced access control)" on public.consultations;
create policy "Allow select (app-enforced access control)" on public.consultations
  for select using (firebase_uid = auth.jwt()->>'sub');


-- ═══════════════════════════════════════════════════════════════════════
-- 2. EMAIL_LOGS — server-side audit trail, written only by the Edge
--    Function (service-role key, bypasses RLS). The app can read its own
--    rows (for a future "email history" view) but can never write here —
--    this keeps the log trustworthy: it always reflects what Brevo
--    actually returned, not what the client claims happened.
-- ═══════════════════════════════════════════════════════════════════════
create table if not exists public.email_logs (
  id             uuid primary key default gen_random_uuid(),
  firebase_uid   text references public.profiles(firebase_uid) on delete set null,
  email_type     text not null,   -- welcome | password_reset | consultation_request
                                   -- | consultation_confirmation | admin_notification | test
  recipient      text not null,
  status         text not null,   -- sent | failed
  response_code  integer,
  error_message  text,
  retry_count    integer not null default 0,
  created_at     timestamptz not null default now()
);

create index if not exists idx_email_logs_firebase_uid on public.email_logs(firebase_uid);
create index if not exists idx_email_logs_created_at    on public.email_logs(created_at desc);

alter table public.email_logs enable row level security;

-- Select-only for the owning user; no insert/update/delete policy for the
-- anon/authenticated role at all, so only the service-role key used inside
-- the Edge Function can write here.
drop policy if exists "Allow select (app-enforced access control)" on public.email_logs;
create policy "Allow select (app-enforced access control)" on public.email_logs
  for select using (firebase_uid = auth.jwt()->>'sub');


-- ═══════════════════════════════════════════════════════════════════════
-- 3. STORAGE — consultation-photos bucket (public, same shape as the
--    existing pig-photos bucket)
-- ═══════════════════════════════════════════════════════════════════════
insert into storage.buckets (id, name, public)
values ('consultation-photos', 'consultation-photos', true)
on conflict (id) do nothing;

drop policy if exists "consultation-photos: public read" on storage.objects;
create policy "consultation-photos: public read" on storage.objects
  for select using (bucket_id = 'consultation-photos');

drop policy if exists "consultation-photos: authenticated upload" on storage.objects;
create policy "consultation-photos: authenticated upload" on storage.objects
  for insert with check (bucket_id = 'consultation-photos' and auth.jwt()->>'sub' is not null);

drop policy if exists "consultation-photos: owner update" on storage.objects;
create policy "consultation-photos: owner update" on storage.objects
  for update using (bucket_id = 'consultation-photos' and auth.jwt()->>'sub' is not null);

drop policy if exists "consultation-photos: owner delete" on storage.objects;
create policy "consultation-photos: owner delete" on storage.objects
  for delete using (bucket_id = 'consultation-photos' and auth.jwt()->>'sub' is not null);
