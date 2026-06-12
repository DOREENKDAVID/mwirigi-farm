import {
  registerUser,
  loginUser,
  verifyEmailOtp,
  resetPasswordService,
  logoutUser,
  forgotPasswordService,
  createStaffUser,
  resendOtp,
} from "./auth.service.js";
import { loginWithGoogle, loginWithApple } from "./oauth.service.js";


// =====================================================================
// OAUTH — POST /auth/google + POST /auth/apple
// =====================================================================
// Both return the same response shape as /auth/login:
//   { token, refreshToken, user }
// so the frontend's existing token storage and session handling work
// without any branching for the OAuth path.

const handleOauthError = (res, err) => {
  if (err?.code === "OAUTH_NOT_CONFIGURED") {
    return res.status(503).json({ message: err.message });
  }
  if (err?.code === "INVALID_OAUTH_TOKEN") {
    return res.status(401).json({ message: err.message });
  }
  return res.status(400).json({ message: err.message });
};

export const googleLogin = async (req, res) => {
  try {
    const result = await loginWithGoogle(req.body);
    res.status(200).json({
      token: result.accessToken,
      refreshToken: result.refreshToken,
      user: result.user,
    });
  } catch (err) {
    handleOauthError(res, err);
  }
};

export const appleLogin = async (req, res) => {
  try {
    const result = await loginWithApple(req.body);
    res.status(200).json({
      token: result.accessToken,
      refreshToken: result.refreshToken,
      user: result.user,
    });
  } catch (err) {
    handleOauthError(res, err);
  }
};


// Register user

export const register = async (req, res) => {
  try {
    const user = await registerUser(req.body);
    res.status(201).json({
      message: "User registered. Check email for OTP",
      userId: user.id,
    });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
};


// Verify email
export const verifyEmailController = async (req, res) => {
  try {
    const isVerified = await verifyEmailOtp(req.body);
    res.status(200).json({
      message: "Email verified successfully",
      isVerified,
    });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
};


// Login user
export const login = async (req, res) => {
  try {
    const result = await loginUser(req.body);
    res.status(200).json({
      token: result.accessToken,
      refreshToken: result.refreshToken,
      user: result.user,
    });
  } catch (err) {
    // OAuth-only accounts: return 400 with a specific message so the
    // UI can route the user to the correct sign-in button. All other
    // failures stay 401 with the generic "Invalid credentials" message
    // to prevent enumeration.
    const status = err.code === "OAUTH_ONLY_ACCOUNT" ? 400 : 401;
    res.status(status).json({ message: err.message });
  }
};


// Refresh token
export const refreshTokenController = async (req, res) => {
  res.status(501).json({ message: "Refresh token flow not implemented yet" });
};

// Logout user
export const logoutController = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    await logoutUser(refreshToken);
    res.json({ message: "Logged out successfully" });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
};

// Forgot password
export const forgotPasswordController = async (req, res) => {
  try {
    await forgotPasswordService(req.body.email);
    res.status(200).json({ message: "Reset OTP sent to email" });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
};

// Resend OTP (email verification or password reset)
export const resendOtpController = async (req, res) => {
  try {
    await resendOtp(req.body.email);
    res.status(200).json({ message: "A new code has been sent to your email" });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
};


// Admin-only: create a staff user with a chosen role (route is gated to CEO).
export const createStaffController = async (req, res) => {
  try {
    const user = await createStaffUser(req.body);
    res.status(201).json({ message: "Staff account created", user });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
};

//reset password
export const resetPasswordController = async (req, res) => {
  try {
    await resetPasswordService(req.body);
    res.status(200).json({ message: "Password reset successfully" });
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
};



