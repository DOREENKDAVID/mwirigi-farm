import express from "express";
import rateLimit from "express-rate-limit";
import { z } from "zod";

import {
  register,login,
  verifyEmailController,
  forgotPasswordController,
  resetPasswordController,
  refreshTokenController,
  logoutController,
  createStaffController,
  googleLogin,
  appleLogin,
  resendOtpController,
} from "./auth.controller.js";

import {validate } from "../../middleware/validate.middleware.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import authorizeRoles  from "../../middleware/role.middleware.js";

import {
  registerSchema,
  loginSchema,
  otpSchema,
  resetPasswordSchema,
  createStaffSchema,
  googleLoginSchema,
  appleLoginSchema,
} from "./auth.validation.js";

// Forgot-password only needs an email — user hasn't received an OTP yet.
const forgotPasswordSchema = z.object({
  email: z.string().email("Invalid email format").transform((v) => v.toLowerCase()),
});

const authRouter = express.Router();

// Rate limiting middleware
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // limit each IP to 10 requests per windowMs
  message: "Too many login attempts, please try again later."
});

const otpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // limit each IP to 5 OTP requests per windowMs
  message: "Too many OTP requests, please try again later."
});

//////////////////////////////////////////////////////
// AUTH ROUTES
//////////////////////////////////////////////////////
authRouter.post("/refresh-token", refreshTokenController);
authRouter.post("/logout", logoutController);
authRouter.post("/register", validate(registerSchema), register);

authRouter.post("/login", loginLimiter, validate(loginSchema), login);

// OAuth login. Same response shape as /login so the frontend doesn't
// need a separate session path. Rate-limited like /login since both
// authenticate against credentials.
authRouter.post(
  "/google",
  loginLimiter,
  validate(googleLoginSchema),
  googleLogin,
);
authRouter.post(
  "/apple",
  loginLimiter,
  validate(appleLoginSchema),
  appleLogin,
);

authRouter.post("/verify-email", otpLimiter, validate(otpSchema), verifyEmailController);
authRouter.post("/resend-otp", otpLimiter, validate(forgotPasswordSchema), resendOtpController);

authRouter.post("/forgot-password", otpLimiter, validate(forgotPasswordSchema), forgotPasswordController);

authRouter.post("/reset-password", validate(resetPasswordSchema), resetPasswordController);

//////////////////////////////////////////////////////
// PROTECTED ROUTES (RBAC)
//////////////////////////////////////////////////////

// CEO-only: create a staff account with a chosen role.
authRouter.post(
  "/admin/users",
  authMiddleware,
  authorizeRoles("CEO"),
  validate(createStaffSchema),
  createStaffController,
);

// Only CEO
authRouter.get(
  "/admin",
  authMiddleware,
  authorizeRoles("CEO"),
  (req, res) => {
    res.json({ message: "Welcome CEO" });
  }
);

// Example: multiple roles
authRouter.get(
  "/management",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER", "LAYERS_MANAGER"),
  (req, res) => {
    res.json({ message: "Management access granted" });
  }
);

export default authRouter;