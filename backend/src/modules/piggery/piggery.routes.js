import express from "express";
import * as controller from "./piggery.controller.js";
import {
  authMiddleware,
  authorizeRoles,
} from "../../middleware/auth.middleware.js";

// Role mapping (mirrors dairy/layers):
//   CEO             → full access
//   PIGGERY_MANAGER → full access
//   VET             → read + log farrowing
//   Anyone else     → read-only

const router = express.Router();

// ------- Reads (any authenticated user) -------
router.get("/kpis",       authMiddleware, controller.getKpis);
router.get("/houses",     authMiddleware, controller.listHouses);
router.get("/sows",       authMiddleware, controller.listSows);
router.get("/boars",      authMiddleware, controller.listBoars);
router.get("/litters",    authMiddleware, controller.listLitters);
router.get("/nursery",    authMiddleware, controller.listNursery);
router.get("/fattening",  authMiddleware, controller.listFattening);
router.get("/finishing",  authMiddleware, controller.listFinishing);
router.get("/farrowing",  authMiddleware, controller.listFarrowing);
router.get("/trend",      authMiddleware, controller.getTrend);

// ------- Writes -------
router.post(
  "/pigs",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER"),
  controller.createPig,
);

router.post(
  "/farrowing",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER", "VET"),
  controller.logFarrowing,
);

router.patch(
  "/pigs/:id",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER"),
  controller.updatePig,
);

router.delete(
  "/pigs/:id",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER"),
  controller.softDeletePig,
);

// ------- Litter / Nursery / Pen CRUD -------
router.post(
  "/litters",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER", "VET"),
  controller.createLitter,
);
router.patch(
  "/litters/:id",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER", "VET"),
  controller.updateLitter,
);
router.delete(
  "/litters/:id",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER"),
  controller.deleteLitter,
);

router.post(
  "/nursery",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER", "VET"),
  controller.createNursery,
);
router.patch(
  "/nursery/:id",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER", "VET"),
  controller.updateNursery,
);
router.delete(
  "/nursery/:id",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER"),
  controller.deleteNursery,
);

router.post(
  "/pens",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER"),
  controller.createPen,
);
router.patch(
  "/pens/:id",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER"),
  controller.updatePen,
);
router.post(
  "/pens/:id/release",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER"),
  controller.releasePen,
);
router.delete(
  "/pens/:id",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER"),
  controller.deletePen,
);

// ------- Inventory -------
router.get("/inventory", authMiddleware, controller.listInventory);
router.post(
  "/inventory",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER", "VET", "ADMIN"),
  controller.createInventory,
);
router.patch(
  "/inventory/:id",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER", "VET", "ADMIN"),
  controller.updateInventory,
);
router.delete(
  "/inventory/:id",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER", "VET", "ADMIN"),
  controller.deleteInventory,
);

// ------- Farmers Choice dispatch log -------
// Read open to any authenticated user; write restricted to roles that
// can actually load the truck. Soft-delete behind CEO/ADMIN since FC
// records are operational + financial — manager can't quietly erase
// what shipped.
router.get(
  "/fc-deliveries",
  authMiddleware,
  controller.listFcDeliveries,
);
router.post(
  "/fc-deliveries",
  authMiddleware,
  authorizeRoles("CEO", "PIGGERY_MANAGER", "ADMIN"),
  controller.createFcDelivery,
);
router.delete(
  "/fc-deliveries/:id",
  authMiddleware,
  authorizeRoles("CEO", "ADMIN"),
  controller.deleteFcDelivery,
);

export default router;
