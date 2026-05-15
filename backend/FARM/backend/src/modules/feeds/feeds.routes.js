import express from "express";
import * as controller from "./feeds.controller.js";
import {
  authMiddleware,
  authorizeRoles,
} from "../../middleware/auth.middleware.js";

// Role mapping:
//   Reads     — any authenticated user
//   Writes    — ADMIN, CEO, FEEDS_MANAGER
//
// (Spec mentioned a FARM_MANAGER role; the existing Role enum doesn't
// have one, so CEO covers that responsibility.)

const writers = authorizeRoles("ADMIN", "CEO", "FEEDS_MANAGER");
const router = express.Router();

// ------- Dashboard -------
router.get("/dashboard", authMiddleware, controller.getDashboard);

// ------- Materials -------
router.get("/materials", authMiddleware, controller.listMaterials);
router.get("/materials/:id", authMiddleware, controller.getMaterialById);
router.post("/materials", authMiddleware, writers, controller.createMaterial);
router.patch(
  "/materials/:id",
  authMiddleware,
  writers,
  controller.updateMaterial,
);
router.delete(
  "/materials/:id",
  authMiddleware,
  writers,
  controller.deleteMaterial,
);

// ------- Deliveries -------
router.get("/deliveries", authMiddleware, controller.listDeliveries);
router.post(
  "/deliveries",
  authMiddleware,
  writers,
  controller.createDelivery,
);

// ------- Consumption -------
router.post(
  "/consumption",
  authMiddleware,
  writers,
  controller.createConsumption,
);
router.post(
  "/consumption/bulk",
  authMiddleware,
  writers,
  controller.createBulkConsumption,
);

// ------- Bulk feed -------
router.get("/bulk-feed", authMiddleware, controller.listBulkFeed);
router.patch(
  "/bulk-feed/:id",
  authMiddleware,
  writers,
  controller.updateBulkFeed,
);

// ------- Distribution -------
router.get("/distribution", authMiddleware, controller.listDistribution);
router.post(
  "/distribution",
  authMiddleware,
  writers,
  controller.upsertDistribution,
);

export default router;
