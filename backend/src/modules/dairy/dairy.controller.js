import * as dairyService from "./dairy.service.js";
import * as dairyReportsService from "./dairy.reports.service.js";
import {
  cowSchema,
  releaseCowSchema,
  calfDispositionSchema,
  milkRecordSchema,
  dairyInventorySchema,
  dairyInventoryPatchSchema,
} from "./dairy.validation.js";

//////////////////////////////////////////////////////
// 🐄 COW CONTROLLERS
//////////////////////////////////////////////////////

export const createCow = async (req, res) => {
  try {
    const validatedData = cowSchema.parse(req.body);

    const cow = await dairyService.createCow(validatedData);

    res.status(201).json(cow);
  } catch (error) {
    res.status(400).json({
      error: error.errors || error.message,
    });
  }
};

export const getAllCows = async (req, res) => {
  try {
    // Workers + Houses pills compose with AND. `unassigned` is a
    // sentinel value for cows missing the relation so the UI can
    // surface them like the HTML's "⚠ Unassigned" pill.
    const cows = await dairyService.getAllCows({
      workerId: typeof req.query.workerId === "string" ? req.query.workerId : undefined,
      houseId:  typeof req.query.houseId  === "string" ? req.query.houseId  : undefined,
      search:   typeof req.query.search   === "string" ? req.query.search   : undefined,
    });
    res.json(cows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

export const getCowByTag = async (req, res) => {
  try {
    const cow = await dairyService.getCowByTag(req.params.tag);

    if (!cow) {
      return res.status(404).json({ message: "Cow not found" });
    }

    res.json(cow);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

export const updateCow = async (req, res) => {
  try {
    const cow = await dairyService.updateCow(req.params.tag, req.body);
    res.json(cow);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

export const deleteCow = async (req, res) => {
  try {
    await dairyService.deleteCow(req.params.tag);
    res.json({ message: "Cow deleted successfully" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

export const releaseCow = async (req, res) => {
  try {
    const body = releaseCowSchema.parse(req.body);
    const cow = await dairyService.releaseCow(
      req.params.tag,
      body,
      req.user?.id,
    );
    res.json(cow);
  } catch (err) {
    if (err?.issues) {
      return res.status(400).json({
        error: "Validation error",
        issues: err.issues.map((i) => ({ path: i.path, message: i.message })),
      });
    }
    if (err.message === "Cow not found") {
      return res.status(404).json({ error: err.message });
    }
    if (err.message === "Cow is already released") {
      return res.status(409).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

//////////////////////////////////////////////////////
// 🥛 MILK RECORD CONTROLLERS
//////////////////////////////////////////////////////

export const createMilkRecord = async (req, res) => {
  try {
    const validatedData = milkRecordSchema.parse(req.body);

    const record = await dairyService.createMilkRecord({
      ...validatedData,
      userId: req.user.id,
    });

    res.status(201).json(record);
  } catch (error) {
    res.status(400).json({
      error: error.errors || error.message,
    });
  }
};

export const getMilkRecords = async (req, res) => {
  try {
    const records = await dairyService.getMilkRecords();
    res.json(records);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

export const getMilkRecordsByCow = async (req, res) => {
  try {
    const records = await dairyService.getMilkRecordsByCow(
      req.params.cowId
    );
    res.json(records);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

export const deleteMilkRecord = async (req, res) => {
  try {
    await dairyService.deleteMilkRecord(req.params.id);
    res.json({ message: "Milk record deleted successfully" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

//////////////////////////////////////////////////////
// 📊 DASHBOARD CONTROLLERS
//////////////////////////////////////////////////////

export const getDairyDashboard = async (_req, res) => {
  try {
    const data = await dairyService.getDashboard();
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Compact KPI card payload — used by the Flutter dairy summary cards.
export const getDairySummary = async (_req, res) => {
  try {
    const data = await dairyService.getSummary();
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

//////////////////////////////////////////////////////
// 👷 WORKER CONTROLLERS
//////////////////////////////////////////////////////

export const getWorkers = async (_req, res) => {
  try {
    const workers = await dairyService.getDairyWorkers();
    res.json(workers);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const getCowsByWorker = async (req, res) => {
  try {
    const cows = await dairyService.getCowsByWorkerId(req.params.workerId);
    res.json(cows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const reassignWorkerCows = async (req, res) => {
  try {
    const fromWorkerId = req.params.workerId;
    const toWorkerId = (req.body ?? {}).toWorkerId;
    if (typeof toWorkerId !== "string" || !toWorkerId) {
      return res
        .status(400)
        .json({ error: "toWorkerId is required in the request body" });
    }
    const count = await dairyService.reassignWorkerCows(
      fromWorkerId,
      toWorkerId,
      req.user?.id,
    );
    res.json({ reassigned: count });
  } catch (err) {
    const msg = err.message ?? "Reassignment failed";
    if (
      msg === "Source worker not found" ||
      msg === "Replacement worker not found"
    ) {
      return res.status(404).json({ error: msg });
    }
    if (
      msg === "Cannot reassign cows to the same worker" ||
      msg === "Both fromWorkerId and toWorkerId are required"
    ) {
      return res.status(400).json({ error: msg });
    }
    res.status(500).json({ error: msg });
  }
};

//////////////////////////////////////////////////////
// PHASE 2 + 3 — aggregations & bulk submit
//////////////////////////////////////////////////////

export const getHousesOverview = async (_req, res) => {
  try {
    const data = await dairyService.getHousesOverview();
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Optional `date` query param (ISO string). Used by the historical-
// session mode in the milk panel — when set, the response scopes to
// that calendar day instead of "today". Rejects future dates so a
// stale picker can't surface entries for a day that hasn't happened.
const parseSessionDate = (raw) => {
  if (!raw) return undefined;
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return undefined;
  // Snap to end-of-day so today (which has all 24h available) doesn't
  // get rejected by the "future" guard against the current instant.
  const dayEnd = new Date(d);
  dayEnd.setHours(23, 59, 59, 999);
  if (dayEnd > new Date()) return undefined;
  return d;
};

export const getTodaySessions = async (req, res) => {
  try {
    const threshold = req.query.threshold
      ? Number(req.query.threshold)
      : undefined;
    const date = parseSessionDate(req.query.date);
    const data = await dairyService.getTodaySessions({
      ...(threshold && threshold > 0 && threshold <= 1
        ? { belowAvgThreshold: threshold }
        : {}),
      ...(date ? { date } : {}),
    });
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const getTodayNetSummary = async (req, res) => {
  try {
    const date = parseSessionDate(req.query.date);
    const data = await dairyService.getTodayNetSummary(
      date ? { date } : {},
    );
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const updateMilkDeductions = async (req, res) => {
  try {
    const body = req.body ?? {};
    const num = (v) =>
      v === null || v === undefined ? undefined : Number(v);
    const calf = num(body.calfDeduction);
    const house = num(body.householdDeduct);
    if (
      (calf !== undefined && (Number.isNaN(calf) || calf < 0 || calf > 1000)) ||
      (house !== undefined &&
        (Number.isNaN(house) || house < 0 || house > 1000))
    ) {
      return res.status(400).json({
        error: "Deduction values must be numbers between 0 and 1000 litres",
      });
    }
    const row = await dairyService.updateMilkDeductions({
      calfDeduction: calf,
      householdDeduct: house,
    });
    res.json({
      calfDeduction: row.calfDeduction,
      householdDeduct: row.householdDeduct,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const submitMilkSession = async (req, res) => {
  try {
    const { workerId, session, date, entries } = req.body ?? {};
    if (!session || !["DAWN", "AM", "MID", "PM"].includes(session)) {
      return res
        .status(400)
        .json({ error: "session must be one of DAWN, AM, MID, PM" });
    }
    if (!Array.isArray(entries) || entries.length === 0) {
      return res
        .status(400)
        .json({ error: "entries must be a non-empty array" });
    }
    const writeDate = date ? new Date(date) : new Date();
    await dairyService.submitMilkSession({
      workerId: workerId ?? null,
      session,
      date: writeDate,
      entries,
      userId: req.user?.id ?? null,
    });
    // Return the refreshed view scoped to the *same date* we just
    // wrote against — historical mode submits expect their own day's
    // snapshot back, not today's.
    const todaySessions = await dairyService.getTodaySessions({
      date: writeDate,
    });
    res.status(201).json({
      success: true,
      message: "Milk session saved",
      data: todaySessions,
    });
  } catch (err) {
    if (err.message?.startsWith("Cow not found")) {
      return res.status(404).json({ error: err.message });
    }
    if (err.message?.includes("not assigned to this worker")) {
      return res.status(400).json({ error: err.message });
    }
    res.status(500).json({ error: err.message });
  }
};

//////////////////////////////////////////////////////
// 📈 DAILY MILK — 7-DAY TREND
//////////////////////////////////////////////////////

export const getDailyMilkTrend = async (req, res) => {
  try {
    const days = Math.max(
      1,
      Math.min(31, Number.parseInt(req.query.days ?? '7', 10) || 7),
    );
    const data = await dairyService.getDailyMilkTrend({ days });
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

//////////////////////////////////////////////////////
// 🐮 CALVES REGISTER
//////////////////////////////////////////////////////

export const getCalvesRegister = async (_req, res) => {
  try {
    const data = await dairyService.getCalvesRegister();
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const disposeCalf = async (req, res) => {
  try {
    const body = calfDispositionSchema.parse(req.body);
    const updated = await dairyService.disposeCalf(
      req.params.id,
      body,
      req.user?.id,
    );
    res.json(updated);
  } catch (err) {
    if (err?.issues) {
      return res.status(400).json({
        error: "Validation error",
        issues: err.issues.map((i) => ({ path: i.path, message: i.message })),
      });
    }
    if (err.message === "Calf record not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

//////////////////////////////////////////////////////
// 📦 DAIRY INVENTORY
//////////////////////////////////////////////////////

export const getDairyInventory = async (_req, res) => {
  try {
    const data = await dairyService.getDairyInventory();
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const createDairyInventoryItem = async (req, res) => {
  try {
    const validated = dairyInventorySchema.parse(req.body);
    const item = await dairyService.createDairyInventoryItem(validated);
    res.status(201).json(item);
  } catch (err) {
    res.status(400).json({ error: err.errors || err.message });
  }
};

export const updateDairyInventoryItem = async (req, res) => {
  try {
    const validated = dairyInventoryPatchSchema.parse(req.body);
    const item = await dairyService.updateDairyInventoryItem(
      req.params.id,
      validated,
    );
    res.json(item);
  } catch (err) {
    res.status(400).json({ error: err.errors || err.message });
  }
};

export const deleteDairyInventoryItem = async (req, res) => {
  try {
    await dairyService.softDeleteDairyInventoryItem(req.params.id);
    res.json({ success: true, message: "Inventory item deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

//////////////////////////////////////////////////////
// 📊 DAIRY REPORTS — analytics dashboard
//////////////////////////////////////////////////////

// Pulls the milk production report. Query params:
//   animalId, houseId, workerId,
//   period   = today | week | month | quarter | halfyear | annual | custom,
//   startDate, endDate (required when period=custom)
//
// RBAC layer on top of the route's authMiddleware: a WORKER may only
// see their own production — we force-override workerId to their JWT
// id, so a worker can't grab another worker's numbers by passing a
// different query param. Everyone else (CEO, ADMIN, DAIRY_MANAGER,
// VET) sees the full payload subject to whatever filters they pass.
const scopeFiltersForUser = (user, raw) => {
  const out = { ...raw };
  if (user?.role === "WORKER") {
    // Workers in this codebase are User rows (not Worker rows directly,
    // though the seed mirrors them). The JWT carries `user.id`; we
    // resolve a matching Worker row at the service layer if needed.
    out.workerId = user.workerId ?? user.id ?? out.workerId;
  }
  return out;
};

// Pulls the standard filter set off the request and applies WORKER
// scoping. Centralised so every report controller is one line.
const readFilters = (req) =>
  scopeFiltersForUser(req.user, {
    animalId: req.query.animalId,
    houseId: req.query.houseId,
    workerId: req.query.workerId,
    period: req.query.period,
    startDate: req.query.startDate,
    endDate: req.query.endDate,
  });

export const getMilkProductionReport = async (req, res) => {
  try {
    const report = await dairyReportsService.getMilkProductionReport(
      readFilters(req),
    );
    res.json(report);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

export const getReproductionReport = async (req, res) => {
  try {
    const report = await dairyReportsService.getReproductionReport(
      readFilters(req),
    );
    res.json(report);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

export const getHealthReport = async (req, res) => {
  try {
    const report = await dairyReportsService.getHealthReport(
      readFilters(req),
    );
    res.json(report);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

export const getVaccinationReport = async (req, res) => {
  try {
    const report = await dairyReportsService.getVaccinationReport(
      readFilters(req),
    );
    res.json(report);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};