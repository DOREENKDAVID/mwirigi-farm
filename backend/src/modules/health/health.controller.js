import * as healthService from "./health.service.js";
import {
  createVaccinationSchema,
  updateVaccinationRecordSchema,
  createTreatmentSchema,
  updateTreatmentSchema,
} from "./health.validation.js";

const handleZodError = (res, err) => {
  if (err?.issues) {
    return res.status(400).json({
      error: "Validation error",
      issues: err.issues.map((i) => ({ path: i.path, message: i.message })),
    });
  }
  return null;
};

// ---------------------------------------------------------------------
// GET /api/health/kpis
// ---------------------------------------------------------------------
export const getKpis = async (_req, res) => {
  try {
    res.json(await healthService.getKpis());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ---------------------------------------------------------------------
// GET /api/health/vaccinations
// ---------------------------------------------------------------------
// `?unit=` filters the rows to a single HealthUnit (e.g. `Dairy`,
// `Layers`). Used by the Dairy module's vaccination pill to consume
// the unified Health schedule without standing up a parallel system.
export const listVaccinations = async (req, res) => {
  try {
    const unit = typeof req.query.unit === "string" ? req.query.unit : null;
    const rows = await healthService.listVaccinations();
    const filtered = unit
      ? rows.filter(
          (r) => (r.unit ?? "").toLowerCase() === unit.toLowerCase(),
        )
      : rows;
    res.json(filtered);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ---------------------------------------------------------------------
// POST /api/health/vaccinations
// ---------------------------------------------------------------------
export const createVaccinationRecord = async (req, res) => {
  try {
    const body = createVaccinationSchema.parse(req.body);
    const userId = req.user?.id ?? null;
    const record = await healthService.createVaccinationRecord(body, userId);
    res.status(201).json(record);
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "Protocol not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

// ---------------------------------------------------------------------
// PATCH /api/health/vaccinations/records/:id
// ---------------------------------------------------------------------
export const updateVaccinationRecord = async (req, res) => {
  try {
    const body = updateVaccinationRecordSchema.parse(req.body);
    const userId = req.user?.id ?? null;
    const record = await healthService.updateVaccinationRecord(
      req.params.id,
      body,
      userId,
    );
    res.json(record);
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "Vaccination record not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

// ---------------------------------------------------------------------
// GET /api/health/protocols  → list of editable protocol definitions
// ---------------------------------------------------------------------
export const listProtocols = async (_req, res) => {
  try {
    res.json(await healthService.listProtocols());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ---------------------------------------------------------------------
// GET /api/health/treatments?activeOnly=true
// ---------------------------------------------------------------------
export const listTreatments = async (req, res) => {
  try {
    const activeOnly = req.query.activeOnly !== "false";
    res.json(await healthService.listTreatments({ activeOnly }));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ---------------------------------------------------------------------
// POST /api/health/treatments
// ---------------------------------------------------------------------
// Unit managers can only file a treatment for their own unit. CEO,
// VET and ADMIN are not gated — they triage cross-unit. The mapping
// is intentionally local to this controller: it's the only place
// where role-to-unit ownership matters today, and centralising it
// in middleware would tangle the auth layer with a single workflow's
// rules. FEEDLOT_MANAGER owns both Feedlot bulls and Doopers sheep.
const UNIT_OWNERSHIP = {
  DAIRY_MANAGER: ["Dairy"],
  PIGGERY_MANAGER: ["Piggery"],
  LAYERS_MANAGER: ["Layers"],
  FEEDLOT_MANAGER: ["Feedlot", "Doopers"],
};

export const createTreatment = async (req, res) => {
  try {
    const body = createTreatmentSchema.parse(req.body);

    const allowed = UNIT_OWNERSHIP[req.user?.role];
    if (allowed && !allowed.includes(body.unit)) {
      return res.status(403).json({
        error: `${req.user.role} can only report sick animals for unit(s): ${allowed.join(", ")}`,
      });
    }

    const treatment = await healthService.createTreatment(body);
    res.status(201).json(treatment);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(400).json({ error: err.message });
  }
};

// ---------------------------------------------------------------------
// PATCH /api/health/treatments/:id
// ---------------------------------------------------------------------
export const updateTreatment = async (req, res) => {
  try {
    const body = updateTreatmentSchema.parse(req.body);
    const treatment = await healthService.updateTreatment(
      req.params.id,
      body,
    );
    res.json(treatment);
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "Treatment not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

// ---------------------------------------------------------------------
// GET /api/health/protocol-reference  → vet protocol reference library
// ---------------------------------------------------------------------
export const getProtocolReference = async (_req, res) => {
  try {
    res.json(await healthService.getProtocolReference());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
