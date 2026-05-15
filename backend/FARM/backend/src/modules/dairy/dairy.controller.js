import * as dairyService from "./dairy.service.js";
import {
  cowSchema,
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

export const getTodaySessions = async (req, res) => {
  try {
    const threshold = req.query.threshold
      ? Number(req.query.threshold)
      : undefined;
    const data = await dairyService.getTodaySessions(
      threshold && threshold > 0 && threshold <= 1
        ? { belowAvgThreshold: threshold }
        : {},
    );
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const getTodayNetSummary = async (_req, res) => {
  try {
    const data = await dairyService.getTodayNetSummary();
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const submitMilkSession = async (req, res) => {
  try {
    const { workerId, session, date, entries } = req.body ?? {};
    if (!session || !["AM", "MID", "PM"].includes(session)) {
      return res
        .status(400)
        .json({ error: "session must be one of AM, MID, PM" });
    }
    if (!Array.isArray(entries) || entries.length === 0) {
      return res
        .status(400)
        .json({ error: "entries must be a non-empty array" });
    }
    await dairyService.submitMilkSession({
      workerId: workerId ?? null,
      session,
      date: date ? new Date(date) : new Date(),
      entries,
      userId: req.user?.id ?? null,
    });
    // Return the refreshed today-view so the UI can update without a
    // round-trip.
    const todaySessions = await dairyService.getTodaySessions();
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