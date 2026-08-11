// ═══════════════════════════════════════════════════════════════════════
// ASF — stamp-claim Edge Function
//
// Replaces the Firebase Cloud Function approach originally documented in
// FIREBASE_THIRDPARTY_AUTH_SETUP.md (functions/index.js's onCreate trigger
// + backfill-claims.js). That approach requires the Firebase project to be
// on the Blaze (pay-as-you-go) plan — Cloud Functions cannot deploy at all
// on the free Spark plan, regardless of how little they'd actually run.
// This project stays on Spark by design, so this Edge Function does the
// exact same job — stamping the `role: authenticated` custom claim
// Supabase's Third-Party Auth integration needs to see on a Firebase user's
// ID token before Postgres RLS's `auth.jwt()->>'sub'` checks resolve to
// anything other than an unauthenticated request — using only things this
// project already has: a Supabase Edge Function (free) and a Firebase
// service account key (free to generate, no Blaze needed to just call the
// Identity Toolkit REST API with one).
//
// Trigger model: lazy/on-demand rather than an onCreate hook. Called from
// AuthRepository._forceRefreshIdTokenWithRetry() (Flutter) the first time
// that retry loop notices the current ID token doesn't have the claim yet
// — which covers BOTH a brand-new registration (no separate "wire this
// into the signup flow" step needed) AND every pre-existing account that
// registered before this function existed (no separate one-time backfill
// script/run needed either — each old user gets stamped automatically the
// next time they sign in and make their first authenticated write).
// Idempotent and safe to call repeatedly; the caller only needs it to
// succeed once, ever, per user.
//
// Auth model: Supabase verifies the caller's Firebase ID token's signature
// (against the Firebase project registered in Authentication > Third-Party
// Auth) BEFORE this function's code runs — see _shared/cors.ts's doc for
// why that's true project-wide. So decoding (NOT re-verifying — that's
// already been done for us) the bearer token here to read `sub` is safe:
// nothing reaches this line unless Supabase's own gateway already confirmed
// the token is a genuine, unexpired, correctly-audienced Firebase ID token.
// A caller can therefore only ever stamp their OWN uid, never someone
// else's — there is no uid parameter accepted from the request body.
//
// Required secret (set via `supabase secrets set`):
//   FIREBASE_SERVICE_ACCOUNT_JSON — the full JSON contents of a Firebase
//     service account key (Firebase Console > Project Settings > Service
//     Accounts > Generate new private key). Used ONLY to obtain a
//     short-lived Google OAuth2 access token scoped to the Identity
//     Toolkit API — never logged, never returned to the caller.
// ═══════════════════════════════════════════════════════════════════════

import { corsHeaders } from "../_shared/cors.ts";

const SERVICE_ACCOUNT_JSON = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "asf-app-2990c";

interface ServiceAccount {
  client_email: string;
  private_key: string;
}

function base64url(input: ArrayBuffer | string): string {
  const bytes =
    typeof input === "string" ? new TextEncoder().encode(input) : new Uint8Array(input);
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

/// Hand-rolled service-account JWT-bearer OAuth2 flow (RFC 7523), using
/// only Deno's native Web Crypto + fetch — deliberately no npm dependency
/// (e.g. google-auth-library), since this needs to be reliable inside
/// Supabase's constrained edge runtime and every piece here (crypto.subtle,
/// atob/btoa, fetch) is a standard Web API already proven to work in
/// send-email, this project's other Edge Function.
async function getGoogleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/identitytoolkit",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64url(signature)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const body = await res.json();
  if (!res.ok || !body.access_token) {
    throw new Error(`Google token exchange failed: ${JSON.stringify(body)}`);
  }
  return body.access_token as string;
}

function decodeJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = payload + "=".repeat((4 - (payload.length % 4)) % 4);
    return JSON.parse(atob(padded));
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ success: false, error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) {
    return new Response(JSON.stringify({ success: false, error: "Missing bearer token" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const claims = decodeJwtPayload(token);
  const uid = claims?.sub as string | undefined;
  if (!uid) {
    return new Response(JSON.stringify({ success: false, error: "Could not read uid from token" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (claims?.role === "authenticated") {
    // Already stamped (a second concurrent call, or a token that was
    // refreshed since — nothing to do).
    return new Response(JSON.stringify({ success: true, alreadyStamped: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (!SERVICE_ACCOUNT_JSON) {
    return new Response(
      JSON.stringify({ success: false, error: "Not configured (missing FIREBASE_SERVICE_ACCOUNT_JSON secret)" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  try {
    const sa = JSON.parse(SERVICE_ACCOUNT_JSON) as ServiceAccount;
    const accessToken = await getGoogleAccessToken(sa);

    const res = await fetch(
      `https://identitytoolkit.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/accounts:update`,
      {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          localId: uid,
          customAttributes: JSON.stringify({ role: "authenticated" }),
        }),
      },
    );
    const bodyText = await res.text();
    if (!res.ok) {
      return new Response(JSON.stringify({ success: false, error: bodyText }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
