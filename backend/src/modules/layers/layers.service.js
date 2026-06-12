import prisma from "../../prisma/client.js";
import { decrementCrateStockBy } from "./inventory/layersInventory.service.js";

const EGGS_PER_TRAY = 30;

const startOfDay = (d) => {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
};

const endOfDay = (d) => {
  const x = new Date(d);
  x.setHours(23, 59, 59, 999);
  return x;
};

const todayRange = () => {
  const now = new Date();
  return { start: startOfDay(now), end: endOfDay(now) };
};

const daysBetween = (a, b) => {
  const ms = startOfDay(b).getTime() - startOfDay(a).getTime();
  return Math.max(1, Math.round(ms / 86_400_000));
};

const layerHouseFilter = { type: "Poultry" };

//////////////////////////////////////////////////////
// HOUSES
//////////////////////////////////////////////////////

// GET /api/layers/houses
// Returns the list of layer houses in display order.
export const listHouses = async () => {
  return prisma.house.findMany({
    where: layerHouseFilter,
    orderBy: { name: "asc" },
    select: { id: true, name: true, capacity: true, color: true },
  });
};

//////////////////////////////////////////////////////
// PRODUCTION HISTORY (per-house)
//////////////////////////////////////////////////////

// GET /api/layers/production/:houseId?days=7
// GET /api/layers/production/:houseId?date=ISO   ← single-day historical view
//
// When `date` is supplied: returns only the records logged for that exact
// calendar day. When omitted: returns the last `days` days from today
// (original behaviour, used by the parent page's initial load).
export const getProductionForHouse = async (houseId, { days, date }) => {
  const house = await prisma.house.findUnique({ where: { id: houseId } });
  if (!house) throw new Error("House not found");

  let start, end;
  if (date) {
    start = startOfDay(date);
    end = endOfDay(date);
  } else {
    end = endOfDay(new Date());
    start = startOfDay(new Date());
    start.setDate(start.getDate() - (days - 1));
  }

  const records = await prisma.layerProduction.findMany({
    where: { houseId, date: { gte: start, lte: end } },
    orderBy: { date: "asc" },
  });

  return { house: { id: house.id, name: house.name, capacity: house.capacity, color: house.color }, records };
};

//////////////////////////////////////////////////////
// CREATE / UPDATE DAILY ENTRY
//////////////////////////////////////////////////////

// POST /api/layers/production
// Idempotent per (houseId, date): re-submitting today's entry updates the
// existing row. Server computes trays, percentLaying, closingStock, dayAge.
export const upsertDailyEntry = async (input) => {
  const house = await prisma.house.findUnique({ where: { id: input.houseId } });
  if (!house) throw new Error("House not found");

  const date = startOfDay(input.date ?? new Date());

  // dayAge: previous record + days elapsed. First-ever record starts at 1.
  const prev = await prisma.layerProduction.findFirst({
    where: { houseId: input.houseId, date: { lt: date } },
    orderBy: { date: "desc" },
    select: { dayAge: true, date: true },
  });
  const dayAge = prev ? prev.dayAge + daysBetween(prev.date, date) : 1;

  const opening = input.openingStock;
  const eggs = input.eggsCollected;
  const dead = input.deadRemoved;

  const trays = Number((eggs / EGGS_PER_TRAY).toFixed(2));
  const percentLaying =
    opening > 0 ? Number(((eggs / opening) * 100).toFixed(2)) : 0;
  const closingStock = Math.max(0, opening - dead);

  const data = {
    houseId: input.houseId,
    date,
    openingStock: opening,
    eggsCollected: eggs,
    householdUsed: input.householdUsed ?? 0,
    trays,
    percentLaying,
    feedKg: input.feedKg,
    deadRemoved: dead,
    closingStock,
    dayAge,
    remarks: input.remarks ?? null,
  };

  // Capture the existing eggs-today (if any) so we can decrement the
  // crate inventory by the *delta*, not the gross. Re-submitting the
  // same entry then shouldn't double-count.
  const existing = await prisma.layerProduction.findUnique({
    where: { houseId_date: { houseId: input.houseId, date } },
    select: { eggsCollected: true },
  });
  const prevEggs = existing?.eggsCollected ?? 0;

  const saved = await prisma.layerProduction.upsert({
    where: { houseId_date: { houseId: input.houseId, date } },
    create: data,
    // dayAge stays from the original create on update — re-running today's
    // entry shouldn't bump bird age.
    update: {
      openingStock: data.openingStock,
      eggsCollected: data.eggsCollected,
      householdUsed: data.householdUsed,
      trays: data.trays,
      percentLaying: data.percentLaying,
      feedKg: data.feedKg,
      deadRemoved: data.deadRemoved,
      closingStock: data.closingStock,
      remarks: data.remarks,
    },
  });

  // Auto-update: decrement the crate-stock consumable by the net new
  // crates logged. Each crate fits 30 eggs (EGGS_PER_TRAY). Failures
  // here are logged but never fail the egg-log POST itself.
  const eggsDelta = Math.max(0, eggs - prevEggs);
  const cratesDelta = Math.floor(eggsDelta / EGGS_PER_TRAY);
  if (cratesDelta > 0) {
    try {
      await decrementCrateStockBy(cratesDelta);
    } catch (err) {
      console.warn("[layers] crate-stock decrement failed:", err.message);
    }
  }

  return saved;
};

//////////////////////////////////////////////////////
// SNAPSHOT (per-house current state)
//////////////////////////////////////////////////////

// GET /api/layers/snapshot
// One row per layer house with the latest record summarised. If a house has
// no records yet, its values come back as 0.
export const getSnapshot = async () => {
  const houses = await prisma.house.findMany({
    where: layerHouseFilter,
    orderBy: { name: "asc" },
    include: {
      layerProductions: { orderBy: { date: "desc" }, take: 1 },
    },
  });

  return houses.map((h) => {
    const last = h.layerProductions[0];
    const eggsToday = last?.eggsCollected ?? 0;
    const householdUsed = last?.householdUsed ?? 0;
    return {
      houseId: h.id,
      name: h.name,
      color: h.color,
      capacity: h.capacity,
      currentStock: last?.closingStock ?? 0,
      eggsToday,
      householdUsed,
      availableEggs: Math.max(0, eggsToday - householdUsed),
      trays: last?.trays ?? 0,
      percentLaying: last?.percentLaying ?? 0,
      feedKg: last?.feedKg ?? 0,
      lastEntryDate: last?.date ?? null,
    };
  });
};

//////////////////////////////////////////////////////
// TREND (aggregate over all layer houses)
//////////////////////////////////////////////////////

// GET /api/layers/trend?days=7
// Daily totals across all layer houses for the chart in the bottom card.
//   eggsCollected — sum
//   percentLaying — eggs/opening across all houses combined for the day
export const getTrend = async ({ days }) => {
  const end = endOfDay(new Date());
  const start = startOfDay(new Date());
  start.setDate(start.getDate() - (days - 1));

  const records = await prisma.layerProduction.findMany({
    where: {
      date: { gte: start, lte: end },
      house: layerHouseFilter,
    },
    orderBy: { date: "asc" },
    select: {
      date: true,
      eggsCollected: true,
      openingStock: true,
    },
  });

  // Bucket per day so missing days appear as zero rows.
  const buckets = new Map();
  for (let i = 0; i < days; i += 1) {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    const key = d.toISOString().slice(0, 10);
    buckets.set(key, { eggs: 0, opening: 0 });
  }
  for (const r of records) {
    const key = r.date.toISOString().slice(0, 10);
    const cur = buckets.get(key) ?? { eggs: 0, opening: 0 };
    cur.eggs += r.eggsCollected;
    cur.opening += r.openingStock;
    buckets.set(key, cur);
  }

  return Array.from(buckets.entries()).map(([date, v]) => ({
    date,
    eggsCollected: v.eggs,
    percentLaying:
      v.opening > 0 ? Number(((v.eggs / v.opening) * 100).toFixed(2)) : 0,
  }));
};

//////////////////////////////////////////////////////
// SUMMARY (top KPIs)
//////////////////////////////////////////////////////

// GET /api/layers/kpis
//   { totalBirds, eggsToday, traysToday, avgLayingRate, feedToday, mortalityToday }
// Derived from today's LayerProduction rows. totalBirds is the sum of
// today's openingStock across all layer houses. If no records exist for
// today, the snapshot's last-known closingStock is used as a fallback so
// the KPI isn't misleadingly 0.
export const getKpis = async () => {
  const { start, end } = todayRange();

  const [todayRows, fallbackHouses] = await Promise.all([
    prisma.layerProduction.findMany({
      where: { date: { gte: start, lte: end }, house: layerHouseFilter },
      select: {
        openingStock: true,
        eggsCollected: true,
        householdUsed: true,
        deadRemoved: true,
        feedKg: true,
      },
    }),
    // Used only when there are no records for today.
    prisma.house.findMany({
      where: layerHouseFilter,
      include: {
        layerProductions: {
          orderBy: { date: "desc" },
          take: 1,
          select: { closingStock: true },
        },
      },
    }),
  ]);

  let totalBirds;
  let eggsToday;
  let feedToday;
  let mortalityToday;

  let householdUsedToday = 0;

  if (todayRows.length > 0) {
    totalBirds = todayRows.reduce((s, r) => s + r.openingStock, 0);
    eggsToday = todayRows.reduce((s, r) => s + r.eggsCollected, 0);
    householdUsedToday = todayRows.reduce((s, r) => s + (r.householdUsed ?? 0), 0);
    feedToday = Number(
      todayRows.reduce((s, r) => s + r.feedKg, 0).toFixed(2),
    );
    mortalityToday = todayRows.reduce((s, r) => s + r.deadRemoved, 0);
  } else {
    totalBirds = fallbackHouses.reduce(
      (s, h) => s + (h.layerProductions[0]?.closingStock ?? 0),
      0,
    );
    eggsToday = 0;
    feedToday = 0;
    mortalityToday = 0;
  }

  const traysToday = Number((eggsToday / EGGS_PER_TRAY).toFixed(2));
  const avgLayingRate =
    totalBirds > 0 ? Math.min(1, eggsToday / totalBirds) : 0;
  const availableEggsToday = Math.max(0, eggsToday - householdUsedToday);
  const availableTraysToday = Number((availableEggsToday / EGGS_PER_TRAY).toFixed(2));

  return {
    totalBirds,
    eggsToday,
    traysToday,
    householdUsedToday,
    availableEggsToday,
    availableTraysToday,
    avgLayingRate,
    feedToday,
    mortalityToday,
  };
};
