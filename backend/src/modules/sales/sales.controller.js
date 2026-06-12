import * as salesService from "./sales.service.js";
import {
  createSaleSchema,
  updateSaleSchema,
  listSalesSchema,
} from "./sales.validation.js";

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
    const query = listSalesSchema.parse(req.query);
    const result = await salesService.listSales(query);
    res.json(result);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(500).json({ error: err.message });
  }
};

export const create = async (req, res) => {
  try {
    const body = createSaleSchema.parse(req.body);
    const actorId = req.user?.id ?? null;
    const sale = await salesService.createSale(body, actorId);
    res.status(201).json(sale);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(400).json({ error: err.message });
  }
};

export const update = async (req, res) => {
  try {
    const patch = updateSaleSchema.parse(req.body);
    const actorId = req.user?.id ?? null;
    const updated = await salesService.updateSale(req.params.id, patch, actorId);
    res.json(updated);
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "Sale not found") return res.status(404).json({ error: err.message });
    res.status(400).json({ error: err.message });
  }
};

export const remove = async (req, res) => {
  try {
    const actorId = req.user?.id ?? null;
    await salesService.deleteSale(req.params.id, actorId);
    res.status(204).end();
  } catch (err) {
    if (err.message === "Sale not found") return res.status(404).json({ error: err.message });
    res.status(500).json({ error: err.message });
  }
};

export const summary = async (req, res) => {
  try {
    const module = req.query.module?.toUpperCase();
    if (!module || !["DAIRY", "LAYERS"].includes(module)) {
      return res.status(400).json({ error: "module must be DAIRY or LAYERS" });
    }
    const data = await salesService.getSalesSummary(module);
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
