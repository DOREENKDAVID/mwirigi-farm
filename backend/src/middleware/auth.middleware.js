import jwt from "jsonwebtoken";

export const authMiddleware = (req, res, next) => {
  const token = req.headers.authorization?.split(" ")[1];

  if (!token) {
    console.warn("Unauthorized access attempt: No token provided.");
    return res.status(401).json({ message: "No token provided" });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    console.error("Token verification failed:", err.message);
    if (err.name === "TokenExpiredError") {
      return res.status(401).json({ message: "Token expired" });
    }
    return res.status(401).json({ message: "Invalid token" });
  }
};

// Role-based access control middleware
export const authorizeRoles = (...allowedRoles) => {
  return (req, res, next) => {
    const user = req.user;

    if (!allowedRoles.includes(user.role)) {
      console.warn(
        `Access denied for user ${user.id} with role ${user.role}. Allowed roles: ${allowedRoles}`
      );
      return res.status(403).json({
        message: "Access denied"
      });
    }

    next();
  };
};

