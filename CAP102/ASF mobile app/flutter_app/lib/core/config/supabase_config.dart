// ══════════════════════════════════════════════════════════════════════
// Supabase client (Database + Storage) — ported directly from
// src/supabase-config.js. Same Supabase project as the existing app.
//
// Firebase Authentication remains the app's sole identity provider —
// Supabase is used ONLY for the Postgres database and Storage buckets,
// per the existing app's hybrid-backend design. Supabase's own Auth is
// never used (persistSession/autoRefreshToken are both off, matching the
// web app's client config).
//
// Third-party auth (Firebase → Supabase): the `accessToken` callback
// below hands PostgREST the current Firebase ID token on every request,
// once the Supabase Dashboard's Authentication → Third-Party Auth
// integration is configured with this project's Firebase Project ID
// (see FIREBASE_THIRDPARTY_AUTH_SETUP.md). That lets Postgres RLS
// policies check `auth.jwt()->>'sub'` against a real, cryptographically
// verified Firebase uid instead of trusting the app to always filter by
// firebase_uid itself. Before that dashboard config + the `role:
// authenticated` custom-claim Cloud Function are both live, this
// callback still runs (it's harmless), but Postgres has no way to verify
// the token yet, so the anon-key role applies exactly as before — this
// change alone does not enable anything until the dashboard-side
// integration is switched on.
//
// Security note (same as the web app): only the PUBLIC anon/publishable
// key belongs here. The Secret/Service Role key must never be added to
// this file — it bypasses Row Level Security entirely.
// ══════════════════════════════════════════════════════════════════════

import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kSupabaseUrl = 'https://genxzsocmhgnxwwxjifz.supabase.co';
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdlbnh6c29jbWhnbnh3d3hqaWZ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3Njc3MTIsImV4cCI6MjA5OTM0MzcxMn0.6f5ELfMBBn2Xg8QXu5hw-ZwivEqec9I-11_Wv6Bk_bo';

/// Call once at app startup, after Firebase.initializeApp(). Mirrors
/// src/supabase-config.js's createClient() options exactly, plus the
/// accessToken wiring needed for Firebase-as-third-party-auth.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: false,
    ),
    // Supabase calls this on every request to attach `Authorization:
    // Bearer <token>`. Returning null (signed out) falls back to the
    // plain anon-key request, same as before this change existed.
    accessToken: () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      try {
        return await user.getIdToken();
      } catch (_) {
        // Never let a token-fetch hiccup block an otherwise-working
        // request; it'll just go out anon-scoped, same as pre-migration.
        return null;
      }
    },
  );
}

SupabaseClient get supabase => Supabase.instance.client;
