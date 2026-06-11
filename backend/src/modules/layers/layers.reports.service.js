// =====================================================================
// Layers Reports — analytics service
// =====================================================================
// Backs GET /api/layers/reports/production. Period + house-filtered
// aggregation over LayerProduction with previous-period delta and a
// graph-ready daily-bucket array. Mirrors the shape used by the
// dairy reports module so the frontend chart components can stay
// generic.
//
// Filter contract:
//   filters = {
//     houseId?:  string,            // House.id, narrows to one house
//     period?:   PeriodPreset wire,  // see utils/period.js
//     startDate?: Date | string,    // required when period === "custom"
//     endDate?:   Date | string,
//   }
//
// Today + 7-day endpoints (kpis · trend · snapshot) keep their own
// semantics; this is a separate "analytics" path so nothing existing
// changes behaviour.

import prisma from "../../prisma/client.js";
import { deltaPct, resolveRange } from "../../utils/period.js";

const EGGS_PER_TRAY = 30;
const DAY_MS = 24 * 60 * 60 * 1000;

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

const dowLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

// Bucket LayerProduction rows into one-row-per-day across the window.
// Aggregates eggs + crates + dead + feed. The chart renders against
// `crates` (1 crate = 30 eggs) for parity with the rest of the layers
// UI which talks in crates everywhere except the raw DB column.
const bucketByDay = (records, start, end) => {
  const days =
    Math.floor((endOfDay(end) - startOfDay(start)) / DAY_MS) + 1;
  const buckets = [];
  for (let i = 0; i < days; i += 1) {
    const d = new Date(startOfDay(start).getTime() + i * DAY_MS);
    const key = d.toISOString().slice(0, 10);
    buckets.push({
      date: key,
      dow: dowLabels[d.getDay()],
      eggs: 0,
      crates: 0,
      dead: 0,
      feedKg: 0,
    });
  }
  const byDate = new Map(buckets.map((b) => [b.date, b]));
  for (const r of records) {
    const k = new Date(r.date).toISOString().slice(0, 10);
    const b = byDate.get(k);
    if (!b) continue;
    b.eggs += r.eggsCollected ?? 0;
    b.dead += r.deadRemoved ?? 0;
    b.feedKg += r.feedKg ?? 0;
  }
  for (const b of buckets) {
    b.crates = Number((b.eggs / EGGS_PER_TRAY).toFixed(1));
    b.feedKg = Number(b.feedKg.toFixed(1));
  }
  return buckets;
};

// Build a LayerProduction `where` clause from the filter input. The
// `house.type` guard makes sure we never accidentally pick up rows
// from a non-Layers house (defensive — the FK should already enforce
// the relation but a soft-deleted layer house could otherwise sneak
// rows into Dairy queries downstream).
const buildWhere = (filters, range) => {
  const where = {
    date: { gte: range.start, lte: range.end },
    house: { type: "Poultry" },
  };
  if (filters.houseId) where.houseId = filters.houseId;
  return where;
};

export const getProductionReport = async (filters = {}) => {
  const range = resolveRange(filters);
  const where = buildWhere(filters, range);
  const prevWhere = buildWhere(filters, {
    start: range.prevStart,
    end: range.prevEnd,
  });

  // All queries in one round-trip.
  const [
    curAgg,
    prevAgg,
    dailyRecords,
    perHouseRows,
    activeBirdsAgg,
    activeBirdHouses,
  ] = await Promise.all([
    prisma.layerProduction.aggregate({
      where,
      _sum: { eggsCollected: true, deadRemoved: true, feedKg: true },
    }),
    prisma.layerProduction.aggregate({
      where: prevWhere,
      _sum: { eggsCollected: true, deadRemoved: true, feedKg: true },
    }),
    prisma.layerProduction.findMany({
      where,
      select: {
        date: true,
        eggsCollected: true,
        deadRemoved: true,
        feedKg: true,
      },
    }),
    prisma.layerProduction.groupBy({
      by: ["houseId"],
      where,
      _sum: { eggsCollected: true, deadRemoved: true },
    }),
    // "Active birds" = sum of latest closingStock across the houses
    // the filter applies to. Snapshot value, not period-scoped — the
    // frontend frames this KPI as "right now".
    prisma.layerProduction.findMany({
      where: filters.houseId
        ? { houseId: filters.houseId }
        : { house: { type: "Poultry" } },
      distinct: ["houseId"],
      orderBy: { date: "desc" },
      select: { houseId: true, closingStock: true },
    }),
    prisma.house.findMany({
      where: { type: "Poultry" },
      select: { id: true, name: true, color: true, birdCount: true },
    }),
  ]);

  const eggs = curAgg._sum.eggsCollected ?? 0;
  const eggsPrev = prevAgg._sum.eggsCollected ?? 0;
  const crates = Math.round((eggs / EGGS_PER_TRAY) * 10) / 10;
  const cratesPrev = Math.round((eggsPrev / EGGS_PER_TRAY) * 10) / 10;
  const dead = curAgg._sum.deadRemoved ?? 0;
  const deadPrev = prevAgg._sum.deadRemoved ?? 0;
  const feedKg = Number((curAgg._sum.feedKg ?? 0).toFixed(1));
  const feedKgPrev = Number((prevAgg._sum.feedKg ?? 0).toFixed(1));

  // Active birds — sum the latest closingStock per house. When a
  // houseId filter is set the result is that one house's latest stock;
  // otherwise it sums across every Poultry house.
  const activeBirds = activeBirdsAgg.reduce(
    (s, r) => s + (r.closingStock ?? 0),
    0,
  );

  // Per-house breakdown. Used by the chart's "Houses" tab + the
  // best/lowest pickers. Eggs → crates for consistency.
  const houseLookup = new Map(activeBirdHouses.map((h) => [h.id, h]));
  const houses = perHouseRows
    .map((r) => {
      const h = houseLookup.get(r.houseId);
      const houseEggs = r._sum.eggsCollected ?? 0;
      return {
        houseId: r.houseId,
        name: h?.name ?? "—",
        color: h?.color ?? "#27500A",
        crates: Math.round((houseEggs / EGGS_PER_TRAY) * 10) / 10,
        eggs: houseEggs,
        dead: r._sum.deadRemoved ?? 0,
      };
    })
    .sort((a, b) => b.crates - a.crates);

  const best = houses.length > 0 ? houses[0] : null;
  const lowest = houses.length > 0 ? houses[houses.length - 1] : null;

  return {
    period: {
      label: range.label,
      start: range.start,
      end: range.end,
      prevStart: range.prevStart,
      prevEnd: range.prevEnd,
    },
    filters: {
      houseId: filters.houseId ?? null,
    },
    totals: {
      eggs,
      crates,
      dead,
      feedKg,
      activeBirds,
    },
    previousTotals: {
      eggs: eggsPrev,
      crates: cratesPrev,
      dead: deadPrev,
      feedKg: feedKgPrev,
    },
    delta: {
      crates: deltaPct(crates, cratesPrev),
      eggs: deltaPct(eggs, eggsPrev),
      // Mortality going down is good — UI flips the sign semantically;
      // we just return the raw delta and let the caller colour it.
      dead: deltaPct(dead, deadPrev),
      feedKg: deltaPct(feedKg, feedKgPrev),
    },
    daily: bucketByDay(dailyRecords, range.start, range.end),
    houses,
    best,
    lowest,
  };
};
