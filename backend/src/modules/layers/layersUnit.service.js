import prisma from "../../prisma/client.js";

// =====================================================================
// LAYERS UNIT — UNIFIED DOMAIN AGGREGATOR
// =====================================================================
// Produces the single payload backing GET /api/layers-unit:
//   {
//     layers:      { totalBirds, cratesToday, mortalityToday, houses: [...] }
//     brooder:     { id, population, ageDays, receivedDate, transferDate,
//                    progressPercent, status, mortality }
//     production:  [ { date, eggsCollected, percentLaying } ]   // 7-day chart
//     vaccination: [ { name, dayOffset, scheduledDate, status, doneDate } ]
//     allocation:  [ { type, birds, description, createdAt, cycleId } ]
//   }
//
// Design rules:
//   * No status fields are stored. `brooder.status` is derived from
//     ageDays + actualTransferDate; `house.phasingOut` from ageDays vs 360
//     and birdCount vs 90% of capacity; vaccination `status` from records
//     overlaid on the protocol.
//   * The vaccination PROTOCOL lives in code (BROODER_VACCINE_PROTOCOL).
//     Completion records (administered events) are read from the Health
//     module's polymorphic `VaccinationRecord` table, scoped by
//     `brooderId`. The legacy `BrooderVaccination` table is no longer
//     read by this service — see migration 20260508111500.
//   * Allocations are versioned: when multiple rows exist for one type, the
//     most recent (by createdAt) wins for the dashboard view.

const EGGS_PER_TRAY = 30;
const PHASING_OUT_AGE_DAYS = 360;
const PHASING_OUT_RATIO = 0.9;
const DUE_NOW_WINDOW_DAYS = 7;

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

const daysBetween = (a, b) =>
  Math.floor((startOfDay(b).getTime() - startOfDay(a).getTime()) / 86_400_000);

const addDays = (d, n) => {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
};

// ---------------------------------------------------------------------
// Brooder vaccination protocol — single source of truth in code.
// `dayOffset` is the day-of-life when the vaccine is due. `windowDays`
// extends the DUE_NOW band for multi-day vaccinations (e.g. Fowl
// typhoid + Fowl pox is "Day 56-63" in the HTML).
// ---------------------------------------------------------------------
export const BROODER_VACCINE_PROTOCOL = [
  { name: "Newcastle (1st dose)",            dayOffset: 12, windowDays: 0 },
  { name: "Gumboro (IBD)",                   dayOffset: 15, windowDays: 0 },
  { name: "Newcastle (repeat, Week 6)",      dayOffset: 42, windowDays: 0 },
  { name: "Fowl typhoid + Fowl pox (Week 8-9)", dayOffset: 56, windowDays: 7 },
  { name: "Coryza (Week 11)",                dayOffset: 77, windowDays: 0 },
  { name: "Move from brooder to cage (Week 12)", dayOffset: 84, windowDays: 0, milestone: true },
  { name: "Egg drop syndrome vaccine (Week 14)", dayOffset: 98, windowDays: 0 },
];

// ---------------------------------------------------------------------
// Brooder helpers
// ---------------------------------------------------------------------

const deriveBrooderStatus = ({ ageDays, targetDays, actualTransferDate }) => {
  if (actualTransferDate) return "TRANSFERRED";
  if (ageDays >= targetDays) return "TRANSFERRED";
  if (ageDays >= targetDays - 7) return "READY_TO_TRANSFER";
  return "REARING";
};

const buildBrooderView = (brooder) => {
  if (!brooder) return null;

  const today = startOfDay(new Date());
  const received = startOfDay(brooder.receivedDate);
  const ageDays = Math.max(0, daysBetween(received, today));
  const transferDate = addDays(received, brooder.targetDays);
  const progressPercent = Math.min(
    100,
    Math.round((ageDays / brooder.targetDays) * 100),
  );

  return {
    id: brooder.id,
    label: brooder.label,
    population: brooder.population,
    mortality: brooder.mortality,
    receivedDate: received.toISOString(),
    transferDate: transferDate.toISOString(),
    actualTransferDate: brooder.actualTransferDate
      ? brooder.actualTransferDate.toISOString()
      : null,
    targetDays: brooder.targetDays,
    ageDays,
    daysRemaining: Math.max(0, brooder.targetDays - ageDays),
    progressPercent,
    status: deriveBrooderStatus({
      ageDays,
      targetDays: brooder.targetDays,
      actualTransferDate: brooder.actualTransferDate,
    }),
  };
};

// Vaccination view = protocol overlaid with completion records.
//   DONE       — administered record exists
//   DUE_NOW    — within ±DUE_NOW_WINDOW_DAYS (or +windowDays for multi-day vaccines)
//   OVERDUE    — scheduledDate < today, no record
//   UPCOMING   — scheduledDate > today + window
const buildVaccinationView = (brooder, records) => {
  if (!brooder) return [];

  const today = startOfDay(new Date());
  const received = startOfDay(brooder.receivedDate);
  const recordByOffset = new Map(records.map((r) => [r.dayOffset, r]));

  return BROODER_VACCINE_PROTOCOL.map((step) => {
    const scheduledDate = addDays(received, step.dayOffset);
    const record = recordByOffset.get(step.dayOffset);
    const window = Math.max(DUE_NOW_WINDOW_DAYS, step.windowDays);
    const dayDelta = daysBetween(scheduledDate, today);

    let status;
    if (record) {
      status = "DONE";
    } else if (dayDelta < -window) {
      status = "UPCOMING";
    } else if (dayDelta > step.windowDays) {
      status = "OVERDUE";
    } else {
      status = "DUE_NOW";
    }

    return {
      name: step.name,
      dayOffset: step.dayOffset,
      windowDays: step.windowDays,
      milestone: Boolean(step.milestone),
      scheduledDate: scheduledDate.toISOString(),
      doneDate: record ? record.administeredAt.toISOString() : null,
      status,
    };
  });
};

// ---------------------------------------------------------------------
// House helpers — phasing-out is dynamic (no boolean stored).
// ---------------------------------------------------------------------

const computeHouseView = ({ house, latestProduction }) => {
  const flockAgeDays = latestProduction?.dayAge ?? 0;
  const cratesToday =
    latestProduction?.eggsCollected != null
      ? Math.round((latestProduction.eggsCollected / EGGS_PER_TRAY) * 10) / 10
      : 0;
  const feedKg = latestProduction?.feedKg ?? 0;
  // Prefer the latest production's closing stock — it reflects every
  // dead-removed deduction. The seeded `house.birdCount` is the
  // registered/headline figure used only as a Day-1 fallback (no
  // production records yet for this house). Previously we preferred
  // birdCount unconditionally, which made the house tile keep
  // showing 2,980 hens even after a worker logged 90 dead.
  const birdCount =
    latestProduction?.closingStock != null
      ? latestProduction.closingStock
      : house.birdCount;

  // Phasing-out rule (dynamic):
  //   * Reaching end-of-lay window (>= 360 days), OR
  //   * Stock has dropped meaningfully below capacity (<90%).
  const phasingOut =
    flockAgeDays >= PHASING_OUT_AGE_DAYS ||
    (house.capacity > 0 && birdCount < house.capacity * PHASING_OUT_RATIO);

  return {
    id: house.id,
    name: house.name,
    color: house.color,
    capacity: house.capacity,
    birdCount,
    flockAgeDays,
    cratesToday,
    feedKg,
    phasingOut,
    status: phasingOut ? "PHASING_OUT" : "CONTINUING",
  };
};

// ---------------------------------------------------------------------
// Allocations — pick the latest revision per type so the dashboard
// reflects the current plan, but keep all rows queryable.
// ---------------------------------------------------------------------

const buildAllocationView = (allocations) => {
  // Group by type; pick newest createdAt per type.
  const byType = new Map();
  for (const a of allocations) {
    const cur = byType.get(a.type);
    if (!cur || a.createdAt > cur.createdAt) byType.set(a.type, a);
  }
  return Array.from(byType.values()).map((a) => ({
    id: a.id,
    type: a.type,
    birds: a.birds,
    description: a.description,
    cycleId: a.cycleId,
    createdAt: a.createdAt.toISOString(),
  }));
};

// ---------------------------------------------------------------------
// 7-day production trend across all layer houses.
// ---------------------------------------------------------------------

const buildProductionTrend = async (days = 7) => {
  const end = endOfDay(new Date());
  const start = startOfDay(new Date());
  start.setDate(start.getDate() - (days - 1));

  const records = await prisma.layerProduction.findMany({
    where: {
      date: { gte: start, lte: end },
      house: { type: "Poultry" },
    },
    select: { date: true, eggsCollected: true, openingStock: true },
  });

  const buckets = new Map();
  for (let i = 0; i < days; i += 1) {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    buckets.set(d.toISOString().slice(0, 10), { eggs: 0, opening: 0 });
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
    cratesCollected: Number((v.eggs / EGGS_PER_TRAY).toFixed(1)),
    percentLaying:
      v.opening > 0 ? Number(((v.eggs / v.opening) * 100).toFixed(2)) : 0,
  }));
};

// ---------------------------------------------------------------------
// Top-level aggregator
// ---------------------------------------------------------------------

// =====================================================================
// HEALTH MODULE INTEROP
// =====================================================================
// The Health module's vaccination schedule composes DB-stored
// VaccineProtocol rows with the brooder protocol that lives here. This
// helper exposes the brooder vaccinations in the same shape the Health
// composer expects so it never needs to know about Brooder internals.
//
// Returned shape (one row per brooder vaccine step):
//   {
//     vaccine, unit, animals,
//     lastDone, lastDoneAt, nextDue, nextDueAt,
//     status, type, daysUntilDue, source, protocolId
//   }
export const getBrooderScheduleRows = async () => {
  const brooder = await prisma.brooder.findFirst({
    orderBy: { receivedDate: "desc" },
    include: { vaccinationRecords: true },
  });
  if (!brooder) return [];

  const view = buildVaccinationView(brooder, brooder.vaccinationRecords);
  const today = startOfDay(new Date());

  return view.map((v) => {
    const scheduledDate = new Date(v.scheduledDate);
    const doneDate = v.doneDate ? new Date(v.doneDate) : null;

    // Display strings — match the HTML's "Mar 2026 (Day 12)" / "Day 56-63 (now)"
    // patterns exactly.
    const dayLabel = v.windowDays > 0
      ? `Day ${v.dayOffset}-${v.dayOffset + v.windowDays}`
      : `Day ${v.dayOffset}`;
    const lastDoneStr = doneDate
      ? `${formatMonthYear(doneDate)} (Day ${v.dayOffset})`
      : null;
    let nextDueStr;
    if (v.status === "DONE") {
      // Once a brooder vaccine is done, there is no further "next due"
      // for this batch — the protocol moves on to the next dose.
      nextDueStr = null;
    } else if (v.status === "DUE_NOW") {
      nextDueStr = `${dayLabel} (now)`;
    } else {
      nextDueStr = `${formatMonthYear(scheduledDate)} (${dayLabel})`;
    }

    const daysUntilDue = doneDate
      ? null
      : daysBetween(today, scheduledDate);

    return {
      vaccine: v.name,
      unit: "Layers",
      animals: brooder.population,
      lastDone: lastDoneStr,
      lastDoneAt: doneDate ? doneDate.toISOString() : null,
      nextDue: nextDueStr,
      nextDueAt:
        v.status === "DONE" ? null : scheduledDate.toISOString(),
      status: v.status,
      type: "BROODER_DAY",
      daysUntilDue,
      source: "BROODER",
      protocolId: null,
      // Extra fields useful for the KPI engine + UI.
      brooderId: brooder.id,
      dayOffsetStart: v.dayOffset,
      dayOffsetEnd: v.dayOffset + (v.windowDays || 0),
      milestone: v.milestone,
    };
  });
};

const formatMonthYear = (d) =>
  d.toLocaleString("en-US", { month: "short", year: "numeric" });

// GET /api/layers-unit
// Returns the unified Layers Unit dashboard payload in one round-trip.
export const getLayersUnit = async () => {
  // Run everything we can in parallel — there are no read dependencies.
  const [houses, latestBrooder, productionTrend] = await Promise.all([
    prisma.house.findMany({
      where: { type: "Poultry" },
      orderBy: { name: "asc" },
      include: {
        layerProductions: {
          orderBy: { date: "desc" },
          take: 1,
        },
      },
    }),
    prisma.brooder.findFirst({
      orderBy: { receivedDate: "desc" },
      include: {
        // Source of truth for "DONE" state is the Health module's
        // unified VaccinationRecord table, not the legacy
        // BrooderVaccination one.
        vaccinationRecords: true,
        allocations: { orderBy: { createdAt: "desc" } },
      },
    }),
    buildProductionTrend(7),
  ]);

  const houseViews = houses.map((h) =>
    computeHouseView({ house: h, latestProduction: h.layerProductions[0] }),
  );

  const totalBirds = houseViews.reduce((s, h) => s + h.birdCount, 0);
  const cratesToday = Number(
    houseViews.reduce((s, h) => s + (h.cratesToday ?? 0), 0).toFixed(1),
  );
  // Mortality today comes from today's LayerProduction rows.
  const todayStart = startOfDay(new Date());
  const todayEnd = endOfDay(new Date());
  const todayRows = await prisma.layerProduction.findMany({
    where: {
      date: { gte: todayStart, lte: todayEnd },
      house: { type: "Poultry" },
    },
    select: { deadRemoved: true },
  });
  const mortalityToday = todayRows.reduce((s, r) => s + r.deadRemoved, 0);

  const brooderView = buildBrooderView(latestBrooder);
  const vaccinationView = buildVaccinationView(
    latestBrooder,
    latestBrooder?.vaccinationRecords ?? [],
  );
  const allocationView = buildAllocationView(latestBrooder?.allocations ?? []);

  return {
    layers: {
      totalBirds,
      cratesToday,
      mortalityToday,
      houses: houseViews,
    },
    brooder: brooderView,
    production: productionTrend,
    vaccination: vaccinationView,
    allocation: allocationView,
  };
};
