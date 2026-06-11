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
// NOTE: this route must be declared before /vaccinations/:id so Express
// doesn't swallow "records" as an :id param.
router.patch(
  "/vaccinations/records/:id",
  authMiddleware,
  authorizeRoles("CEO", "VET"),
  controller.updateVaccinationRecord,
);

// ----- Protocol definitions (admin/vet only) -----
router.get(
  "/protocols",
  authMiddleware,
  authorizeRoles("CEO", "VET", "ADMIN"),
  controller.listProtocols,
);

// ----- Active treatments -----
//
// Sick-animal reports also land here (the dialog encodes severity in
// `notes` and uses "Pending vet review" as the medication sentinel),
// so the POST gate has to admit unit managers — not just CEO + VET —
// or a Dairy Manager can't flag one of their own cows. The controller
// then enforces that a unit manager can only file *for their unit*;
// CEO / VET / ADMIN may file for any unit.
router.get("/treatments", authMiddleware, controller.listTreatments);
router.post(
  "/treatments",
  authMiddleware,
  authorizeRoles(
    "CEO",
    "VET",
    "ADMIN",
    "DAIRY_MANAGER",
    "PIGGERY_MANAGER",
    "LAYERS_MANAGER",
    "FEEDLOT_MANAGER",
  ),
  controller.createTreatment,
);
// Treatment refinement (real medication, status changes) stays
// vet-only — managers raise the flag, the vet diagnoses.
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
