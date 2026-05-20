import express from "express";
import * as controller from "./layers.controller.js";
import * as inventory from "./inventory/layersInventory.controller.js";
import * as brooder from "./brooder.controller.js";
import {
  authMiddleware,
  authorizeRoles,
} from "../../middleware/auth.middleware.js";

// Role mapping:
//   CEO            → full access
//   LAYERS_MANAGER → full access (logs daily entries)
//   VET            → read + log daily entries
//   Anyone else    → read-only

const router = express.Router();

// ------- Reads (any authenticated user) -------
router.get("/kpis", authMiddleware, controller.getKpis);
router.get("/houses", authMiddleware, controller.getHouses);
router.get("/snapshot", authMiddleware, controller.getSnapshot);
router.get("/trend", authMiddleware, controller.getTrend);
router.get(
  "/production/:houseId",
  authMiddleware,
  controller.getProductionForHouse,
);

// Period-scoped analytics for the Production pill. Distinct path so
// the legacy today/7-day endpoints don't break — the report adds the
// filter surface (period, houseId, startDate, endDate) on top.
router.get(
  "/reports/production",
  authMiddleware,
  controller.getProductionReport,
);

// ------- Writes -------
router.post(
  "/production",
  authMiddleware,
  authorizeRoles("CEO", "LAYERS_MANAGER", "VET"),
  controller.createDailyEntry,
);

// ------- Inventory -------
// Composite summary for the inventory pill: items + KPIs + alerts.
router.get("/inventory/summary", authMiddleware, inventory.summary);
router.get("/inventory", authMiddleware, inventory.list);
router.post(
  "/inventory",
  authMiddleware,
  authorizeRoles("CEO", "LAYERS_MANAGER"),
  inventory.create,
);
router.patch(
  "/inventory/:id",
  authMiddleware,
  authorizeRoles("CEO", "LAYERS_MANAGER"),
  inventory.update,
);
router.delete(
  "/inventory/:id",
  authMiddleware,
  authorizeRoles("CEO", "LAYERS_MANAGER"),
  inventory.softDelete,
);

// ------- Brooder Occurrences -------
router.get("/brooder/occurrences", authMiddleware, brooder.listOccurrences);
router.get(
  "/brooder/occurrences/weekly",
  authMiddleware,
  brooder.weeklyReport,
);
router.post(
  "/brooder/occurrences",
  authMiddleware,
  authorizeRoles("CEO", "LAYERS_MANAGER", "VET"),
  brooder.logOccurrence,
);

// ------- Allocation Plans -------
// Write access is strictly CEO + LAYERS_MANAGER per Wave 4 governance.
// Every write goes through createAllocationPlan which also appends an
// AuditLog row in the same transaction.
router.post(
  "/brooder/allocations",
  authMiddleware,
  authorizeRoles("CEO", "LAYERS_MANAGER"),
  brooder.createAllocation,
);
router.get(
  "/brooder/allocations/history",
  authMiddleware,
  brooder.allocationHistory,
);

export default router;
