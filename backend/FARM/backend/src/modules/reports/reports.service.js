import prisma from "../../prisma/client.js";

/* =========================================================
   📅 DATE UTILITIES
========================================================= */

// Single day (today or specific date)
const getSingleDayRange = (date = new Date()) => {
  const start = new Date(date);
  start.setHours(0, 0, 0, 0);

  const end = new Date(date);
  end.setHours(23, 59, 59, 999);

  return { start, end };
};

// Last N days (rolling window)
const getLastNDaysRange = (days = 7) => {
  const end = new Date();
  end.setHours(23, 59, 59, 999);

  const start = new Date();
  start.setDate(start.getDate() - days + 1);
  start.setHours(0, 0, 0, 0);

  return { start, end };
};

/* =========================================================
   🧮 GENERIC AGGREGATION HELPER
========================================================= */

const aggregateData = async (model, fields, range) => {
  return prisma[model].aggregate({
    _sum: fields,
    where: {
      date: {
        gte: range.start,
        lte: range.end,
      },
    },
  });
};

/* =========================================================
   📊 TODAY METRICS (Dashboard cards)
========================================================= */

export const getTodayMetrics = async () => {
  const range = getSingleDayRange();

  const [milk, eggs] = await Promise.all([
    aggregateData("milkRecord", { netLitres: true }, range),
    aggregateData("eggRecord", { eggs: true, dead: true }, range),
  ]);

  const totalEggs = eggs._sum.eggs || 0;

  return {
    milk: milk._sum.netLitres || 0,
    eggs: totalEggs,
    trays: Number((totalEggs / 30).toFixed(1)),
    mortality: eggs._sum.dead || 0,
  };
};

/* =========================================================
   📈 KPIs (Efficiency metrics)
========================================================= */

export const getKPIs = async () => {
  const [totalCows, today] = await Promise.all([
    prisma.cow.count(),
    getTodayMetrics(),
  ]);

  const totalBirds = 6900; // move to config later

  return {
    avgMilkPerCow: totalCows
      ? Number((today.milk / totalCows).toFixed(2))
      : 0,

    henDayProduction: totalBirds > 0
      ? Number(((today.eggs / totalBirds) * 100).toFixed(2))
      : 0,

    mortalityRate: totalBirds > 0
      ? Number(((today.mortality / totalBirds) * 100).toFixed(2))
      : 0,
  };
};

/* =========================================================
   📄 DAILY SUMMARY (CEO report)
========================================================= */

export const getDailySummary = async (date) => {
  const range = getSingleDayRange(date);

  const [milk, eggs, mortality] = await Promise.all([
    aggregateData("milkRecord", { netLitres: true }, range),
    aggregateData("eggRecord", { eggs: true }, range),
    aggregateData("eggRecord", { dead: true }, range),
  ]);

  const totalEggs = eggs._sum.eggs || 0;

  return {
    date,
    milk: milk._sum.netLitres || 0,
    eggs: totalEggs,
    trays: Number((totalEggs / 30).toFixed(1)),
    mortality: mortality._sum.dead || 0,
  };
};

/* =========================================================
   🐄 MILK TREND (7/30 days)
========================================================= */

export const getMilkTrend = async (days = 7) => {
  const range = getLastNDaysRange(days);

  const records = await prisma.milkRecord.findMany({
    where: {
      date: {
        gte: range.start,
        lte: range.end,
      },
    },
    orderBy: { date: "asc" },
  });

  const trendMap = {};

  records.forEach((r) => {
    const date = r.date.toISOString().split("T")[0];
    trendMap[date] = (trendMap[date] || 0) + r.netLitres;
  });

  return Object.entries(trendMap)
    .map(([date, milk]) => ({
      date,
      milk,
    }))
    .sort((a, b) => new Date(a.date) - new Date(b.date));
};

/* =========================================================
   🐔 EGG TREND (7/30 days)
========================================================= */

export const getEggTrend = async (days = 7) => {
  const range = getLastNDaysRange(days);

  const records = await prisma.eggRecord.findMany({
    where: {
      date: {
        gte: range.start,
        lte: range.end,
      },
    },
    orderBy: { date: "asc" },
  });

  const trendMap = {};

  records.forEach((r) => {
    const date = r.date.toISOString().split("T")[0];

    if (!trendMap[date]) {
      trendMap[date] = { eggs: 0, dead: 0 };
    }

    trendMap[date].eggs += r.eggs;
    trendMap[date].dead += r.dead;
  });

  return Object.entries(trendMap)
    .map(([date, val]) => ({
      date,
      eggs: val.eggs,
      trays: Number((val.eggs / 30).toFixed(1)),
      mortality: val.dead,
    }))
    .sort((a, b) => new Date(a.date) - new Date(b.date));
};

import { Parser } from "json2csv";

/* =========================================================
   📄 CSV EXPORT UTILITY
========================================================= */

export const exportCSV = (data) => {
  if (!data || data.length === 0) {
    return "";
  }

  // Flatten Prisma objects if needed
  const cleaned = data.map((item) => ({
    date: item.date,
    netLitres: item.netLitres,
    cowId: item.cowId || null,
  }));

  const parser = new Parser({
    fields: Object.keys(cleaned[0]),
  });

  return parser.parse(cleaned);
};

export const getMonthlyDairy = async (month) => {
  const start = new Date(`${month}-01`);
  const end = new Date(start);
  end.setMonth(end.getMonth() + 1);

  return prisma.milkRecord.findMany({
    where: {
      date: {
        gte: start,
        lt: end,
      },
    },
    orderBy: { date: "asc" },
  });
};