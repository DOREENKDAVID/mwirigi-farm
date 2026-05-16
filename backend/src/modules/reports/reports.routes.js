import express from "express";
import * as ReportsController from "./reports.controller.js";
import * as catalog from "./reports.catalog.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";

const router = express.Router();

// Legacy analytics endpoints (kept for backwards compatibility).
router.get("/daily-summary", ReportsController.getDailySummary);
router.get("/today", ReportsController.getTodayMetrics);
router.get("/analytics", ReportsController.getAnalyticsDashboard);
router.get("/dairy/monthly/csv", ReportsController.exportDairyCSV);

// v2 enterprise reports catalog. List + get + CSV download. PDF
// generation lives client-side via the `printing` package so the user
// gets the system print dialog (preview + share + save).
router.get("/catalog", authMiddleware, catalog.list);
router.get("/catalog/:key", authMiddleware, catalog.get);
router.get("/catalog/:key.csv", authMiddleware, catalog.downloadCsv);

export default router;