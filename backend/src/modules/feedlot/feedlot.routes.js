import express from "express";
import * as controller from "./feedlot.controller.js";
import {
  authMiddleware,
  authorizeRoles,
} from "../../middleware/auth.middleware.js";

// Role mapping (no FEEDLOT_MANAGER role exists; using CEO + VET for writes
// since vets handle livestock husbandry):
//   Reads     — any authenticated user
//   Writes    — CEO, VET

const router = express.Router();

// ------- Reads -------
router.get("/kpis", authMiddleware, controller.getKpis);
router.get("/bulls", authMiddleware, controller.listBulls);
router.get("/sheep", authMiddleware, controller.listSheep);
router.get("/lambing", authMiddleware, controller.listLambing);

// ------- Writes -------
router.post(
  "/bulls",
  authMiddleware,
  authorizeRoles("CEO", "VET"),
  controller.createBull,
);

router.patch(
  "/bulls/:id",
  authMiddleware,
  authorizeRoles("CEO", "VET"),
  controller.updateBull,
);

router.delete(
  "/bulls/:id",
  authMiddleware,
  authorizeRoles("CEO", "VET"),
  controller.deleteBull,
);

router.post(
  "/bulls/:id/sell",
  authMiddleware,
  authorizeRoles("CEO", "VET"),
  controller.sellBull,
);

router.post(
  "/sheep/:id/sell",
  authMiddleware,
  authorizeRoles("CEO", "VET"),
  controller.sellSheep,
);

router.post(
  "/weights",
  authMiddleware,
  authorizeRoles("CEO", "VET"),
  controller.logWeight,
);

router.post(
  "/sheep",
  authMiddleware,
  authorizeRoles("CEO", "VET"),
  controller.createSheep,
);

router.patch(
  "/sheep/:id",
  authMiddleware,
  authorizeRoles("CEO", "VET"),
  controller.updateSheep,
);

router.delete(
  "/sheep/:id",
  authMiddleware,
  authorizeRoles("CEO", "VET"),
  controller.deleteSheep,
);

router.post(
  "/lambing",
  authMiddleware,
  authorizeRoles("CEO", "VET"),
  controller.logLambing,
);

// ------- Inventory -------
router.get("/inventory", authMiddleware, controller.listInventory);
router.post(
  "/inventory",
  authMiddleware,
  authorizeRoles("CEO", "VET", "ADMIN"),
  controller.createInventory,
);
router.patch(
  "/inventory/:id",
  authMiddleware,
  authorizeRoles("CEO", "VET", "ADMIN"),
  controller.updateInventory,
);
router.delete(
  "/inventory/:id",
  authMiddleware,
  authorizeRoles("CEO", "VET", "ADMIN"),
  controller.deleteInventory,
);

export default router;
