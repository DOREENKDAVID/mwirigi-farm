import bcrypt from "bcrypt";

export const generateOTP = () =>
  Math.floor(100000 + Math.random() * 900000).toString();

export const hashOTP = (otp) => bcrypt.hash(otp, 10);

export const compareOTP = (enteredOtp, hashedOtp) =>
  bcrypt.compare(enteredOtp, hashedOtp);