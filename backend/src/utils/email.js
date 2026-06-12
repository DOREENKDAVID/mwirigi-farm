import nodemailer from "nodemailer";

const user = process.env.EMAIL_USER;
const pass = process.env.EMAIL_PASS;

if (!user || !pass) {
  console.error(
    "[email] EMAIL_USER or EMAIL_PASS is not set — OTP emails will fail.",
  );
}

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: { user, pass },
});

const otpTemplate = (heading, otp, intent) => `
  <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px; color: #1a1a1a;">
    <h2 style="color: #2e7d32; margin: 0 0 16px;">${heading}</h2>
    <p>Your one-time code to ${intent}:</p>
    <div style="font-size: 32px; letter-spacing: 6px; font-weight: bold; background: #f3f8f3; padding: 16px 24px; text-align: center; border-radius: 8px; margin: 20px 0;">${otp}</div>
    <p style="color: #555; font-size: 14px;">This code expires in 5 minutes. If you didn't request it, ignore this email.</p>
    <p style="color: #888; font-size: 12px; margin-top: 32px;">— Mwirigi Farm</p>
  </div>
`;

const send = async ({ to, subject, html }) => {
  if (!user || !pass) {
    throw new Error("Email send refused: EMAIL_USER or EMAIL_PASS is not set.");
  }
  const info = await transporter.sendMail({
    from: `"Mwirigi Farm" <${user}>`,
    to,
    subject,
    html,
  });
  console.log(`[email] sent "${subject}" → ${to} (id=${info.messageId})`);
};

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
