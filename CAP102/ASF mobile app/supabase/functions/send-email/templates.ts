// ASF — reusable HTML email templates for the Brevo transactional emails.
//
// All templates share one responsive, inline-styled wrapper (email clients
// strip <style> blocks and external CSS unpredictably, so every rule here
// is inline) using a green agricultural palette:
//   primary green  #2E7D32   accent green  #66BB6A
//   light green bg #E8F5E9   page bg       #F5F5F0
//   dark text      #1B2E1E   muted text    #5B6B5D
//
// Max width 600px is the standard safe width for email clients (Gmail,
// Outlook, Apple Mail) on both desktop and mobile.

function escapeHtml(value: string | number | null | undefined): string {
  if (value === null || value === undefined) return "";
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function wrapper(opts: {
  preheader: string;
  heading: string;
  bodyHtml: string;
}): string {
  const { preheader, heading, bodyHtml } = opts;
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>ASF Mobile App</title>
</head>
<body style="margin:0;padding:0;background-color:#F5F5F0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">${escapeHtml(preheader)}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#F5F5F0;padding:24px 12px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:#FFFFFF;border-radius:12px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,0.08);">
          <tr>
            <td style="background-color:#2E7D32;padding:28px 32px;text-align:center;">
              <div style="font-size:22px;line-height:28px;font-weight:700;color:#FFFFFF;letter-spacing:0.5px;">🐖 ASF Mobile App</div>
              <div style="font-size:13px;color:#C8E6C9;margin-top:4px;">African Swine Fever Farm Management</div>
            </td>
          </tr>
          <tr>
            <td style="padding:32px;">
              <h1 style="margin:0 0 16px 0;font-size:20px;line-height:28px;color:#1B2E1E;">${escapeHtml(heading)}</h1>
              ${bodyHtml}
            </td>
          </tr>
          <tr>
            <td style="background-color:#E8F5E9;padding:20px 32px;text-align:center;">
              <div style="font-size:12px;color:#5B6B5D;line-height:18px;">This is an automated message from the ASF Mobile App.<br/>Please do not reply directly to this email.</div>
            </td>
          </tr>
        </table>
        <div style="max-width:600px;margin-top:16px;font-size:11px;color:#9AA69B;text-align:center;">© ${new Date().getFullYear()} ASF Mobile App. All rights reserved.</div>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function pillButton(label: string): string {
  return `<div style="margin:24px 0;"><span style="display:inline-block;background-color:#2E7D32;color:#FFFFFF;font-size:14px;font-weight:600;padding:12px 24px;border-radius:8px;">${escapeHtml(label)}</span></div>`;
}

function infoRow(label: string, value: string | number | null | undefined): string {
  return `<tr>
    <td style="padding:8px 0;font-size:13px;color:#5B6B5D;width:38%;vertical-align:top;">${escapeHtml(label)}</td>
    <td style="padding:8px 0;font-size:14px;color:#1B2E1E;font-weight:600;vertical-align:top;">${escapeHtml(value ?? "—")}</td>
  </tr>`;
}

export function welcomeTemplate(data: { name: string }): { subject: string; html: string } {
  const name = data.name || "Farmer";
  const bodyHtml = `
    <p style="margin:0 0 16px 0;font-size:15px;line-height:24px;color:#1B2E1E;">Hi ${escapeHtml(name)},</p>
    <p style="margin:0 0 16px 0;font-size:15px;line-height:24px;color:#1B2E1E;">Welcome to <strong>ASF Mobile App</strong> — your all-in-one companion for managing pig production safely and efficiently, with built-in African Swine Fever monitoring.</p>
    <p style="margin:0 0 12px 0;font-size:15px;line-height:24px;color:#1B2E1E;">Here's what you can do right away:</p>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 8px 0;">
      <tr><td style="padding:10px 0;border-bottom:1px solid #E8F5E9;"><strong style="color:#2E7D32;">✓ Daily Task Reminders</strong><br/><span style="font-size:13px;color:#5B6B5D;">Stay on top of feeding, weighing, and health checks with daily task lists.</span></td></tr>
      <tr><td style="padding:10px 0;border-bottom:1px solid #E8F5E9;"><strong style="color:#2E7D32;">✓ Feeding Guide</strong><br/><span style="font-size:13px;color:#5B6B5D;">Stage-based feeding recommendations and consumption tracking.</span></td></tr>
      <tr><td style="padding:10px 0;border-bottom:1px solid #E8F5E9;"><strong style="color:#2E7D32;">✓ Growth Tracking</strong><br/><span style="font-size:13px;color:#5B6B5D;">Log weekly weigh-ins and watch ADG/FCR trends over time.</span></td></tr>
      <tr><td style="padding:10px 0;border-bottom:1px solid #E8F5E9;"><strong style="color:#2E7D32;">✓ Health Monitoring</strong><br/><span style="font-size:13px;color:#5B6B5D;">Daily symptom checks with automatic risk scoring and alerts.</span></td></tr>
      <tr><td style="padding:10px 0;"><strong style="color:#2E7D32;">✓ Expert Consultation</strong><br/><span style="font-size:13px;color:#5B6B5D;">Reach out to agricultural experts directly from the app when you need help.</span></td></tr>
    </table>
    ${pillButton("Open ASF Mobile App")}
    <p style="margin:0;font-size:13px;line-height:20px;color:#5B6B5D;">If you didn't create this account, you can safely ignore this email.</p>
  `;
  return {
    subject: "Welcome to ASF Mobile App",
    html: wrapper({ preheader: "Welcome to ASF Mobile App — let's get your farm set up.", heading: `Welcome, ${name}! 🎉`, bodyHtml }),
  };
}

export function passwordResetTemplate(data: { name?: string; email: string }): { subject: string; html: string } {
  const name = data.name || "there";
  const bodyHtml = `
    <p style="margin:0 0 16px 0;font-size:15px;line-height:24px;color:#1B2E1E;">Hi ${escapeHtml(name)},</p>
    <p style="margin:0 0 16px 0;font-size:15px;line-height:24px;color:#1B2E1E;">We're letting you know that a password reset was just requested for the ASF Mobile App account associated with <strong>${escapeHtml(data.email)}</strong>.</p>
    <p style="margin:0 0 16px 0;font-size:15px;line-height:24px;color:#1B2E1E;">Check your inbox for a separate email from Firebase with your password reset link. That link is what actually resets your password — this email is just a heads-up notification.</p>
    <p style="margin:0;font-size:13px;line-height:20px;color:#5B6B5D;">If you didn't request this, your account is still safe — no changes were made, and you can ignore both emails.</p>
  `;
  return {
    subject: "Password Reset Requested — ASF Mobile App",
    html: wrapper({ preheader: "A password reset was requested for your ASF account.", heading: "Password Reset Requested", bodyHtml }),
  };
}

export function consultationRequestTemplate(data: {
  referenceNumber: string;
  farmerName: string;
  farmerEmail: string;
  pigBatch?: string;
  currentWeight?: string | number;
  issueCategory: string;
  problemDescription: string;
  photoUrl?: string;
  submittedAt: string;
}): { subject: string; html: string } {
  const photoHtml = data.photoUrl
    ? `<div style="margin-top:16px;"><a href="${escapeHtml(data.photoUrl)}" style="font-size:13px;color:#2E7D32;">View attached photo →</a></div>`
    : "";
  const bodyHtml = `
    <p style="margin:0 0 16px 0;font-size:15px;line-height:24px;color:#1B2E1E;">A new expert consultation request has been submitted.</p>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 8px 0;">
      ${infoRow("Reference #", data.referenceNumber)}
      ${infoRow("Farmer Name", data.farmerName)}
      ${infoRow("Farmer Email", data.farmerEmail)}
      ${infoRow("Pig Batch", data.pigBatch)}
      ${infoRow("Current Weight", data.currentWeight ? `${data.currentWeight} kg` : undefined)}
      ${infoRow("Issue Category", data.issueCategory)}
      ${infoRow("Submitted", data.submittedAt)}
    </table>
    <div style="margin-top:16px;padding:14px 16px;background-color:#F5F5F0;border-radius:8px;">
      <div style="font-size:12px;color:#5B6B5D;margin-bottom:6px;">Problem Description</div>
      <div style="font-size:14px;color:#1B2E1E;line-height:22px;">${escapeHtml(data.problemDescription)}</div>
    </div>
    ${photoHtml}
  `;
  return {
    subject: `New Consultation Request — ${data.referenceNumber}`,
    html: wrapper({ preheader: `New consultation request from ${data.farmerName}`, heading: "New Consultation Request", bodyHtml }),
  };
}

export function consultationConfirmationTemplate(data: {
  farmerName: string;
  referenceNumber: string;
  date: string;
  summary: string;
  expectedResponseTime: string;
}): { subject: string; html: string } {
  const bodyHtml = `
    <p style="margin:0 0 16px 0;font-size:15px;line-height:24px;color:#1B2E1E;">Hi ${escapeHtml(data.farmerName)},</p>
    <p style="margin:0 0 16px 0;font-size:15px;line-height:24px;color:#1B2E1E;">We've received your consultation request. Our agricultural experts will review it and get back to you soon.</p>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 8px 0;">
      ${infoRow("Reference #", data.referenceNumber)}
      ${infoRow("Date Submitted", data.date)}
      ${infoRow("Expected Response Time", data.expectedResponseTime)}
    </table>
    <div style="margin-top:16px;padding:14px 16px;background-color:#F5F5F0;border-radius:8px;">
      <div style="font-size:12px;color:#5B6B5D;margin-bottom:6px;">Your Summary</div>
      <div style="font-size:14px;color:#1B2E1E;line-height:22px;">${escapeHtml(data.summary)}</div>
    </div>
    <p style="margin:16px 0 0 0;font-size:13px;line-height:20px;color:#5B6B5D;">Keep this reference number handy — you can quote it in any follow-up.</p>
  `;
  return {
    subject: "Consultation Request Received",
    html: wrapper({ preheader: `Your consultation request ${data.referenceNumber} was received.`, heading: "Request Received ✓", bodyHtml }),
  };
}

export function adminNotificationTemplate(data: {
  title: string;
  message: string;
  category?: string;
  meta?: Record<string, unknown>;
}): { subject: string; html: string } {
  const metaRows = data.meta
    ? Object.entries(data.meta).map(([k, v]) => infoRow(k, v as string)).join("")
    : "";
  const isCritical = (data.category || "").toLowerCase().includes("health") || (data.category || "").toLowerCase().includes("critical");
  const bodyHtml = `
    ${isCritical ? `<div style="margin-bottom:16px;padding:10px 14px;background-color:#FDECEA;border-left:4px solid #D32F2F;border-radius:4px;font-size:13px;color:#D32F2F;font-weight:600;">⚠ Critical Alert</div>` : ""}
    <p style="margin:0 0 16px 0;font-size:15px;line-height:24px;color:#1B2E1E;">${escapeHtml(data.message)}</p>
    ${metaRows ? `<table role="presentation" width="100%" cellpadding="0" cellspacing="0">${metaRows}</table>` : ""}
  `;
  return {
    subject: `[ASF Admin] ${data.title}`,
    html: wrapper({ preheader: data.title, heading: data.title, bodyHtml }),
  };
}

export function testTemplate(data: { name?: string }): { subject: string; html: string } {
  const bodyHtml = `
    <p style="margin:0 0 16px 0;font-size:15px;line-height:24px;color:#1B2E1E;">Hi ${escapeHtml(data.name || "there")},</p>
    <p style="margin:0 0 16px 0;font-size:15px;line-height:24px;color:#1B2E1E;">This is a test email from the ASF Mobile App's Brevo integration. If you're reading this, the send-email Edge Function, your Brevo API key, and sender configuration are all working correctly. ✅</p>
    <p style="margin:0;font-size:13px;line-height:20px;color:#5B6B5D;">Sent from the in-app Email Testing screen.</p>
  `;
  return {
    subject: "ASF Mobile App — Test Email",
    html: wrapper({ preheader: "Brevo integration test email.", heading: "Test Email ✅", bodyHtml }),
  };
}
