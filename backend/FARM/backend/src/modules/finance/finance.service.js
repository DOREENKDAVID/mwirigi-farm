// Finance module — CEO-level consolidated financial dashboard.
//
// v1 endpoints:
//   getDashboard()        → KPI strip + revenue-by-unit + per-unit P&L
//   listRevenue({...})    → paginated revenue rows
//   createRevenue(input)
//   listExpenses({...})   → paginated expense rows
//   createExpense(input)
//
// Auto-pulling from Dairy / Layers / Piggery transactions is a
// follow-up — once those modules emit a "transaction recorded" event
// we'll mirror them into the Revenue / Expense tables here so the
// dashboard stays live without manual entry.

import prisma from "../../prisma/client.js";

// Each FinanceUnit gets a stable accent colour (matches the v4.2 HTML
// mockup's revenue-by-unit donut). Frontend uses these directly.
const UNIT_COLORS = {
  Dairy:    "#3B6D11",
  Layers:   "#1D9E75",
  Piggery:  "#EF9F27",
  Ngushish: "#639922",
  Feedlot:  "#854F0B",
  Doopers:  "#A8743C",
  Other:    "#6B7770",
};

const monthBoundsFor = (date) => {
  const d = date ?? new Date();
  const start = new Date(d.getFullYear(), d.getMonth(), 1);
  const end = new Date(d.getFullYear(), d.getMonth() + 1, 1);
  return { start, end };
};

// =====================================================================
// Dashboard — what the FinancePage Overview pill renders
// =====================================================================
//
// Returns:
//   {
//     period: { month, year, label },
//     kpis:   { revenue, expenses, netProfit, marginPct, bestUnit },
//     revenueByUnit: [{ unit, color, amount, pct }],
//     pnl:           [{ unit, color, revenue, expenses, profit, marginPct }],
//   }
//
// All amounts are in KSh.

export const getDashboard = async ({ month, year } = {}) => {
  const ref =
    month != null && year != null
      ? new Date(year, month - 1, 1)
      : new Date();
  const { start, end } = monthBoundsFor(ref);

  const [revenueByUnit, expensesByUnit] = await Promise.all([
    prisma.revenue.groupBy({
      by: ["unit"],
      where: { date: { gte: start, lt: end } },
      _sum: { amount: true },
    }),
    prisma.expense.groupBy({
      by: ["unit"],
      where: { date: { gte: start, lt: end }, approved: true },
      _sum: { amount: true },
    }),
  ]);

  // Build a unified per-unit P&L map. Use FinanceUnit enum as the canonical
  // ordering so units that have only expenses (or only revenue) still
  // appear in the table.
  const unitOrder = [
    "Dairy", "Layers", "Piggery", "Ngushish", "Feedlot", "Doopers", "Other",
  ];
  const map = new Map(
    unitOrder.map((u) => [u, { unit: u, color: UNIT_COLORS[u], revenue: 0, expenses: 0 }]),
  );
  for (const r of revenueByUnit) {
    const slot = map.get(r.unit) ?? {
      unit: r.unit, color: UNIT_COLORS[r.unit] ?? UNIT_COLORS.Other,
      revenue: 0, expenses: 0,
    };
    slot.revenue = r._sum.amount ?? 0;
    map.set(r.unit, slot);
  }
  for (const e of expensesByUnit) {
    const slot = map.get(e.unit) ?? {
      unit: e.unit, color: UNIT_COLORS[e.unit] ?? UNIT_COLORS.Other,
      revenue: 0, expenses: 0,
    };
    slot.expenses = e._sum.amount ?? 0;
    map.set(e.unit, slot);
  }

  const pnl = [];
  let totalRevenue = 0;
  let totalExpenses = 0;
  for (const slot of map.values()) {
    if (slot.revenue === 0 && slot.expenses === 0) continue;
    const profit = slot.revenue - slot.expenses;
    const marginPct =
      slot.revenue > 0 ? Number(((profit / slot.revenue) * 100).toFixed(1)) : 0;
    pnl.push({
      unit: slot.unit,
      color: slot.color,
      revenue: Number(slot.revenue.toFixed(2)),
      expenses: Number(slot.expenses.toFixed(2)),
      profit: Number(profit.toFixed(2)),
      marginPct,
    });
    totalRevenue += slot.revenue;
    totalExpenses += slot.expenses;
  }

  // Revenue-by-unit slice for the donut chart. Sorted by amount desc so
  // legends read top-to-bottom.
  const rbuRaw = pnl
    .filter((r) => r.revenue > 0)
    .map((r) => ({ unit: r.unit, color: r.color, amount: r.revenue }))
    .sort((a, b) => b.amount - a.amount);
  const revenueByUnitOut = rbuRaw.map((r) => ({
    ...r,
    pct: totalRevenue > 0 ? Number(((r.amount / totalRevenue) * 100).toFixed(1)) : 0,
  }));

  // Best unit = highest profit (positive). When none are profitable,
  // surface the highest-revenue one as a fallback.
  const profitable = pnl.filter((r) => r.profit > 0);
  const sortedByProfit = profitable.sort((a, b) => b.profit - a.profit);
  const sortedByRevenue = [...pnl].sort((a, b) => b.revenue - a.revenue);
  const best = sortedByProfit[0] ?? sortedByRevenue[0] ?? null;
  const bestUnit = best
    ? {
        unit: best.unit,
        revenuePct:
          totalRevenue > 0
            ? Number(((best.revenue / totalRevenue) * 100).toFixed(1))
            : 0,
      }
    : null;

  const netProfit = totalRevenue - totalExpenses;
  const marginPct =
    totalRevenue > 0 ? Number(((netProfit / totalRevenue) * 100).toFixed(1)) : 0;

  const monthName = ref.toLocaleDateString("en-KE", {
    month: "long",
    year: "numeric",
  });

  return {
    period: {
      month: ref.getMonth() + 1,
      year: ref.getFullYear(),
      label: monthName,
    },
    kpis: {
      revenue: Number(totalRevenue.toFixed(2)),
      expenses: Number(totalExpenses.toFixed(2)),
      netProfit: Number(netProfit.toFixed(2)),
      marginPct,
      bestUnit,
    },
    revenueByUnit: revenueByUnitOut,
    pnl,
  };
};

// =====================================================================
// Revenue CRUD
// =====================================================================

export const listRevenue = async ({
  unit,
  category,
  from,
  to,
  page = 1,
  limit = 50,
} = {}) => {
  const where = {};
  if (unit) where.unit = unit;
  if (category) where.category = category;
  if (from || to) {
    where.date = {};
    if (from) where.date.gte = new Date(from);
    if (to) where.date.lte = new Date(to);
  }
  const [rows, total] = await Promise.all([
    prisma.revenue.findMany({
      where,
      orderBy: { date: "desc" },
      skip: (page - 1) * limit,
      take: limit,
    }),
    prisma.revenue.count({ where }),
  ]);
  return { rows, total, page, limit };
};

export const createRevenue = async (input, userId) => {
  return prisma.revenue.create({
    data: {
      unit: input.unit,
      category: input.category,
      amount: input.amount,
      quantity: input.quantity ?? null,
      unitLabel: input.unitLabel ?? null,
      date: input.date ? new Date(input.date) : new Date(),
      notes: input.notes ?? null,
      createdById: userId ?? null,
    },
  });
};

// =====================================================================
// Expense CRUD
// =====================================================================

export const listExpenses = async ({
  unit,
  category,
  approved,
  from,
  to,
  page = 1,
  limit = 50,
} = {}) => {
  const where = {};
  if (unit) where.unit = unit;
  if (category) where.category = category;
  if (approved != null) where.approved = approved;
  if (from || to) {
    where.date = {};
    if (from) where.date.gte = new Date(from);
    if (to) where.date.lte = new Date(to);
  }
  const [rows, total] = await Promise.all([
    prisma.expense.findMany({
      where,
      orderBy: { date: "desc" },
      skip: (page - 1) * limit,
      take: limit,
    }),
    prisma.expense.count({ where }),
  ]);
  return { rows, total, page, limit };
};

export const createExpense = async (input, userId) => {
  return prisma.expense.create({
    data: {
      unit: input.unit,
      category: input.category,
      amount: input.amount,
      vendor: input.vendor ?? null,
      paymentMethod: input.paymentMethod ?? null,
      receiptUrl: input.receiptUrl ?? null,
      approved: input.approved ?? true,
      date: input.date ? new Date(input.date) : new Date(),
      notes: input.notes ?? null,
      createdById: userId ?? null,
    },
  });
};
