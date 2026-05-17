import express from "express";
import * as controller from "./staff.controller.js";
import {
  authMiddleware,
  authorizeRoles,
} from "../../middleware/auth.middleware.js";

// Role mapping:
//   ADMIN, CEO   — full access (create/edit staff, run payroll)
//   Any auth     — read dashboard, attendance today, list tasks
//   ADMIN, CEO + each unit's manager + VET — assign/update tasks
//   Self-attendance (check-in/out) — any authenticated user

const ADMIN = ["ADMIN", "CEO"];
const STAFF_WRITERS = ["ADMIN", "CEO"];
const TASK_WRITERS = [
  "ADMIN",
  "CEO",
  "DAIRY_MANAGER",
  "LAYERS_MANAGER",
  "PIGGERY_MANAGER",
  "FEEDLOT_MANAGER",
  "STORE_MANAGER",
  "VET",
];

const router = express.Router();

// ===== Dashboard (one-shot read) =====
router.get("/dashboard", authMiddleware, controller.getDashboard);

// ===== Staff CRUD =====
router.post(
  "/",
  authMiddleware,
  authorizeRoles(...STAFF_WRITERS),
  controller.createStaff,
);
router.get("/", authMiddleware, controller.listStaff);
router.get("/:id", authMiddleware, controller.getStaffById);
router.patch(
  "/:id",
  authMiddleware,
  authorizeRoles(...STAFF_WRITERS),
  controller.updateStaff,
);
router.delete(
  "/:id",
  authMiddleware,
  authorizeRoles(...ADMIN),
  controller.deleteStaff,
);

// ===== Attendance =====
router.get(
  "/attendance/today",
  authMiddleware,
  controller.getTodayAttendance,
);
router.post(
  "/attendance",
  authMiddleware,
  authorizeRoles(...STAFF_WRITERS),
  controller.markAttendance,
);
router.post(
  "/attendance/check-in",
  authMiddleware,
  controller.checkIn,
);
router.post(
  "/attendance/check-out",
  authMiddleware,
  controller.checkOut,
);

// ===== Tasks =====
router.get("/tasks", authMiddleware, controller.listTasksToday);
router.post(
  "/tasks",
  authMiddleware,
  authorizeRoles(...TASK_WRITERS),
  controller.createTask,
);
router.patch(
  "/tasks/:id",
  authMiddleware,
  authorizeRoles(...TASK_WRITERS),
  controller.updateTask,
);
router.delete(
  "/tasks/:id",
  authMiddleware,
  authorizeRoles(...TASK_WRITERS),
  controller.deleteTask,
);

router.post(
  "/tasks/:id/reassign",
  authMiddleware,
  authorizeRoles(...TASK_WRITERS),
  controller.reassignTask,
);

router.patch(
  "/workers/:id/availability",
  authMiddleware,
  authorizeRoles(...TASK_WRITERS),
  controller.setWorkerAvailability,
);

// ===== Payroll =====
router.get(
  "/payroll",
  authMiddleware,
  authorizeRoles(...STAFF_WRITERS),
  controller.getPayroll,
);
router.post(
  "/payroll/process",
  authMiddleware,
  authorizeRoles(...ADMIN),
  controller.processPayroll,
);

// ===== Payroll adjustments (advances / bonuses / penalties / overtime) =====
router.get(
  "/payroll/adjustments",
  authMiddleware,
  controller.listAdjustments,
);
router.post(
  "/payroll/adjustments",
  authMiddleware,
  authorizeRoles(...STAFF_WRITERS),
  controller.createAdjustment,
);
router.patch(
  "/payroll/adjustments/:id",
  authMiddleware,
  authorizeRoles(...STAFF_WRITERS),
  controller.updateAdjustment,
);
router.delete(
  "/payroll/adjustments/:id",
  authMiddleware,
  authorizeRoles(...ADMIN),
  controller.deleteAdjustment,
);

export default router;
