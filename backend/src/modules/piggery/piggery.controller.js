import * as piggeryService from "./piggery.service.js";
import {
  createPigSchema,
  updatePigSchema,
  farrowingSchema,
  trendQuerySchema,
  sowSearchSchema,
  farrowingQuerySchema,
} from "./piggery.validation.js";

const handleZodError = (res, err) => {
  if (err?.issues) {
    return res.status(400).json({
      error: "Validation error",
      issues: err.issues.map((i) => ({ path: i.path, message: i.message })),
    });
  }
  return null;
};

export const getKpis = async (_req, res) => {
  try {
    res.json(await piggeryService.getKpis());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const listHouses = async (_req, res) => {
  try {
    res.json(await piggeryService.listHouses());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const listSows = async (req, res) => {
  try {
    const query = sowSearchSchema.parse(req.query);
    res.json(await piggeryService.listSows(query));
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(500).json({ error: err.message });
  }
};

export const listBoars = async (_req, res) => {
  try {
    res.json(await piggeryService.listBoars());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const listLitters = async (_req, res) => {
  try {
    res.json(await piggeryService.listLitters());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const listNursery = async (_req, res) => {
  try {
    res.json(await piggeryService.listNursery());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const listFattening = async (_req, res) => {
  try {
    res.json(await piggeryService.listFattening());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const listFinishing = async (_req, res) => {
  try {
    res.json(await piggeryService.listFinishing());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const listFarrowing = async (req, res) => {
  try {
    const query = farrowingQuerySchema.parse(req.query);
    res.json(await piggeryService.listFarrowing(query));
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(500).json({ error: err.message });
  }
};

export const getTrend = async (req, res) => {
  try {
    const query = trendQuerySchema.parse(req.query);
    res.json(await piggeryService.getTrend(query));
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(500).json({ error: err.message });
  }
};

export const createPig = async (req, res) => {
  try {
    const body = createPigSchema.parse(req.body);
    const pig = await piggeryService.createPig(body);
    res.status(201).json(pig);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(400).json({ error: err.message });
  }
};

export const logFarrowing = async (req, res) => {
  try {
    const body = farrowingSchema.parse(req.body);
    const record = await piggeryService.logFarrowing(body);
    res.status(201).json(record);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(400).json({ error: err.message });
  }
};

export const updatePig = async (req, res) => {
  try {
    const patch = updatePigSchema.parse(req.body);
    const pig = await piggeryService.updatePig(req.params.id, patch);
    res.json(pig);
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "Pig not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

export const softDeletePig = async (req, res) => {
  try {
    await piggeryService.softDeletePig(req.params.id);
    res.status(204).end();
  } catch (err) {
    if (err.message === "Pig not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(500).json({ error: err.message });
  }
};

// ===== Litter / Nursery / Pen CRUD =====

const reqStr = (v, msg) => {
  if (typeof v !== "string" || v.trim().length === 0) throw new Error(msg);
  return v.trim();
};
const reqInt = (v, msg, { min = 0, max = 1000 } = {}) => {
  const n = typeof v === "number" ? v : Number(v);
  if (!Number.isInteger(n) || n < min || n > max) throw new Error(msg);
  return n;
};
const optDate = (v) => {
  if (v === undefined || v === null || v === "") return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
};
const optStr = (v) => {
  if (v === undefined || v === null) return null;
  const s = String(v).trim();
  return s.length === 0 ? null : s;
};

export const createLitter = async (req, res) => {
  try {
    const body = req.body ?? {};
    const litterId = reqStr(body.litterId, "litterId is required");
    const sowId = reqStr(body.sowId, "sowId is required");
    const count = reqInt(body.count ?? 0, "count must be 0..30", { max: 30 });
    const row = await piggeryService.createLitter({
      litterId,
      sowId,
      born: optDate(body.born),
      count,
      note: optStr(body.note),
    });
    res.status(201).json(row);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

export const updateLitter = async (req, res) => {
  try {
    const body = req.body ?? {};
    const patch = {};
    if (body.litterId !== undefined) patch.litterId = reqStr(body.litterId, "litterId invalid");
    if (body.sowId !== undefined) patch.sowId = reqStr(body.sowId, "sowId invalid");
    if (body.born !== undefined) patch.born = optDate(body.born);
    if (body.count !== undefined) patch.count = reqInt(body.count, "count 0..30", { max: 30 });
    if (body.note !== undefined) patch.note = optStr(body.note);
    const row = await piggeryService.updateLitter(req.params.id, patch);
    res.json(row);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

export const deleteLitter = async (req, res) => {
  try {
    await piggeryService.softDeleteLitter(req.params.id);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const createNursery = async (req, res) => {
  try {
    const body = req.body ?? {};
    const pen = reqStr(body.pen, "pen is required");
    const count = reqInt(body.count ?? 0, "count must be 0..500", { max: 500 });
    const row = await piggeryService.createNurseryGroup({
      pen,
      count,
      age: optStr(body.age),
      born: optDate(body.born),
      breed: optStr(body.breed),
      note: optStr(body.note),
    });
    res.status(201).json(row);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

export const updateNursery = async (req, res) => {
  try {
    const body = req.body ?? {};
    const patch = {};
    if (body.pen !== undefined) patch.pen = reqStr(body.pen, "pen invalid");
    if (body.count !== undefined) patch.count = reqInt(body.count, "count 0..500", { max: 500 });
    if (body.age !== undefined) patch.age = optStr(body.age);
    if (body.born !== undefined) patch.born = optDate(body.born);
    if (body.breed !== undefined) patch.breed = optStr(body.breed);
    if (body.note !== undefined) patch.note = optStr(body.note);
    const row = await piggeryService.updateNurseryGroup(req.params.id, patch);
    res.json(row);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

export const deleteNursery = async (req, res) => {
  try {
    await piggeryService.softDeleteNurseryGroup(req.params.id);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const createPen = async (req, res) => {
  try {
    const body = req.body ?? {};
    const pen = reqStr(body.pen, "pen is required");
    const house = reqStr(body.house, "house is required");
    if (!["E", "F"].includes(house)) {
      return res.status(400).json({ error: "house must be 'E' or 'F'" });
    }
    const count = reqInt(body.count ?? 0, "count must be 0..200", { max: 200 });
    const row = await piggeryService.createFattenPen({
      pen,
      house,
      count,
      age: optStr(body.age),
      saleReady: body.saleReady === true,
      saleWindow: optStr(body.saleWindow),
    });
    res.status(201).json(row);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

export const updatePen = async (req, res) => {
  try {
    const body = req.body ?? {};
    const patch = {};
    if (body.pen !== undefined) patch.pen = reqStr(body.pen, "pen invalid");
    if (body.house !== undefined) {
      patch.house = reqStr(body.house, "house invalid");
      if (!["E", "F"].includes(patch.house)) {
        return res.status(400).json({ error: "house must be 'E' or 'F'" });
      }
    }
    if (body.count !== undefined) patch.count = reqInt(body.count, "count 0..200", { max: 200 });
    if (body.age !== undefined) patch.age = optStr(body.age);
    if (body.saleReady !== undefined) patch.saleReady = body.saleReady === true;
    if (body.saleWindow !== undefined) patch.saleWindow = optStr(body.saleWindow);
    const row = await piggeryService.updateFattenPen(req.params.id, patch);
    res.json(row);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

export const deletePen = async (req, res) => {
  try {
    await piggeryService.softDeleteFattenPen(req.params.id);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ===== Inventory =====

export const listInventory = async (_req, res) => {
  try {
    res.json(await piggeryService.listPiggeryInventory());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const createInventory = async (req, res) => {
  try {
    const body = req.body ?? {};
    if (!body.name || typeof body.name !== "string") {
      return res.status(400).json({ error: "name is required" });
    }
    if (!body.category) {
      return res.status(400).json({ error: "category is required" });
    }
    if (typeof body.quantity !== "number" || body.quantity < 0) {
      return res.status(400).json({ error: "quantity must be >= 0" });
    }
    const row = await piggeryService.createPiggeryInventoryItem(body);
    res.status(201).json(row);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const updateInventory = async (req, res) => {
  try {
    const row = await piggeryService.updatePiggeryInventoryItem(
      req.params.id,
      req.body ?? {},
    );
    res.json(row);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const deleteInventory = async (req, res) => {
  try {
    await piggeryService.softDeletePiggeryInventoryItem(req.params.id);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
