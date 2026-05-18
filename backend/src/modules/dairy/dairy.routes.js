import express from "express";
import * as dairyController from "./dairy.controller.js";
import {
  authorizeRoles,
  authMiddleware,
} from "../../middleware/auth.middleware.js";

const dairyRoutes = express.Router();

// Role mapping (matches schema.prisma's Role enum):
//   CEO            → full dairy access
//   DAIRY_MANAGER  → full dairy access
//   VET            → can log milk + view cows
//   Anyone else    → read-only (just authMiddleware)

//////////////////////////////////////////////////////
// 🐄 COW ROUTES
//////////////////////////////////////////////////////

dairyRoutes.post(
  "/cows",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER"),
  dairyController.createCow,
);

dairyRoutes.get("/cows", authMiddleware, dairyController.getAllCows);

dairyRoutes.get("/cows/tag/:tag", authMiddleware, dairyController.getCowByTag);

dairyRoutes.put(
  "/cows/tag/:tag",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER"),
  dairyController.updateCow,
);

dairyRoutes.delete(
  "/cows/tag/:tag",
  authMiddleware,
  authorizeRoles("CEO"),
  dairyController.deleteCow,
);

dairyRoutes.post(
  "/cows/tag/:tag/release",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER"),
  dairyController.releaseCow,
);

//////////////////////////////////////////////////////
// 🥛 MILK RECORD ROUTES
//////////////////////////////////////////////////////

dairyRoutes.post(
  "/milk",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER", "VET"),
  dairyController.createMilkRecord,
);

// Read-only listing — open to any authenticated user.
dairyRoutes.get("/milk", authMiddleware, dairyController.getMilkRecords);

dairyRoutes.get(
  "/milk/cow/:cowId",
  authMiddleware,
  dairyController.getMilkRecordsByCow,
);

dairyRoutes.delete(
  "/milk/:id",
  authMiddleware,
  authorizeRoles("CEO"),
  dairyController.deleteMilkRecord,
);

//////////////////////////////////////////////////////
// 📊 DASHBOARD / SUMMARY ROUTES
//////////////////////////////////////////////////////

dairyRoutes.get("/dashboard", authMiddleware, dairyController.getDairyDashboard);

// Compact KPI payload for the Flutter dairy summary cards.
dairyRoutes.get("/summary", authMiddleware, dairyController.getDairySummary);

//////////////////////////////////////////////////////
// 👷 WORKER ROUTES
//////////////////////////////////////////////////////

dairyRoutes.get("/workers", authMiddleware, dairyController.getWorkers);

dairyRoutes.get(
  "/workers/:workerId/cows",
  authMiddleware,
  dairyController.getCowsByWorker,
);

// Bulk reassign every cow currently assigned to `:workerId` to a
// replacement worker. Used when a worker is flipped to unavailable
// (sick / off / vacation / …) so the herd doesn't sit unassigned
// during the next milking session.
// Body: { toWorkerId }
dairyRoutes.post(
  "/workers/:workerId/reassign-cows",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER"),
  dairyController.reassignWorkerCows,
);

//////////////////////////////////////////////////////
// PHASE 2 + 3 — operational aggregation + bulk submit
//////////////////////////////////////////////////////

// Per-house roll-up for the "Houses overview" card.
dairyRoutes.get(
  "/houses/overview",
  authMiddleware,
  dairyController.getHousesOverview,
);

// Per-worker / per-session view that drives both the worker view and
// the manager view of the milk-logging panel.
dairyRoutes.get(
  "/milk/sessions/today",
  authMiddleware,
  dairyController.getTodaySessions,
);

// Today's gross / net (calf + household deductions applied).
dairyRoutes.get(
  "/milk/summary/today",
  authMiddleware,
  dairyController.getTodayNetSummary,
);

// PATCH the calf / household deductions used in the milk session
// summary. Body: { calfDeduction?: number, householdDeduct?: number }.
// Pass 0 (or omit) to revert the calf override and fall back to the
// live count of calving events under 4 months old.
dairyRoutes.patch(
  "/config/deductions",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER"),
  dairyController.updateMilkDeductions,
);

// Atomic bulk submit: { workerId, session, date, entries: [{cowId, litres}] }
// Idempotent — re-submitting the same (cow, date, session) overwrites.
dairyRoutes.post(
  "/milk/sessions",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER", "VET"),
  dairyController.submitMilkSession,
);

//////////////////////////////////////////////////////
// 📈 DAILY MILK — 7-DAY TREND
//////////////////////////////////////////////////////

// One row per day with the day-of-week label and total litres. Used by
// the "Daily milk — 7 days" bar chart on the Dairy page. ?days= can
// override the default 7-day window.
dairyRoutes.get(
  "/milk/trend/daily",
  authMiddleware,
  dairyController.getDailyMilkTrend,
);

//////////////////////////////////////////////////////
// 🐮 CALVES REGISTER
//////////////////////////////////////////////////////

// CALVING reproduction records joined with dam and (when matched) calf cow.
dairyRoutes.get("/calves", authMiddleware, dairyController.getCalvesRegister);

// Record a calf disposition (sold / died / transferred / lost). Updates
// the underlying CALVING ReproductionRecord with calvingFate + notes,
// and — when the calf has a Cow row — sets releasedAt in the same
// transaction. PDF receipt for sales is generated client-side.
dairyRoutes.post(
  "/calves/:id/dispose",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER"),
  dairyController.disposeCalf,
);

//////////////////////////////////////////////////////
// 📦 DAIRY INVENTORY
//////////////////////////////////////////////////////

dairyRoutes.get("/inventory", authMiddleware, dairyController.getDairyInventory);

dairyRoutes.post(
  "/inventory",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER"),
  dairyController.createDairyInventoryItem,
);

dairyRoutes.patch(
  "/inventory/:id",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER"),
  dairyController.updateDairyInventoryItem,
);

dairyRoutes.delete(
  "/inventory/:id",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER"),
  dairyController.deleteDairyInventoryItem,
);

//////////////////////////////////////////////////////
// 📊 DAIRY REPORTS — analytics dashboard (Phase 1: milk)
//////////////////////////////////////////////////////

// Read-only — any authenticated user can hit it, the controller scopes
// the payload by role (WORKER sees only their own production).
dairyRoutes.get(
  "/reports/milk",
  authMiddleware,
  dairyController.getMilkProductionReport,
);
dairyRoutes.get(
  "/reports/reproduction",
  authMiddleware,
  dairyController.getReproductionReport,
);
dairyRoutes.get(
  "/reports/health",
  authMiddleware,
  dairyController.getHealthReport,
);
dairyRoutes.get(
  "/reports/vaccinations",
  authMiddleware,
  dairyController.getVaccinationReport,
);

export default dairyRoutes;
