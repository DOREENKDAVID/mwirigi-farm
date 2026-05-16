import express from "express";
import * as controller from "./reminders.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";

const router = express.Router();

router.get("/kpis", authMiddleware, controller.kpis);
router.get("/", authMiddleware, controller.list);

// syntheticIds contain colons ("vaccine:abc:next-due"). Express will
// match a single :param up to the next slash, so colons are fine —
// just URL-encode the value on the client side before calling.
router.post("/:syntheticId/done", authMiddleware, controller.markDone);
router.post("/:syntheticId/snooze", authMiddleware, controller.snooze);
router.post("/:syntheticId/undo", authMiddleware, controller.undo);

export default router;
