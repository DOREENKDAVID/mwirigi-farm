import express from "express";
import * as controller from "./sales.controller.js";
import {
  authMiddleware,
  authorizeRoles,
} from "../../middleware/auth.middleware.js";

const router = express.Router();

// All reads: any authenticated user
router.get("/", authMiddleware, controller.list);
router.get("/summary", authMiddleware, controller.summary);

// Writes: CEO, LAYERS_MANAGER, DAIRY_MANAGER (and VET for occasional logging)
router.post(
  "/",
  authMiddleware,
  authorizeRoles("CEO", "LAYERS_MANAGER", "DAIRY_MANAGER", "VET"),
  controller.create,
);

router.patch(
  "/:id",
  authMiddleware,
  authorizeRoles("CEO", "LAYERS_MANAGER", "DAIRY_MANAGER", "VET"),
  controller.update,
);

router.delete(
  "/:id",
  authMiddleware,
  authorizeRoles("CEO", "LAYERS_MANAGER", "DAIRY_MANAGER"),
  controller.remove,
);

export default router;
