import * as reproductionService from "./reproduction.service.js";
import {
  createReproductionSchema,
  updateReproductionSchema,
  listQuerySchema,
  confirmPregnancySchema,
} from "./reproduction.validation.js";

const handleZodError = (res, err) => {
  if (err?.issues) {
    return res.status(400).json({
      error: "Validation error",
      issues: err.issues.map((i) => ({ path: i.path, message: i.message })),
    });
  }
  return null;
};

export const list = async (req, res) => {
  try {
    const query = listQuerySchema.parse(req.query);
    const data = await reproductionService.listReproductionRows(query);
    res.json(data);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(500).json({ error: err.message });
  }
};

export const create = async (req, res) => {
  try {
    const body = createReproductionSchema.parse(req.body);
    const record = await reproductionService.createReproductionRecord(body);
    res.status(201).json(record);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(400).json({ error: err.message });
  }
};

export const getHistory = async (req, res) => {
  try {
    const data = await reproductionService.getHistoryForCow(req.params.cowId);
    res.json(data);
  } catch (err) {
    res.status(404).json({ error: err.message });
  }
};

export const update = async (req, res) => {
  try {
    const patch = updateReproductionSchema.parse(req.body);
    const record = await reproductionService.updateReproductionRecord(
      req.params.id,
      patch,
    );
    res.json(record);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(400).json({ error: err.message });
  }
};

export const confirmPregnancy = async (req, res) => {
  try {
    const body = confirmPregnancySchema.parse(req.body);
    const record = await reproductionService.confirmMostRecentAi(body);
    res.json(record);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(400).json({ error: err.message });
  }
};

export const softDelete = async (req, res) => {
  try {
    await reproductionService.softDeleteReproductionRecord(req.params.id);
    res.status(204).end();
  } catch (err) {
    res.status(404).json({ error: err.message });
  }
};
