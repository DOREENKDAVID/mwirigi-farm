import { z } from "zod";

export const registerSchema = z
  .object({
    userName: z
      .string()
      .trim()
      .min(3, "Username must be at least 3 characters")
      .max(30, "Username must be at most 30 characters")
      .regex(/^[a-zA-Z0-9_-]+$/, "Username may only contain letters, numbers, underscores, and hyphens"),

    email: z
      .string()
      .email("Invalid email format")
      .transform((val) => val.toLowerCase()),

    password: z
      .string()
      .min(8, "Password must be at least 8 characters")
      .regex(/[A-Z]/, "Password must include an uppercase letter")
      .regex(/[a-z]/, "Password must include a lowercase letter")
      .regex(/\d/, "Password must include a number")
      .regex(/[^A-Za-z0-9]/, "Password must include a special character"),

    confirmPassword: z.string().min(1, "Confirm your password"),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Passwords do not match",
    path: ["confirmPassword"],
  });

// Login accepts either email or username in a single `identifier` field.
// Both forms are stored lowercased, so we lowercase here for lookup parity.
export const loginSchema = z.object({
  identifier: z
    .string()
    .trim()
    .min(1, "Email or username is required")
    .transform((val) => val.toLowerCase()),
  password: z.string().min(1, "Password is required"),
});

// OTP schema for password reset
export const otpSchema = z.object({
  email: z.string().email("Invalid email format").transform((val) => val.toLowerCase()),
  enteredOtp: z.string().length(6, "OTP must be exactly 6 digits")
});

// Admin-only staff creation. Role is selected by the admin (a CEO),
// unlike public /register which always assigns VET server-side.
export const createStaffSchema = z.object({
  userName: z
    .string()
    .trim()
    .min(3, "Username must be at least 3 characters")
    .max(30, "Username must be at most 30 characters")
    .regex(/^[a-zA-Z0-9_-]+$/, "Username may only contain letters, numbers, underscores, and hyphens"),

  email: z
    .string()
    .email("Invalid email format")
    .transform((val) => val.toLowerCase()),

  password: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .regex(/[A-Z]/, "Password must include an uppercase letter")
    .regex(/[a-z]/, "Password must include a lowercase letter")
    .regex(/\d/, "Password must include a number")
    .regex(/[^A-Za-z0-9]/, "Password must include a special character"),

  role: z.enum([
    "CEO",
    "DAIRY_MANAGER",
    "LAYERS_MANAGER",
    "PIGGERY_MANAGER",
    "VET",
    "ICT",
  ]),
});

// Password reset schema
export const resetPasswordSchema = z.object({
  email: z.string().email("Invalid email format").transform((val) => val.toLowerCase()),
  enteredOtp: z.string().length(6, "OTP must be exactly 6 digits"),
  newPassword: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .regex(/[A-Z]/, "Password must include an uppercase letter")
    .regex(/[a-z]/, "Password must include a lowercase letter")
    .regex(/\d/, "Password must include a number")
    .regex(/[^A-Za-z0-9]/, "Password must include a special character")
});

// OAuth login schemas. The ID/identity tokens are JWTs (~1KB), capped
// generously at 4KB to defend against pathological input.
export const googleLoginSchema = z.object({
  idToken: z.string().trim().min(20, "idToken is required").max(4096),
});

export const appleLoginSchema = z.object({
  identityToken: z.string().trim().min(20, "identityToken is required").max(4096),
});

export const validate = (schema) => (req, res, next) => {
  try {
    const result = schema.parse(req.body);
    req.body = result; // sanitized + transformed
    next();
  } catch (err) {
    return res.status(400).json({
      message: "Validation error",
      errors: err.errors.map((e) => e.message), // detailed error messages
    });
  }
};