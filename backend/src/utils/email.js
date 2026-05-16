import { Resend } from "resend";

const apiKey = process.env.RESEND_API_KEY;
const resend = apiKey ? new Resend(apiKey) : null;

// Resend's shared sender — works without a verified domain, but only delivers
// to the email you signed up with. For other recipients, verify a domain at
// resend.com/domains and set EMAIL_FROM to "Mwirigi Farm <noreply@yourdomain>".
const FROM = process.env.EMAIL_FROM || "Mwirigi Farm <onboarding@resend.dev>";

const send = async ({ to, subject, html }) => {
  if (!resend) {
    console.warn(`[email] RESEND_API_KEY missing — skipping send to ${to}`);
    return;
  }
  const { error } = await resend.emails.send({ from: FROM, to, subject, html });
  if (error) throw new Error(`Email send failed: ${error.message || error.name}`);
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
