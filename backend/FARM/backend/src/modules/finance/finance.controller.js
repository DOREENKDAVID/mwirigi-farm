import * as service from "./finance.service.js";
import { revenueSchema, expenseSchema } from "./finance.validation.js";

export const dashboard = async (req, res) => {
  try {
    const month = req.query.month ? Number(req.query.month) : undefined;
    const year = req.query.year ? Number(req.query.year) : undefined;
    const data = await service.getDashboard({ month, year });
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const parseListQuery = (req) => ({
  unit: req.query.unit ?? undefined,
  category: req.query.category ?? undefined,
  approved: req.query.approved == null
    ? undefined
    : req.query.approved === "true",
  from: req.query.from ?? undefined,
  to: req.query.to ?? undefined,
  page: req.query.page ? Number(req.query.page) : 1,
  limit: req.query.limit ? Math.min(200, Number(req.query.limit)) : 50,
});

export const listRevenue = async (req, res) => {
  try {
    res.json(await service.listRevenue(parseListQuery(req)));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const createRevenue = async (req, res) => {
  try {
    const validated = revenueSchema.parse(req.body);
    const row = await service.createRevenue(validated, req.user?.id);
    res.status(201).json(row);
  } catch (err) {
    res.status(400).json({ error: err.errors || err.message });
  }
};

export const listExpenses = async (req, res) => {
  try {
    res.json(await service.listExpenses(parseListQuery(req)));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const createExpense = async (req, res) => {
  try {
    const validated = expenseSchema.parse(req.body);
    const row = await service.createExpense(validated, req.user?.id);
    res.status(201).json(row);
  } catch (err) {
    res.status(400).json({ error: err.errors || err.message });
  }
};
