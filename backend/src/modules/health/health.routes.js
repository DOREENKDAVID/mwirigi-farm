import express from "express";
import * as controller from "./health.controller.js";
import {
  authMiddleware,
  authorizeRoles,
} from "../../middleware/auth.middleware.js";

// =====================================================================
// /api/health/*
// =====================================================================
// Cross-unit health & vaccination dashboard.
//
// Role mapping:
//   CEO + VET → write access (log vaccinations, manage treatments)
//   Anyone authenticated → read

const router = express.Router();

// ----- KPI tile -----
router.get("/kpis", authMiddleware, controller.getKpis);

// ----- Vaccination schedule -----
router.get("/vaccinations", authMiddleware, controller.listVaccinations);
router.post(
  "/vaccinations",
  authMiddleware,
  authorizeRoles("CEO", "VET"),
  controller.createVaccinationRecord,
);

// ----- Protocol definitions (admin/vet only) -----
router.get(
  "/protocols",
  authMiddleware,
  authorizeRoles("CEO", "VET", "ADMIN"),
  controller.listProtocols,
);

// ----- Active treatments -----
router.get("/treatments", authMiddleware, controller.listTreatments);
router.post(
  "/treatments",
  authMiddleware,
  authorizeRoles("CEO", "VET"),
  controller.createTreatment,
);
router.patch(
  "/treatments/:id",
  authMiddleware,
  authorizeRoles("CEO", "VET"),
  controller.updateTreatment,
);

// ----- Vet protocol reference library -----
router.get(
  "/protocol-reference",
  authMiddleware,
  controller.getProtocolReference,
);

export default router;
