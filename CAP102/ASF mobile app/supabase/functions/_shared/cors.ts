// Shared CORS headers for all ASF Edge Functions. The Flutter app calls
// these functions via supabase_flutter's `functions.invoke()`, which is a
// plain HTTPS POST carrying the caller's Firebase-issued Supabase session
// token in the Authorization header — Supabase verifies that token against
// the configured Firebase Third-Party Auth project before this function's
// code ever runs (see FIREBASE_THIRDPARTY_AUTH_SETUP.md), so there is no
// extra auth check to do here.
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
