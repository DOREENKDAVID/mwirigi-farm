import express from "express";
import * as controller from "./finance.controller.js";
import {
  authMiddleware,
  authorizeRoles,
} from "../../middleware/auth.middleware.js";

const router = express.Router();

// CEO/ADMIN-only writes; reads open to any authenticated user (managers
// often need to glance at their own unit's KPIs even if they can't post).
router.get("/dashboard", authMiddleware, controller.dashboard);

router.get("/revenue", authMiddleware, controller.listRevenue);
router.post(
  "/revenue",
  authMiddleware,
  authorizeRoles("CEO", "ADMIN"),
  controller.createRevenue,
);

router.get("/expenses", authMiddleware, controller.listExpenses);
router.post(
  "/expenses",
  authMiddleware,
  authorizeRoles("CEO", "ADMIN"),
  controller.createExpense,
);

export default router;
