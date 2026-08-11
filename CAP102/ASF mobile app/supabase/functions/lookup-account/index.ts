// ═══════════════════════════════════════════════════════════════════════
// ASF — lookup-account Edge Function
//
// Fixes a structural bug in Forgot Password / phone-taken / duplicate-
// registration checks. Those checks all run BEFORE the user has an active
// Firebase session (that's the whole point of Forgot Password — the user
// can't sign in), so the Flutter app's Supabase client has no Firebase ID
// token to attach. `profiles`' RLS policy is
// `firebase_uid = auth.jwt()->>'sub'`, which evaluates to
// `firebase_uid = NULL` for an unauthenticated request — and `NULL`
// never equals anything in SQL, so a client-side query against `profiles`
// from a signed-out user ALWAYS returns zero rows, no matter the email's
// casing or whether the account is genuinely registered. That silently
// broke three call sites that all funnel through the same
// getUidByEmail/getUidByPhone/phoneNumberIsTaken pattern in
// auth_repository.dart: Forgot Password ("No account was found" for real
// accounts), the pre-login phone-taken check, and the duplicate-account
// guard during registration.
//
// This function does the same lookup server-side with the service-role
// key (which bypasses RLS entirely), so pre-auth existence checks
// actually work. Deliberately UNAUTHENTICATED (see
// `[functions.lookup-account]` / verify_jwt = false in
// supabase/config.toml) — that's the entire point, it must be callable by
// a signed-out user.
//
// Returns ONLY the Firebase uid (or null) — never any other profile
// field — to keep the exposed surface minimal. A bare Firebase uid grants
// no access to anything on its own: every other read/write in this app
// still requires a genuine Firebase ID token whose `sub` claim matches,
// enforced by Postgres RLS exactly as before.
//
// Uses the automatically-injected SUPABASE_URL and
// SUPABASE_SERVICE_ROLE_KEY (every Edge Function gets these for free) —
// no secrets to configure.
// ═══════════════════════════════════════════════════════════════════════

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let body: { type?: string; value?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const type = body.type;
  const value = (body.value ?? "").trim();
  if ((type !== "email" && type !== "phone") || !value) {
    return new Response(
      JSON.stringify({
        error: "Body must be { type: 'email' | 'phone', value: string }",
      }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const base = admin.from("profiles").select("firebase_uid").limit(1);
    const { data, error } =
      type === "email"
        ? await base.ilike("email", value).maybeSingle()
        : await base.eq("phone_number", value).maybeSingle();

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ uid: data?.firebase_uid ?? null }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
