import express from "express";
import * as controller from "./reproduction.controller.js";
import {
  authMiddleware,
  authorizeRoles,
} from "../../middleware/auth.middleware.js";

// Role mapping (matches the dairy module's policy):
//   Read           — any authenticated user
//   POST / PATCH   — CEO, DAIRY_MANAGER, VET (vets do AI work)
//   DELETE         — CEO

const router = express.Router();

router.get("/", authMiddleware, controller.list);
router.get("/:cowId", authMiddleware, controller.getHistory);

router.post(
  "/",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER", "VET"),
  controller.create,
);

// Confirm the cow's most recent AI in one call. Used by the "Pregnancy
// confirmed" option in the m-repro modal.
router.post(
  "/confirm",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER", "VET"),
  controller.confirmPregnancy,
);

router.patch(
  "/:id",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER", "VET"),
  controller.update,
);

router.delete(
  "/:id",
  authMiddleware,
  authorizeRoles("CEO"),
  controller.softDelete,
);

export default router;
