import express from "express";
import * as controller from "./layers.controller.js";
import * as inventory from "./inventory/layersInventory.controller.js";
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

export default router;
