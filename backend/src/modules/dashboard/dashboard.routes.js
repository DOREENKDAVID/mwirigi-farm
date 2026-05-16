// dashboard.routes.js
import express from "express";
import { getDashboard, getOverview } from "./dashboard.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";

const router = express.Router();

// GET /api/dashboard — legacy stub (kept so existing callers don't 404).
router.get("/", getDashboard);

// GET /api/dashboard/overview — auth-protected, full CEO overview.
router.get("/overview", authMiddleware, getOverview);

export default router;