// dashboard.service.js
import prisma from "../../prisma/client.js";
import { listReminders } from "../reminders/reminders.service.js";
import { listTreatments } from "../health/health.service.js";

// helper: status logic
const getStatus = (value, target) => {
  if (!target) return "neutral";
  if (value >= target) return "on_track";
  if (value >= target * 0.8) return "warning";
  return "below_target";
};

const EGGS_PER_TRAY = 30;

// Targets the schema doesn't yet store on FarmConfig. Move here when the
// Settings page lands a UI for editing them.
const FALLBACK_TARGETS = {
  milkTarget: 2000,
  cratesTarget: 700,
  pigletTarget: 100,
  layersFlockTarget: 20000,
  feedlotTarget: 50,
};

// Map each unit's display row to the role that manages it. Used to look up
// the manager's userName from the User table.
const UNIT_MANAGER_ROLES = {
  Dairy: "DAIRY_MANAGER",
  Layers: "LAYERS_MANAGER",
  Piggery: "PIGGERY_MANAGER",
};

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
const startOfMonth = (d) =>
  new Date(d.getFullYear(), d.getMonth(), 1);
const startOfNextMonth = (d) =>
  new Date(d.getFullYear(), d.getMonth() + 1, 1);

const pct = (current, target) => {
  if (!target || target <= 0) return 0;
  return Math.min(999, Math.round((current / target) * 100));
};

const dayShort = (d) =>
  ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()];

// Temporary in-memory overview so backend can run without Prisma setup.
// Replace this with DB-backed queries once Prisma client generation is fixed.
export const getDashboardOverview = async (date) => {
  const targetDate = new Date(date);
  const daySeed = targetDate.getDate();

  const milkTarget = 600;
  const milkNet = 520 + (daySeed % 6) * 18;
  const milkGross = milkNet + 25;

  const eggTarget = 5500;
  const eggCount = 4800 + (daySeed % 8) * 90;
  const eggLayingRate = Number((74 + (daySeed % 5) * 1.4).toFixed(1));

  const beaconners = 84 + (daySeed % 7);
  const pigTarget = 100;

  const totalCows = 126;
  const workers = 14;
  const calvesUnder4mo = 19;

  return {
    milk: {
      gross: milkGross,
      net: milkNet,
      target: milkTarget,
      status: getStatus(milkNet, milkTarget),
    },
    eggs: {
      count: eggCount,
      target: eggTarget,
      layingRate: eggLayingRate,
      status: getStatus(eggCount, eggTarget),
    },
    piggery: {
      beaconners,
      alive: beaconners,
      dead: 2,
      target: pigTarget,
      status: getStatus(beaconners, pigTarget),
    },
    dairyHerd: {
      totalCows,
      workers,
      calvesUnder4mo,
    },
  };
};

//////////////////////////////////////////////////////
// CEO OVERVIEW
//////////////////////////////////////////////////////

// GET /api/dashboard/overview
//
// Aggregates real data from every module into the shape the frontend
// Overview page consumes: 4 KPIs, 5 progress goals, alerts list,
// 7-day milk trend, and a unit performance table.
export const getOverview = async () => {
  const now = new Date();
  const todayStart = startOfDay(now);
  const todayEnd = endOfDay(now);
  const monthStart = startOfMonth(now);
  const nextMonth = startOfNextMonth(now);
  const sevenDaysAgo = startOfDay(now);
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6);
  const fourteenDaysFromNow = endOfDay(now);
  fourteenDaysFromNow.setDate(fourteenDaysFromNow.getDate() + 14);

  const [
    config,
    milkTodayAgg,
    layerToday,
    pigletsMtdAgg,
    bullsOnFeed,
    milkLast7,
    layerLast7,
    managers,
    reminders,
    activeTreatments,
  ] = await Promise.all([
    prisma.farmConfig.findFirst().catch(() => null),
    prisma.milkRecord.aggregate({
      where: { date: { gte: todayStart, lte: todayEnd } },
      _sum: { litres: true },
    }),
    prisma.layerProduction.findMany({
      where: { date: { gte: todayStart, lte: todayEnd } },
      select: { openingStock: true, eggsCollected: true },
    }),
    prisma.farrowingRecord.aggregate({
      where: {
        date: { gte: monthStart, lt: nextMonth },
        sow: { deletedAt: null },
      },
      _sum: { pigletsBorn: true },
    }),
    prisma.bull.count({ where: { deletedAt: null } }),
    prisma.milkRecord.findMany({
      where: { date: { gte: sevenDaysAgo, lte: todayEnd } },
      select: { date: true, litres: true },
    }),
    prisma.layerProduction.findMany({
      where: { date: { gte: sevenDaysAgo, lte: todayEnd } },
      select: { date: true, eggsCollected: true },
    }),
    prisma.user.findMany({
      where: {
        role: { in: Object.values(UNIT_MANAGER_ROLES) },
      },
      select: { userName: true, role: true },
    }),
    listReminders().catch(() => []),
    listTreatments({ activeOnly: true }).catch(() => []),
  ]);

  // ---------- top-line KPIs ----------
  const milkTarget = config?.milkTarget ?? FALLBACK_TARGETS.milkTarget;
  // FarmConfig.eggsTarget is stored as CRATES per the seed (700 crates/day),
  // not raw eggs. Use it directly.
  const cratesTarget = config?.eggsTarget ?? FALLBACK_TARGETS.cratesTarget;
  const pigletTarget = FALLBACK_TARGETS.pigletTarget;
  const layersFlockTarget = FALLBACK_TARGETS.layersFlockTarget;
  const feedlotTarget = FALLBACK_TARGETS.feedlotTarget;

  const milkToday = Math.round(milkTodayAgg._sum.litres ?? 0);
  const totalEggsToday = layerToday.reduce(
    (s, r) => s + r.eggsCollected,
    0,
  );
  const eggCrates = Math.round(totalEggsToday / EGGS_PER_TRAY);
  const layersFlock = layerToday.reduce(
    (s, r) => s + r.openingStock,
    0,
  );
  const pigletsMTD = pigletsMtdAgg._sum.pigletsBorn ?? 0;

  // ---------- alerts (top 5 reminders + every active sick treatment) ----------
  // Reminders come from the unified reminders feed (health vaccines, repro,
  // farrowing, treatment reviews). Active treatments come from the Health
  // module. Both are mapped into the dashboard alert shape so the existing
  // AlertsCard renders them unchanged.
  const alerts = [];
  let alertId = 1;
  const activeReminders = reminders.filter(
    (r) => r.bucket === "OVERDUE" || r.bucket === "DUE" || r.bucket === "UPCOMING",
  );
  for (const r of activeReminders.slice(0, 5)) {
    let type;
    let message;
    if (r.bucket === "OVERDUE") {
      type = "danger";
      const overdueBy = Math.abs(r.daysUntilDue ?? 0);
      message = overdueBy === 0
        ? "Due today — overdue"
        : `Overdue by ${overdueBy} day${overdueBy === 1 ? "" : "s"}`;
    } else if (r.bucket === "DUE") {
      type = "warning";
      const d = r.daysUntilDue ?? 0;
      message = d === 0 ? "Due today" : `Due in ${d} day${d === 1 ? "" : "s"}`;
    } else {
      type = "info";
      const d = r.daysUntilDue ?? 0;
      message = `Upcoming in ${d} day${d === 1 ? "" : "s"}`;
    }
    alerts.push({
      id: alertId++,
      type,
      title: r.title ?? "Reminder",
      message: r.unit ? `${r.unit} · ${message}` : message,
    });
  }
  // Every animal currently under treatment surfaces as an alert.
  for (const t of activeTreatments) {
    alerts.push({
      id: alertId++,
      type: t.status === "IMPROVING" ? "info" : "danger",
      title: `${t.tag} (${t.unit}) — ${t.diagnosis}`,
      message: `${t.statusLabel} · ${t.medication}`,
    });
  }

  // ---------- 7-day milk + eggs trends ----------
  const milkBuckets = new Map();
  const eggBuckets = new Map();
  const milkTrendRows = [];
  const eggsTrendRows = [];
  for (let i = 6; i >= 0; i -= 1) {
    const d = new Date(todayStart);
    d.setDate(d.getDate() - i);
    const key = d.toISOString().slice(0, 10);
    milkBuckets.set(key, 0);
    eggBuckets.set(key, 0);
    milkTrendRows.push({ key, day: dayShort(d), value: 0 });
    eggsTrendRows.push({ key, day: dayShort(d), value: 0 });
  }
  for (const r of milkLast7) {
    const key = r.date.toISOString().slice(0, 10);
    if (milkBuckets.has(key)) {
      milkBuckets.set(key, milkBuckets.get(key) + r.litres);
    }
  }
  for (const r of layerLast7) {
    const key = r.date.toISOString().slice(0, 10);
    if (eggBuckets.has(key)) {
      eggBuckets.set(key, eggBuckets.get(key) + r.eggsCollected);
    }
  }
  for (const t of milkTrendRows) {
    t.value = Math.round(milkBuckets.get(t.key) ?? 0);
  }
  for (const t of eggsTrendRows) {
    // Convert eggs → crates for display.
    t.value = Math.round((eggBuckets.get(t.key) ?? 0) / EGGS_PER_TRAY);
  }
  const milkTrend = milkTrendRows.map(({ day, value }) => ({ day, value }));
  const eggsTrend = eggsTrendRows.map(({ day, value }) => ({ day, value }));

  // 7-day averages used in the unit performance table.
  const milk7Total = milkTrend.reduce((s, t) => s + t.value, 0);
  const milk7Avg = Math.round(milk7Total / 7);

  const crates7Total = eggsTrend.reduce((s, t) => s + t.value, 0);
  const crates7Avg = Math.round(crates7Total / 7);

  // ---------- unit performance ----------
  const managerByRole = Object.fromEntries(
    managers.map((m) => [m.role, m.userName]),
  );
  const managerFor = (unit) =>
    managerByRole[UNIT_MANAGER_ROLES[unit]] ?? "—";

  const unitPerformance = [
    {
      unit: "Dairy",
      manager: managerFor("Dairy"),
      metric: "Milk litres",
      today: `${milkToday} L`,
      average: `${milk7Avg} L`,
      status: `${pct(milkToday, milkTarget)}% of target`,
    },
    {
      unit: "Layers",
      manager: managerFor("Layers"),
      metric: "Egg crates",
      today: `${eggCrates}`,
      average: `${crates7Avg}`,
      status: `${pct(eggCrates, cratesTarget)}% of target`,
    },
    {
      unit: "Piggery",
      manager: managerFor("Piggery"),
      metric: "Piglets MTD",
      today: "—",
      average: `${pigletsMTD}/mo`,
      status: `${pct(pigletsMTD, pigletTarget)}% of target`,
    },
    {
      unit: "Feedlot",
      manager: "—",
      metric: "Bulls on feed",
      today: `${bullsOnFeed}`,
      average: "—",
      status:
        bullsOnFeed === 0
          ? "Empty"
          : `${pct(bullsOnFeed, feedlotTarget)}% of target`,
    },
  ];

  return {
    milkToday,
    milkTarget,
    eggCrates,
    eggTarget: cratesTarget,
    pigletsMTD,
    pigletTarget,
    activeAlerts: alerts.length,

    goals: {
      milkProduction: {
        current: milkToday,
        target: milkTarget,
        percentage: pct(milkToday, milkTarget),
      },
      eggCrates: {
        current: eggCrates,
        target: cratesTarget,
        percentage: pct(eggCrates, cratesTarget),
      },
      piglets: {
        current: pigletsMTD,
        target: pigletTarget,
        percentage: pct(pigletsMTD, pigletTarget),
      },
      layersFlock: {
        current: layersFlock,
        target: layersFlockTarget,
        percentage: pct(layersFlock, layersFlockTarget),
      },
      feedlotThroughput: {
        current: bullsOnFeed,
        target: feedlotTarget,
        percentage: pct(bullsOnFeed, feedlotTarget),
      },
    },

    alerts,
    milkTrend,
    eggsTrend,
    unitPerformance,
  };
};
