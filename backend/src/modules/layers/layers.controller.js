import * as layersService from "./layers.service.js";
import * as layersReports from "./layers.reports.service.js";
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

//////////////////////////////////////////////////////
// 📊 LAYERS REPORTS — analytics dashboard
//////////////////////////////////////////////////////

// GET /api/layers/reports/production
// Query params: houseId · period · startDate · endDate
// Returns period-scoped totals + previous-period delta + daily
// graph buckets + per-house breakdown. Separate path from /trend
// and /kpis so the legacy today + 7-day widgets stay untouched.
export const getProductionReport = async (req, res) => {
  try {
    const report = await layersReports.getProductionReport({
      houseId: req.query.houseId,
      period: req.query.period,
      startDate: req.query.startDate,
      endDate: req.query.endDate,
    });
    res.json(report);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};
