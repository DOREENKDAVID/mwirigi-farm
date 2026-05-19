import { Resend } from "resend";

const apiKey = process.env.RESEND_API_KEY;
const resend = apiKey ? new Resend(apiKey) : null;

// Resend's shared sender — works without a verified domain, but ONLY
// delivers to the email address the Resend API key belongs to. Sends
// to any other recipient succeed at the API level and are then
// silently dropped, which is what caused OTP delivery to look broken.
// For production, verify a domain at resend.com/domains and set
// EMAIL_FROM, e.g. "Mwirigi Farm <noreply@yourdomain.com>".
const SANDBOX_FROM = "Mwirigi Farm <onboarding@resend.dev>";
const FROM = process.env.EMAIL_FROM || SANDBOX_FROM;
const usingSandbox = !process.env.EMAIL_FROM;

// Boot-time warning. Logged once at module load so the misconfiguration
// is visible the moment the server starts, not buried inside a request
// where it's easy to miss.
if (!resend) {
  console.error(
    "[email] RESEND_API_KEY is not set — OTP emails will throw at send time.",
  );
} else if (usingSandbox) {
  console.warn(
    "[email] EMAIL_FROM is not set — falling back to Resend's sandbox " +
      "sender (onboarding@resend.dev). Sends will only deliver to the " +
      "email registered with your Resend account; all other recipients " +
      "will appear to succeed but never receive the message. Verify a " +
      "domain at https://resend.com/domains and set EMAIL_FROM to fix.",
  );
}

const send = async ({ to, subject, html }) => {
  // Hard failure (not silent warn) — an OTP that's logged-as-warned but
  // never sent makes registration look like it worked and locks the user
  // out. We'd rather the request 500 and surface the bug.
  if (!resend) {
    throw new Error(
      "Email send refused: RESEND_API_KEY is not set on the server.",
    );
  }
  const { data, error } = await resend.emails.send({
    from: FROM,
    to,
    subject,
    html,
  });
  if (error) {
    // Resend returns a structured error object — include name + message
    // so logs are diagnosable, not just "Email send failed".
    throw new Error(
      `Email send failed: ${error.name ?? "unknown"} — ${error.message ?? error}`,
    );
  }
  // Confirmation log. `data.id` is Resend's message id; with it you
  // can look the message up in the Resend dashboard and see whether
  // it bounced, was queued, or actually delivered.
  console.log(
    `[email] sent ${subject} → ${to} (id=${data?.id ?? "unknown"}, from=${FROM})`,
  );
  if (usingSandbox) {
    console.warn(
      `[email] ⚠ sandbox sender — '${to}' will only receive this email ` +
        "if it matches the Resend account owner's email.",
    );
  }
};

const otpTemplate = (heading, otp, intent) => `
  <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px; color: #1a1a1a;">
    <h2 style="color: #2e7d32; margin: 0 0 16px;">${heading}</h2>
    <p>Your one-time code to ${intent}:</p>
    <div style="font-size: 32px; letter-spacing: 6px; font-weight: bold; background: #f3f8f3; padding: 16px 24px; text-align: center; border-radius: 8px; margin: 20px 0;">${otp}</div>
    <p style="color: #555; font-size: 14px;">This code expires in 5 minutes. If you didn't request it, ignore this email.</p>
    <p style="color: #888; font-size: 12px; margin-top: 32px;">— Mwirigi Farm</p>
  </div>
`;

export const sendVerificationEmail = (to, otp) =>
  send({
    to,
    subject: "Verify your Mwirigi Farm account",
    html: otpTemplate("Verify your email", otp, "verify your email address"),
  });

export const sendResetEmail = (to, otp) =>
  send({
    to,
    subject: "Mwirigi Farm password reset",
    html: otpTemplate("Reset your password", otp, "reset your password"),
  });
