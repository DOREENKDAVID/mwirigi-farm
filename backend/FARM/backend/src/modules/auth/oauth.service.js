import prisma from "../../prisma/client.js";
import prismaPkg from "@prisma/client";
import { OAuth2Client } from "google-auth-library";
import appleSignin from "apple-signin-auth";

import { generateAccessToken, generateRefreshToken } from "../../utils/jwt.js";

// Prisma 7 exports enum runtime values at the top level.
const { Role, AuthProvider } = prismaPkg;

// =====================================================================
// OAUTH SERVICE — Google + Apple
// =====================================================================
// Both providers verify the ID token server-side (never trust the
// client), then look up an existing user by:
//   1. provider-specific subject (`googleId` / `appleId`)
//   2. email (case-insensitive)
// If found by email, the OAuth ID is linked to the existing account so
// future logins skip the email lookup. If not found, a new account is
// created with `role = WORKER` (least-privilege; admins promote
// trusted OAuth users via the staff module) and `emailVerified = true`
// (Google/Apple verify the email before issuing the token).
//
// Returns the same `{ accessToken, refreshToken, user }` shape as the
// existing email-password login so the frontend's session handling is
// unchanged.

// Comma-separated list of audience client IDs for each provider. Empty
// when the relevant OAuth app hasn't been registered yet — endpoints
// return 503 in that case so we don't accidentally accept any token.
const googleClientIds = (process.env.GOOGLE_OAUTH_CLIENT_IDS ?? "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

const appleClientIds = (process.env.APPLE_CLIENT_IDS ?? "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

const googleClient = new OAuth2Client();

// ---------------------------------------------------------------------
// GOOGLE
// ---------------------------------------------------------------------

const verifyGoogleToken = async (idToken) => {
  if (googleClientIds.length === 0) {
    const err = new Error("Google OAuth is not configured on this server");
    err.code = "OAUTH_NOT_CONFIGURED";
    throw err;
  }
  let ticket;
  try {
    ticket = await googleClient.verifyIdToken({
      idToken,
      audience: googleClientIds,
    });
  } catch (e) {
    const err = new Error("Invalid Google token");
    err.code = "INVALID_OAUTH_TOKEN";
    throw err;
  }
  const payload = ticket.getPayload();
  if (!payload?.email) {
    const err = new Error("Google token missing email");
    err.code = "INVALID_OAUTH_TOKEN";
    throw err;
  }
  if (payload.email_verified === false) {
    const err = new Error("Google email is not verified");
    err.code = "INVALID_OAUTH_TOKEN";
    throw err;
  }
  return {
    email: payload.email.toLowerCase(),
    name: payload.name ?? null,
    sub: payload.sub,
  };
};

export const loginWithGoogle = async ({ idToken }) => {
  const { email, name, sub } = await verifyGoogleToken(idToken);

  // 1) Look up by Google subject first (cheapest, most specific).
  let user = await prisma.user.findUnique({ where: { googleId: sub } });

  // 2) Fall back to email — links Google to an existing email account.
  if (!user) {
    user = await prisma.user.findUnique({ where: { email } });
  }

  if (user) {
    // Link Google to the existing account (idempotent on re-login).
    user = await prisma.user.update({
      where: { id: user.id },
      data: {
        googleId: sub,
        authProvider: AuthProvider.GOOGLE,
        emailVerified: true,
      },
    });
  } else {
    const userName = await pickUniqueUserName({
      preferred: name,
      email,
    });
    user = await prisma.user.create({
      data: {
        email,
        userName,
        password: null,
        role: Role.WORKER,
        authProvider: AuthProvider.GOOGLE,
        googleId: sub,
        emailVerified: true,
      },
    });
  }

  return issueTokens(user);
};

// ---------------------------------------------------------------------
// APPLE
// ---------------------------------------------------------------------

const verifyAppleToken = async (identityToken) => {
  if (appleClientIds.length === 0) {
    const err = new Error("Apple Sign-In is not configured on this server");
    err.code = "OAUTH_NOT_CONFIGURED";
    throw err;
  }
  let payload;
  try {
    payload = await appleSignin.verifyIdToken(identityToken, {
      audience: appleClientIds,
      // Library throws on expired tokens by default; explicit for clarity.
      ignoreExpiration: false,
    });
  } catch (e) {
    const err = new Error("Invalid Apple token");
    err.code = "INVALID_OAUTH_TOKEN";
    throw err;
  }
  if (!payload?.email) {
    // Apple only returns the email on the *first* sign-in unless the
    // user has opted to share it on every login. If the relay is
    // missing, we can't proceed (existing user lookup needs email).
    const err = new Error(
      "Apple token did not include an email — first sign-in must include scope: email",
    );
    err.code = "INVALID_OAUTH_TOKEN";
    throw err;
  }
  return {
    email: payload.email.toLowerCase(),
    sub: payload.sub,
  };
};

export const loginWithApple = async ({ identityToken }) => {
  const { email, sub } = await verifyAppleToken(identityToken);

  let user = await prisma.user.findUnique({ where: { appleId: sub } });
  if (!user) {
    user = await prisma.user.findUnique({ where: { email } });
  }

  if (user) {
    user = await prisma.user.update({
      where: { id: user.id },
      data: {
        appleId: sub,
        authProvider: AuthProvider.APPLE,
        emailVerified: true,
      },
    });
  } else {
    // Apple doesn't reliably return a name after the first sign-in, so
    // we always derive the username from the email's local part.
    const userName = await pickUniqueUserName({ preferred: null, email });
    user = await prisma.user.create({
      data: {
        email,
        userName,
        password: null,
        role: Role.WORKER,
        authProvider: AuthProvider.APPLE,
        appleId: sub,
        emailVerified: true,
      },
    });
  }

  return issueTokens(user);
};

// ---------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------

// Issues access + refresh tokens identical to the email-password flow.
// Persists the refresh token row so /auth/refresh works the same way.
const issueTokens = async (user) => {
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
      authProvider: user.authProvider,
    },
  };
};

// Derives a unique username. Strategy:
//   1. Slug the preferred name (e.g. Google `name`) → "john.smith".
//   2. Otherwise slug the email local part.
//   3. On collision, append "-2", "-3", ... until one is free.
const pickUniqueUserName = async ({ preferred, email }) => {
  const base = slugify(preferred || email.split("@")[0]) || "user";
  let candidate = base;
  let suffix = 1;
  // Cap at 50 attempts so a pathological collision can't block sign-up.
  for (let i = 0; i < 50; i += 1) {
    const taken = await prisma.user.findUnique({
      where: { userName: candidate },
      select: { id: true },
    });
    if (!taken) return candidate;
    suffix += 1;
    candidate = `${base}-${suffix}`;
  }
  // Extreme fallback — append a short random hex.
  return `${base}-${Math.random().toString(16).slice(2, 8)}`;
};

const slugify = (s) =>
  s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ".")
    .replace(/^\.+|\.+$/g, "")
    .slice(0, 30);
