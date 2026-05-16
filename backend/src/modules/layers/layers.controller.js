import * as layersService from "./layers.service.js";
import {
  dailyEntrySchema,
  daysQuerySchema,
} from "./layers.validation.js";

const handleZodError = (res, err) => {
  if (err?.issues) {
    return res.status(400).json({
      error: "Validation error",
      issues: err.issues.map((i) => ({ path: i.path, message: i.message })),
    });
  }
  return null;
};

export const getHouses = async (_req, res) => {
  try {
    res.json(await layersService.listHouses());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const getProductionForHouse = async (req, res) => {
  try {
    const query = daysQuerySchema.parse(req.query);
    const data = await layersService.getProductionForHouse(
      req.params.houseId,
      query,
    );
    res.json(data);
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "House not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(500).json({ error: err.message });
  }
};

export const createDailyEntry = async (req, res) => {
  try {
    const body = dailyEntrySchema.parse(req.body);
    const record = await layersService.upsertDailyEntry(body);
    res.status(201).json(record);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(400).json({ error: err.message });
  }
};

export const getSnapshot = async (_req, res) => {
  try {
    res.json(await layersService.getSnapshot());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const getTrend = async (req, res) => {
  try {
    const query = daysQuerySchema.parse(req.query);
    res.json(await layersService.getTrend(query));
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(500).json({ error: err.message });
  }
};

export const getKpis = async (_req, res) => {
  try {
    res.json(await layersService.getKpis());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
