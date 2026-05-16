import prisma from "../../prisma/client.js";
import prismaPkg from "@prisma/client";
// Prisma 7 exports enum runtime values at the top level, not on the `Prisma` namespace.
const { Role, OtpType } = prismaPkg;
import { hashPassword, comparePassword } from "../../utils/password.js";
import { generateAccessToken, generateRefreshToken } from "../../utils/jwt.js";
import { generateOTP, hashOTP, compareOTP } from "../../utils/otp.js";
import { sendVerificationEmail, sendResetEmail } from "../../utils/email.js";

// Register user — role is always VET; never accept role from the client.
export const registerUser = async ({ userName, email, password }) => {
  const normalizedEmail = email.toLowerCase();
  const normalizedUserName = userName.toLowerCase();

  const existing = await prisma.user.findFirst({
    where: {
      OR: [{ email: normalizedEmail }, { userName: normalizedUserName }],
    },
    select: { email: true, userName: true },
  });

  if (existing) {
    if (existing.email === normalizedEmail) throw new Error("Email already registered");
    throw new Error("Username already taken");
  }

  const hashedPassword = await hashPassword(password);
  const otp = generateOTP();
  const hashedOtp = await hashOTP(otp);
  const otpExpires = new Date();
      otpExpires.setMinutes(otpExpires.getMinutes() + 5);
  const user = await prisma.user.create({
  data: {
    userName: normalizedUserName,
    email: normalizedEmail,
    password: hashedPassword,
    role: Role.VET,
    otp: hashedOtp,
    otpType: OtpType.VERIFY_EMAIL,
    otpExpires: otpExpires,
    otpAttempts: 0,
  },
});
  await sendVerificationEmail(normalizedEmail, otp);

  return user;
};

// Admin-only staff user creation. Caller must be a CEO (enforced in routes).
// Role is taken from the validated body and the account is pre-verified
// since a CEO is vouching for the new staff member.
export const createStaffUser = async ({ userName, email, password, role }) => {
  const normalizedEmail = email.toLowerCase();
  const normalizedUserName = userName.toLowerCase();

  const existing = await prisma.user.findFirst({
    where: {
      OR: [{ email: normalizedEmail }, { userName: normalizedUserName }],
    },
    select: { email: true, userName: true },
  });

  if (existing) {
    if (existing.email === normalizedEmail) throw new Error("Email already registered");
    throw new Error("Username already taken");
  }

  const hashedPassword = await hashPassword(password);

  return prisma.user.create({
    data: {
      userName: normalizedUserName,
      email: normalizedEmail,
      password: hashedPassword,
      role,
      emailVerified: true,
    },
    select: {
      id: true,
      userName: true,
      email: true,
      role: true,
      createdAt: true,
    },
  });
};

// Verify email OTP — delegates to validateOtp so the 5-attempt cap and
// expiry/type checks are applied consistently with the reset flow.
export const verifyEmailOtp = async ({ email, enteredOtp }) => {
  const user = await validateOtp({
    email,
    enteredOtp,
    type: "VERIFY_EMAIL",
  });

  await prisma.user.update({
    where: { id: user.id },
    data: {
      emailVerified: true,
      otp: null,
      otpType: null,
      otpExpires: null,
      otpAttempts: 0,
    },
  });

  return true;
};

// Login user — `identifier` is either an email or a username.
// All failure paths return the same generic error to prevent enumeration.
export const loginUser = async ({ identifier, password }) => {
  const normalized = identifier.toLowerCase();

  const user = await prisma.user.findFirst({
    where: {
      OR: [{ email: normalized }, { userName: normalized }],
    },
  });

  const GENERIC = new Error("Invalid credentials");

  if (!user) throw GENERIC;
  if (!user.emailVerified) throw GENERIC;

  // OAuth-only accounts have no password hash to compare against.
  // Return a specific message so the UI can route the user to the
  // correct sign-in button instead of failing opaquely on bcrypt.
  if (!user.password) {
    const err = new Error("This account uses Google or Apple sign-in");
    err.code = "OAUTH_ONLY_ACCOUNT";
    throw err;
  }

  const isMatch = await comparePassword(password, user.password);
  if (!isMatch) throw GENERIC;

  const accessToken = generateAccessToken(user);
  const refreshToken = generateRefreshToken();

  await prisma.refreshToken.create({
    data: {
      token: refreshToken,
      userId: user.id,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    },
  });

  return {
    accessToken,
    refreshToken,
    user: {
      id: user.id,
      userName: user.userName,
      email: user.email,
      role: user.role,
    },
  };
};

// Logout user
export const logoutUser = async (refreshToken) => {
  if (!refreshToken) return true;

  await prisma.refreshToken.deleteMany({
    where: { token: refreshToken },
  });

  return true;
};

// Request password reset
export const forgotPasswordService = async (email) => {
  const normalizedEmail = email.toLowerCase();
  const user = await prisma.user.findUnique({ where: { email: normalizedEmail } });

  if (!user) return true;

  const otp = generateOTP();
  const hashedOtp = await hashOTP(otp);

  await prisma.user.update({
    where: { id: user.id },
    data: {
      otp: hashedOtp,
      otpType: "RESET_PASSWORD",
      otpExpires: new Date(Date.now() + 5 * 60 * 1000),
      otpAttempts: 0,
    },
  });

  await sendResetEmail(normalizedEmail, otp);
  return true;
};

export const resendOtp = async (email) => {
  const normalizedEmail = email.toLowerCase();
  const user = await prisma.user.findUnique({ where: { email: normalizedEmail } });

  if (!user) return true;
  if (user.otpAttempts >= 5) throw new Error("Too many attempts. Try later.");

  const otp = generateOTP();
  const hashedOtp = await hashOTP(otp);

  await prisma.user.update({
    where: { id: user.id },
    data: {
      otp: hashedOtp,
      otpType: user.otpType || "RESET_PASSWORD",
      otpExpires: new Date(Date.now() + 5 * 60 * 1000),
      otpAttempts: { increment: 1 },
    },
  });

  if (user.otpType === "RESET_PASSWORD") {
    await sendResetEmail(normalizedEmail, otp);
  } else {
    await sendVerificationEmail(normalizedEmail, otp);
  }

  return true;
};

export const validateOtp = async ({ email, enteredOtp, type }) => {
  const normalizedEmail = email.toLowerCase();
  const user = await prisma.user.findUnique({ where: { email: normalizedEmail } });

  if (!user || !user.otp) throw new Error("Invalid OTP");
  if (user.otpType !== type) throw new Error("Invalid OTP type");
  if (user.otpAttempts >= 5) throw new Error("Too many attempts");
  if (new Date() > user.otpExpires) throw new Error("OTP expired");

  const isMatch = await compareOTP(enteredOtp, user.otp);
  if (!isMatch) {
    await prisma.user.update({
      where: { id: user.id },
      data: { otpAttempts: { increment: 1 } },
    });
    throw new Error("Invalid OTP");
  }

  return user;
};

// Reset password
export const resetPasswordService = async ({ email, enteredOtp, newPassword }) => {
  const normalizedEmail = email.toLowerCase();
  const user = await validateOtp({
    email: normalizedEmail,
    enteredOtp,
    type: "RESET_PASSWORD",
  });

  const hashedPassword = await hashPassword(newPassword);

  await prisma.user.update({
    where: { id: user.id },
    data: {
      password: hashedPassword,
      otp: null,
      otpType: null,
      otpExpires: null,
      otpAttempts: 0,
    },
  });

  return true;
};
