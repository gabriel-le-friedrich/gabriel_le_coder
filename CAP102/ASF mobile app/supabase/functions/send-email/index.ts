// ═══════════════════════════════════════════════════════════════════════
// ASF — send-email Edge Function
//
// The ONLY place the Brevo API key is ever used. The Flutter app never
// sees it — it calls this function via supabase_flutter's
// `supabase.functions.invoke('send-email', body: {...})`, which
// automatically attaches the signed-in user's Supabase session token
// (the Firebase ID token, per this project's Third-Party Auth setup — see
// FIREBASE_THIRDPARTY_AUTH_SETUP.md) as a Bearer token. Supabase verifies
// that token BEFORE this code runs (default `verify_jwt = true`), so an
// unauthenticated caller never reaches this function at all.
//
// Required secrets (set via `supabase secrets set`, see BREVO_SETUP.md):
//   BREVO_API_KEY   — from https://app.brevo.com/settings/keys/api
//   SENDER_EMAIL    — the "from" address, must be a verified Brevo sender
//   SENDER_NAME     — the "from" display name, e.g. "ASF Mobile App"
//   ADMIN_EMAIL     — where consultation-request / admin-notification
//                      emails are sent
//
// Also uses the automatically-injected SUPABASE_URL and
// SUPABASE_SERVICE_ROLE_KEY (every Edge Function gets these for free) to
// write an audit row to public.email_logs after every attempt — this is
// the ONLY writer of that table; RLS on email_logs has no insert policy
// for the anon/authenticated role, so this write must use the service
// role key to bypass RLS.
// ═══════════════════════════════════════════════════════════════════════

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import {
  welcomeTemplate,
  passwordResetTemplate,
  consultationRequestTemplate,
  consultationConfirmationTemplate,
  adminNotificationTemplate,
  testTemplate,
} from "./templates.ts";

type EmailType =
  | "welcome"
  | "password_reset"
  | "consultation_request"
  | "consultation_confirmation"
  | "admin_notification"
  | "test";

interface SendEmailRequest {
  type: EmailType;
  to?: string;
  toName?: string;
  firebaseUid?: string;
  data?: Record<string, unknown>;
}

const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY") ?? "";
const SENDER_EMAIL = Deno.env.get("SENDER_EMAIL") ?? "";
const SENDER_NAME = Deno.env.get("SENDER_NAME") ?? "ASF Mobile App";
const ADMIN_EMAIL = Deno.env.get("ADMIN_EMAIL") ?? "";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

function buildEmail(req: SendEmailRequest): { subject: string; html: string; to: string; toName: string } {
  const data = req.data ?? {};
  switch (req.type) {
    case "welcome": {
      const t = welcomeTemplate({ name: String(data.name ?? req.toName ?? "Farmer") });
      return { ...t, to: req.to!, toName: req.toName ?? String(data.name ?? "") };
    }
    case "password_reset": {
      const t = passwordResetTemplate({ name: data.name ? String(data.name) : undefined, email: String(data.email ?? req.to) });
      return { ...t, to: req.to!, toName: req.toName ?? "" };
    }
    case "consultation_request": {
      const t = consultationRequestTemplate({
        referenceNumber: String(data.referenceNumber ?? ""),
        farmerName: String(data.farmerName ?? ""),
        farmerEmail: String(data.farmerEmail ?? ""),
        pigBatch: data.pigBatch ? String(data.pigBatch) : undefined,
        currentWeight: data.currentWeight as string | number | undefined,
        issueCategory: String(data.issueCategory ?? ""),
        problemDescription: String(data.problemDescription ?? ""),
        photoUrl: data.photoUrl ? String(data.photoUrl) : undefined,
        submittedAt: String(data.submittedAt ?? new Date().toISOString()),
      });
      // Always goes to the admin inbox regardless of what "to" was passed.
      return { ...t, to: ADMIN_EMAIL, toName: "ASF Admin" };
    }
    case "consultation_confirmation": {
      const t = consultationConfirmationTemplate({
        farmerName: String(data.farmerName ?? req.toName ?? ""),
        referenceNumber: String(data.referenceNumber ?? ""),
        date: String(data.date ?? new Date().toISOString()),
        summary: String(data.summary ?? ""),
        expectedResponseTime: String(data.expectedResponseTime ?? "1-2 business days"),
      });
      return { ...t, to: req.to!, toName: req.toName ?? String(data.farmerName ?? "") };
    }
    case "admin_notification": {
      const t = adminNotificationTemplate({
        title: String(data.title ?? "Notification"),
        message: String(data.message ?? ""),
        category: data.category ? String(data.category) : undefined,
        meta: (data.meta as Record<string, unknown>) ?? undefined,
      });
      return { ...t, to: req.to || ADMIN_EMAIL, toName: "ASF Admin" };
    }
    case "test": {
      const t = testTemplate({ name: data.name ? String(data.name) : undefined });
      return { ...t, to: req.to!, toName: req.toName ?? "" };
    }
    default:
      throw new Error(`Unknown email type: ${(req as { type?: string }).type}`);
  }
}

async function sendViaBrevo(opts: { to: string; toName: string; subject: string; html: string }) {
  const res = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "api-key": BREVO_API_KEY,
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    body: JSON.stringify({
      sender: { name: SENDER_NAME, email: SENDER_EMAIL },
      to: [{ email: opts.to, name: opts.toName || undefined }],
      subject: opts.subject,
      htmlContent: opts.html,
    }),
  });
  const bodyText = await res.text();
  let bodyJson: Record<string, unknown> = {};
  try {
    bodyJson = bodyText ? JSON.parse(bodyText) : {};
  } catch {
    // Brevo always returns JSON, but guard anyway.
  }
  return { ok: res.ok, status: res.status, body: bodyJson };
}

async function logAttempt(entry: {
  firebaseUid?: string;
  emailType: string;
  recipient: string;
  status: "sent" | "failed";
  responseCode?: number;
  errorMessage?: string;
}) {
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) return; // best-effort only
  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    await admin.from("email_logs").insert({
      firebase_uid: entry.firebaseUid ?? null,
      email_type: entry.emailType,
      recipient: entry.recipient,
      status: entry.status,
      response_code: entry.responseCode ?? null,
      error_message: entry.errorMessage ?? null,
      retry_count: 0,
    });
  } catch (_) {
    // Logging must never break the actual email response to the client.
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

  let payload: SendEmailRequest;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ success: false, error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (!payload?.type) {
    return new Response(JSON.stringify({ success: false, error: "Missing 'type'" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (!BREVO_API_KEY || !SENDER_EMAIL) {
    return new Response(
      JSON.stringify({ success: false, error: "Email service not configured (missing BREVO_API_KEY or SENDER_EMAIL secret)" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  let built: { subject: string; html: string; to: string; toName: string };
  try {
    built = buildEmail(payload);
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: (err as Error).message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (!built.to) {
    return new Response(JSON.stringify({ success: false, error: "No recipient resolved for this email type" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const result = await sendViaBrevo(built);

    await logAttempt({
      firebaseUid: payload.firebaseUid,
      emailType: payload.type,
      recipient: built.to,
      status: result.ok ? "sent" : "failed",
      responseCode: result.status,
      errorMessage: result.ok ? undefined : JSON.stringify(result.body),
    });

    if (!result.ok) {
      return new Response(
        JSON.stringify({ success: false, error: result.body?.message ?? "Brevo API error", responseCode: result.status }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ success: true, messageId: (result.body as { messageId?: string })?.messageId ?? null }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    await logAttempt({
      firebaseUid: payload.firebaseUid,
      emailType: payload.type,
      recipient: built.to,
      status: "failed",
      errorMessage: (err as Error).message,
    });
    return new Response(JSON.stringify({ success: false, error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
