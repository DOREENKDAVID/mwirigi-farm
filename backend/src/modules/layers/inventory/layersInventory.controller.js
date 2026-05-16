import * as service from "./layersInventory.service.js";
import { itemSchema, itemPatchSchema } from "./layersInventory.validation.js";

export const list = async (_req, res) => {
  try {
    res.json(await service.listInventory());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const summary = async (_req, res) => {
  try {
    res.json(await service.getSummary());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const create = async (req, res) => {
  try {
    const validated = itemSchema.parse(req.body);
    res.status(201).json(await service.createItem(validated));
  } catch (err) {
    res.status(400).json({ error: err.errors || err.message });
  }
};

export const update = async (req, res) => {
  try {
    const validated = itemPatchSchema.parse(req.body);
    res.json(await service.updateItem(req.params.id, validated));
  } catch (err) {
    res.status(400).json({ error: err.errors || err.message });
  }
};

export const softDelete = async (req, res) => {
  try {
    await service.softDeleteItem(req.params.id);
    res.json({ success: true, message: "Inventory item deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
