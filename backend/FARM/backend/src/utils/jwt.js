import jwt from "jsonwebtoken";

// 🔒 Access token (short-lived)
export const generateAccessToken = (user) => {
  try {
    const token = jwt.sign(
      {
        id: user.id,
        role: user.role,
        email: user.email
      },
      process.env.JWT_SECRET,
      { expiresIn: "15m" } // short-lived
    );
    console.info(`Access token generated for user ${user.id}`);
    return token;
  } catch (err) {
    console.error("Error generating access token:", err.message);
    throw new Error("Failed to generate access token");
  }
};

// 🔄 Refresh token (long-lived)
export const generateRefreshToken = () => {
  try {
    const token = jwt.sign(
      {},
      process.env.JWT_REFRESH_SECRET,
      { expiresIn: "7d" }
    );
    console.info("Refresh token generated.");
    return token;
  } catch (err) {
    console.error("Error generating refresh token:", err.message);
    throw new Error("Failed to generate refresh token");
  }
};