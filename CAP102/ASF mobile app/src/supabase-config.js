/* ══════════════════════════════════════════════════════════════════════
   ASF — Supabase client (Database + Storage)
   ══════════════════════════════════════════════════════════════════════
   Firebase Authentication remains the app's identity provider (see
   src/auth-main.js) — Supabase is used here ONLY for the Postgres
   database and Storage buckets, per integration_prompt.md's "hybrid
   backend" design (Firebase = accounts, Supabase = data + files).

   Security note (per the project's own stated requirements):
     - Only the PUBLIC key below (the "publishable" key, or its older
       "anon" JWT equivalent) belongs in client/mobile code. Both are
       designed to be safely embedded in a shipped app — they only ever
       grant what your RLS policies allow (see supabase_schema (1).sql +
       supabase_schema_addendum.sql).
     - The Secret/Service Role key is NEVER used here, and must never be
       added to this file or anywhere else client-side — it bypasses RLS
       entirely. If a trusted server-side task ever needs it (e.g. an
       admin script), keep it out of the app/repo and out of chat/prompt
       history, and treat it as compromised (rotate it in the Supabase
       dashboard) if it's ever pasted into an AI prompt, chat log, or
       committed to source control.

   Row Level Security currently runs in "Option A" mode (see
   supabase_schema (1).sql): RLS is enabled on every table, but the
   policies are permissive — access control is enforced here, in the app,
   by always filtering/tagging every query with the signed-in Firebase
   uid (see src/sync-engine.js and src/auth-main.js). This is a documented
   scope decision, not an oversight — see OFFLINE_SYNC_REPORT.md /
   SUPABASE_INTEGRATION_REPORT.md for the upgrade path to real
   firebase_uid-matched RLS policies (Option B in that same SQL file).
   ══════════════════════════════════════════════════════════════════════ */

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://genxzsocmhgnxwwxjifz.supabase.co';

// The new-style "publishable" key (sb_publishable_...) is Supabase's
// current recommended client-side key — functionally equivalent to the
// legacy anon JWT key for a client like this one, but doesn't expire and
// carries none of a JWT's embedded project metadata. Falls back to the
// legacy anon key automatically if this project's Supabase client
// library version doesn't yet recognize the new key format.
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_J-KgrLYWrnNFEG4Dkn-zTQ_INo3VJvG';
const SUPABASE_ANON_KEY_LEGACY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdlbnh6c29jbWhnbnh3d3hqaWZ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3Njc3MTIsImV4cCI6MjA5OTM0MzcxMn0.6f5ELfMBBn2Xg8QXu5hw-ZwivEqec9I-11_Wv6Bk_bo';

export const supabase = createClient(
  SUPABASE_URL,
  SUPABASE_PUBLISHABLE_KEY || SUPABASE_ANON_KEY_LEGACY,
  {
    auth: {
      // No Supabase Auth session of its own — Firebase Auth is the only
      // identity provider in this app (see src/auth-main.js).
      persistSession: false,
      autoRefreshToken: false,
    },
  }
);

export function isSupabaseConfigured() {
  return !!SUPABASE_URL && !!(SUPABASE_PUBLISHABLE_KEY || SUPABASE_ANON_KEY_LEGACY);
}
