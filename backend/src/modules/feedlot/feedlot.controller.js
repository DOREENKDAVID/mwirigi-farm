import * as feedlotService from "./feedlot.service.js";
import {
  createBullSchema,
  updateBullSchema,
  createWeightSchema,
  createSheepSchema,
  updateSheepSchema,
  lambingSchema,
  lambingQuerySchema,
} from "./feedlot.validation.js";

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
    res.json(await feedlotService.getKpis());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const listBulls = async (_req, res) => {
  try {
    res.json(await feedlotService.listBulls());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const createBull = async (req, res) => {
  try {
    const body = createBullSchema.parse(req.body);
    const bull = await feedlotService.createBull(body);
    res.status(201).json(bull);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(400).json({ error: err.message });
  }
};

export const logWeight = async (req, res) => {
  try {
    const body = createWeightSchema.parse(req.body);
    const bull = await feedlotService.logWeight(body);
    res.status(201).json(bull);
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "Bull not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

export const updateBull = async (req, res) => {
  try {
    const patch = updateBullSchema.parse(req.body);
    const bull = await feedlotService.updateBull(req.params.id, patch);
    res.json(bull);
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "Bull not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

export const deleteBull = async (req, res) => {
  try {
    await feedlotService.softDeleteBull(req.params.id);
    res.status(204).end();
  } catch (err) {
    if (err.message === "Bull not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(500).json({ error: err.message });
  }
};

export const createSheep = async (req, res) => {
  try {
    const body = createSheepSchema.parse(req.body);
    const result = await feedlotService.createSheep(body);
    res.status(201).json(result);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(400).json({ error: err.message });
  }
};

export const listSheep = async (_req, res) => {
  try {
    res.json(await feedlotService.listSheep());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const updateSheep = async (req, res) => {
  try {
    const patch = updateSheepSchema.parse(req.body);
    const sheep = await feedlotService.updateSheep(req.params.id, patch);
    res.json(sheep);
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "Sheep not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

export const deleteSheep = async (req, res) => {
  try {
    await feedlotService.softDeleteSheep(req.params.id);
    res.status(204).end();
  } catch (err) {
    if (err.message === "Sheep not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(500).json({ error: err.message });
  }
};

export const logLambing = async (req, res) => {
  try {
    const body = lambingSchema.parse(req.body);
    const record = await feedlotService.logLambing(body);
    res.status(201).json(record);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(400).json({ error: err.message });
  }
};

export const listLambing = async (req, res) => {
  try {
    const query = lambingQuerySchema.parse(req.query);
    res.json(await feedlotService.listLambing(query));
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(500).json({ error: err.message });
  }
};

// ===== Inventory =====

export const listInventory = async (_req, res) => {
  try {
    res.json(await feedlotService.listFeedlotInventory());
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
    const row = await feedlotService.createFeedlotInventoryItem(body);
    res.status(201).json(row);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const updateInventory = async (req, res) => {
  try {
    const row = await feedlotService.updateFeedlotInventoryItem(
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
    await feedlotService.softDeleteFeedlotInventoryItem(req.params.id);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
