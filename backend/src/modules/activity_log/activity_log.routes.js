import express from "express";
import { listAuditLogs } from "../../utils/audit.js";
import { authMiddleware, authorizeRoles } from "../../middleware/auth.middleware.js";

const router = express.Router();

// GET /api/activity-log
// Query params: entity, entityId, module, actorId, from, to, limit, offset
router.get(
  "/",
  authMiddleware,
  authorizeRoles("CEO", "ADMIN", "LAYERS_MANAGER", "DAIRY_MANAGER", "VET", "STAFF_MANAGER", "PIGGERY_MANAGER", "FEEDLOT_MANAGER"),
  async (req, res) => {
    try {
      const { entity, entityId, module, actorId, from, to, limit, offset } =
        req.query;
      const result = await listAuditLogs({
        entity,
        entityId,
        module,
        actorId,
        from,
        to,
        limit: limit ? Number(limit) : 50,
        offset: offset ? Number(offset) : 0,
      });
      res.json(result);
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  },
);

export default router;
