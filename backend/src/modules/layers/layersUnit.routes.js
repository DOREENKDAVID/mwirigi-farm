import express from "express";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { getLayersUnit } from "./layersUnit.service.js";

// =====================================================================
// /api/layers-unit
// =====================================================================
// Unified Layers Unit dashboard. Returns the complete payload for the
// Layers page in one round-trip:
//   { layers, brooder, production, vaccination, allocation }
// All authenticated users can read.

const router = express.Router();

router.get("/", authMiddleware, async (_req, res) => {
  try {
    const payload = await getLayersUnit();
    res.json(payload);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
