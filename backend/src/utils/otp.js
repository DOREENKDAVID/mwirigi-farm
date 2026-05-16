import bcrypt from "bcrypt";

export const generateOTP = () => {
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  console.info(`Generated OTP: ${otp}`); // For debugging, remove in production
  return otp;
};

export const hashOTP = async (otp) => {
  try {
    const hashedOtp = await bcrypt.hash(otp, 10);
    console.info("OTP hashed successfully.");
    return hashedOtp;
  } catch (err) {
    console.error("Error hashing OTP:", err.message);
    throw new Error("Failed to hash OTP");
  }
};

export const compareOTP = async (enteredOtp, hashedOtp) => {
  try {
    const isMatch = await bcrypt.compare(enteredOtp, hashedOtp);
    console.info("OTP comparison result:", isMatch);
    return isMatch;
  } catch (err) {
    console.error("Error comparing OTP:", err.message);
    throw new Error("Failed to compare OTP");
  }
};