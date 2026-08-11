# Brevo Transactional Email Setup — ASF Mobile App

This document is the handoff for the Brevo integration: how the pieces fit
together, and the exact steps to finish activating it (get an API key,
configure secrets, deploy the Edge Function, test).

## 1. Architecture

```
Flutter app (EmailRepository)
        │  supabase.functions.invoke('send-email', body: {...})
        │  (carries the signed-in user's Firebase JWT automatically)
        ▼
Supabase Edge Function  supabase/functions/send-email/index.ts
        │  reads secrets: BREVO_API_KEY, SENDER_EMAIL, SENDER_NAME, ADMIN_EMAIL
        │  builds the HTML email from supabase/functions/send-email/templates.ts
        │  logs the attempt to public.email_logs (service-role key)
        ▼
Brevo REST API  https://api.brevo.com/v3/smtp/email
```

The Brevo API key is **only ever read inside the Edge Function**, from a
Supabase secret. It is never bundled into the Flutter app, never sent to
the device, and never appears in any client-side log.

Why Supabase Edge Functions instead of Firebase Cloud Functions (the
other option the spec allowed): this project's existing Firebase Cloud
Functions project (`functions/`) currently can't deploy anything because
the Firebase project is still on the free Spark plan — Cloud Functions
requires the paid Blaze plan. Supabase Edge Functions have no equivalent
billing gate on the free tier, so this integration is deployable today
without waiting on a separate Firebase billing upgrade.

## 2. Files

| File | Purpose |
|---|---|
| `supabase/functions/send-email/index.ts` | The Edge Function itself — routes by `type`, calls Brevo, logs the attempt. |
| `supabase/functions/send-email/templates.ts` | The six HTML email templates (green, mobile-friendly, ASF-branded). |
| `supabase/functions/_shared/cors.ts` | Shared CORS headers. |
| `supabase/config.toml` | Minimal Supabase CLI project config (project ref only). |
| `supabase_schema_brevo.sql` | Additive SQL: `public.consultations`, `public.email_logs`, `consultation-photos` storage bucket + RLS. Run once in the Supabase SQL editor, after the main `supabase_schema.sql`. |
| `flutter_app/lib/features/email/` | `EmailRepository`, `EmailType`/`EmailSendResult` models, Riverpod provider, the Email Testing screen. |
| `flutter_app/lib/features/consultation/` | Expert Consultation domain model, repository (local SQLite + Supabase mirror), Riverpod controller, and the consultation form screen. |
| `flutter_app/lib/core/database/sqlite_service.dart` | `consultations` (synced) and `emailQueue` (local-only retry queue) tables — schema v6. |
| `flutter_app/lib/core/services/sync_engine.dart` | Wires `EmailRepository.resyncPending()` and `ConsultationRepository.pushUnsynced()` into the existing offline sync engine. |

## 3. One-time setup

### 3.1 Generate a Brevo API key

1. Sign in at [app.brevo.com](https://app.brevo.com).
2. Go to **Settings → SMTP & API → API Keys** (`https://app.brevo.com/settings/keys/api`).
3. Click **Generate a new API key**, name it e.g. `ASF Mobile App — production`, and copy it. You will not be able to see it again after leaving the page.
4. Under **Senders & IP** in the Brevo dashboard, verify (or add) the email address you intend to send from — Brevo requires the sender address to be a verified sender/domain before it will deliver mail sent through the API.

### 3.2 Install the Supabase CLI (if not already installed)

```bash
npm install -g firebase-tools   # (already installed for Cloud Functions)
npm install -g supabase          # Supabase CLI, separate tool
supabase --version
```

### 3.3 Log in and link the project

```bash
supabase login
cd "ASF mobile app"
supabase link --project-ref genxzsocmhgnxwwxjifz
```

### 3.4 Set the secrets

```bash
supabase secrets set BREVO_API_KEY="xkeysib-xxxxxxxxxxxxxxxxxxxxxxxx"
supabase secrets set SENDER_EMAIL="noreply@yourdomain.com"
supabase secrets set SENDER_NAME="ASF Mobile App"
supabase secrets set ADMIN_EMAIL="ati-admin@yourdomain.com"
```

`SENDER_EMAIL` must be a sender Brevo has verified (step 3.1.4). `ADMIN_EMAIL`
is where every consultation request and admin notification is delivered.

### 3.5 Deploy the Edge Function

```bash
supabase functions deploy send-email --project-ref genxzsocmhgnxwwxjifz
```

### 3.6 Apply the additive schema

Open the Supabase SQL editor for the project and run the contents of
`supabase_schema_brevo.sql` once. It's idempotent — safe to re-run.

## 4. Testing

1. Build and install the app (see the main project's build scripts).
2. Sign in, open **Settings → Email Testing**.
3. Enter an inbox you can actually check, then try each button in turn:
   - **Send Test Email** — confirms the whole pipeline (app → Edge Function → Brevo) works.
   - **Send Welcome Email** — same template new users get after registering.
   - **Send Consultation Email** — the farmer-facing confirmation template.
   - **Send Admin Notification** — the generic admin-alert template.
4. Each button shows the raw result (success / HTTP status / error message) right below — a failed deploy or a wrong secret shows up immediately instead of failing silently.
5. To test the real flows end to end: register a new account (welcome email), submit a request from **Settings → Expert Consultation** (both the admin and confirmation emails), and use **Forgot Password** (the informational email that follows Firebase's own reset email).

## 5. Offline & retry behavior

- Every send tries up to 3 times immediately (2s/4s backoff) — covers a brief network hiccup.
- If all 3 fail (including being fully offline), the email is saved to a local `emailQueue` table instead of being lost.
- The existing offline sync engine (`SyncEngine.syncNow`, already runs on reconnect / every ~25 min / on Dashboard open) retries queued emails with a longer backoff (30s → 60s → 120s) until they succeed or exhaust 3 queued attempts, at which point they're marked `failed` and left for manual follow-up.
- A failed or queued email **never** blocks the action that triggered it — registration, a consultation submission, and a critical health log all save successfully regardless of email delivery status.

## 6. Known gaps / deliberate scope decisions

- **"New feedback" admin notification** (one of three triggers listed in the original spec): this app has no feedback feature/table today (confirmed via search — no feedback screen, repository, or Supabase table exists). `EmailRepository.sendAdminNotification()` is generic and ready to be wired in once a feedback feature is built, but nothing was invented for this handoff.
- **Consultation-request vs. admin-notification for a new consultation**: rather than sending two separate emails to the admin for every consultation (the detailed `consultation_request` template AND a generic `admin_notification`), a new consultation only sends the one, richer `consultation_request` email — it already contains every field the spec asked for. `sendAdminNotification()` is still used for the other admin-alert trigger (critical health status).
- **Email Testing / Expert Consultation screens are English-only** — they weren't run through the app's EN/FIL translation system (`tr()`) in this pass, unlike the rest of the app's screens. Settings tile labels/subtitles *are* translated (`emailTesting`/`expertConsultation` keys added to both languages); the screen bodies themselves are not yet.
