import express from "express";
import * as controller from "./ngushish.controller.js";
import {
  authMiddleware,
  authorizeRoles,
} from "../../middleware/auth.middleware.js";

// Role mapping (mirrors dairy/piggery conventions; no NGUSHISH_MANAGER role
// exists in the Role enum yet, so writes are limited to CEO + STORE_MANAGER
// since horticulture sales/dispatch flow through the stopover store):
//   Reads     — any authenticated user
//   Writes    — CEO, STORE_MANAGER

const writers = authorizeRoles("CEO", "STORE_MANAGER");
const router = express.Router();

// ------- Dashboard -------
router.get("/dashboard", authMiddleware, controller.getDashboard);

// ------- Crops -------
router.get("/crops", authMiddleware, controller.listCrops);
router.get("/crops/:id", authMiddleware, controller.getCropById);
router.post("/crops", authMiddleware, writers, controller.createCrop);
router.patch("/crops/:id", authMiddleware, writers, controller.updateCrop);
router.delete("/crops/:id", authMiddleware, writers, controller.deleteCrop);

// ------- Harvests -------
router.get("/harvests", authMiddleware, controller.listHarvests);
router.post("/harvests", authMiddleware, writers, controller.createHarvest);

// ------- Dispatches -------
router.get("/dispatches", authMiddleware, controller.listDispatches);
router.post(
  "/dispatches",
  authMiddleware,
  writers,
  controller.createDispatch,
);

// ------- Irrigation -------
router.get("/irrigation", authMiddleware, controller.listIrrigation);
router.post(
  "/irrigation",
  authMiddleware,
  writers,
  controller.createIrrigation,
);

// ------- Inventory -------
router.get("/inventory", authMiddleware, controller.listInventory);
router.post(
  "/inventory",
  authMiddleware,
  authorizeRoles("CEO", "STORE_MANAGER", "ADMIN"),
  controller.createInventory,
);
router.patch(
  "/inventory/:id",
  authMiddleware,
  authorizeRoles("CEO", "STORE_MANAGER", "ADMIN"),
  controller.updateInventory,
);
router.delete(
  "/inventory/:id",
  authMiddleware,
  authorizeRoles("CEO", "STORE_MANAGER", "ADMIN"),
  controller.deleteInventory,
);

export default router;
