// =====================================================================
// Dairy Reports — analytics service
// =====================================================================
// Backs the GET /api/dairy/reports/* family. Phase 1 ships the Milk
// Production report; other report types (reproduction, health, calves,
// inventory, worker productivity) will land here as separate exported
// functions once the front-end pill bar lights them up.
//
// Filter contract (every report function takes the same shape):
//
//   filters = {
//     animalId?: string,       // Cow.id, narrows everything to one cow
//     houseId?:  string,       // House.id
//     workerId?: string,       // Worker.id
//     period?:   "today" | "week" | "month" | "quarter"
//              | "halfyear" | "annual" | "custom",
//     startDate?: Date | string, // required when period === "custom"
//     endDate?:   Date | string, //  "
//   }
//
// `resolveRange` maps a period preset to two adjacent ranges so the
// report can quote "+12% vs last month" without the caller doing date
// math. For "custom" we mirror the user-supplied range backwards by
// the same length.
// =====================================================================

import prisma from "../../prisma/client.js";
import { resolveRange } from "../../utils/period.js";

const DAY_MS = 24 * 60 * 60 * 1000;

// Re-export so callers that already import resolveRange from this
// module keep working. New callers should import directly from
// `../../utils/period.js`.
export { resolveRange };

// Local startOfDay / endOfDay helpers (used by the bucketByDay loops
// further down). The shared util's startOfDay/endOfDay are private —
// we keep these small mirrors to avoid pulling them into the public
// API of period.js just for two callers.
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

// Bucket records into one row per day across the [start..end] inclusive
// window. Returns oldest-first so the chart x-axis reads left→right.
const bucketByDay = (records, start, end) => {
  const days = Math.floor((endOfDay(end) - startOfDay(start)) / DAY_MS) + 1;
  const buckets = [];
  for (let i = 0; i < days; i += 1) {
    const d = new Date(startOfDay(start).getTime() + i * DAY_MS);
    const key = d.toISOString().slice(0, 10);
    buckets.push({ date: key, dow: dowLabels[d.getDay()], litres: 0 });
  }
  const byDate = new Map(buckets.map((b) => [b.date, b]));
  for (const r of records) {
    const k = new Date(r.date).toISOString().slice(0, 10);
    const b = byDate.get(k);
    if (b) b.litres += r.litres ?? 0;
  }
  for (const b of buckets) b.litres = Number(b.litres.toFixed(1));
  return buckets;
};

// Compose the MilkRecord Prisma `where` clause from filters. Animal /
// house / worker compose with AND. `houseId` reaches through the cow
// relation so the milk-record query can stay flat.
const buildMilkWhere = (filters, range) => {
  const where = {
    date: { gte: range.start, lte: range.end },
  };
  if (filters.animalId) where.cowId = filters.animalId;
  if (filters.workerId) where.cow = { workerId: filters.workerId };
  if (filters.houseId) {
    where.cow = { ...(where.cow ?? {}), houseId: filters.houseId };
  }
  return where;
};

/* -------------------------------------------------------------------
 * Milk Production Report
 * ----------------------------------------------------------------- */

// Returns:
//   {
//     period: { label, start, end, prevStart, prevEnd },
//     totals: {
//       litres, prevLitres, deltaPct,
//       activeCows, avgPerCow,
//       sessions: { DAWN, AM, MID, PM }
//     },
//     best:   { cowId, tag, nickname, litres } | null,
//     lowest: { cowId, tag, nickname, litres } | null,
//     daily:  [{ date, dow, litres }, ...]
//   }
export const getMilkProductionReport = async (filters = {}) => {
  const range = resolveRange(filters);
  const where = buildMilkWhere(filters, range);
  const prevWhere = buildMilkWhere(filters, {
    start: range.prevStart,
    end: range.prevEnd,
  });

  // Pull everything we need in parallel.
  const [
    sumAgg,
    prevSumAgg,
    sessionRows,
    perCowRows,
    dailyRecords,
  ] = await Promise.all([
    prisma.milkRecord.aggregate({ where, _sum: { litres: true } }),
    prisma.milkRecord.aggregate({ where: prevWhere, _sum: { litres: true } }),
    prisma.milkRecord.groupBy({
      by: ["session"],
      where,
      _sum: { litres: true },
    }),
    prisma.milkRecord.groupBy({
      by: ["cowId"],
      where,
      _sum: { litres: true },
    }),
    prisma.milkRecord.findMany({
      where,
      select: { date: true, litres: true },
    }),
  ]);

  const totalLitres = Number((sumAgg._sum.litres ?? 0).toFixed(1));
  const prevLitres = Number((prevSumAgg._sum.litres ?? 0).toFixed(1));
  // Delta is null (not 0) when the previous window had no data — the
  // UI needs to know the difference between "no change" and "no basis
  // for comparison".
  const deltaPct =
    prevLitres > 0
      ? Number((((totalLitres - prevLitres) / prevLitres) * 100).toFixed(1))
      : null;

  const sessions = { DAWN: 0, AM: 0, MID: 0, PM: 0 };
  for (const r of sessionRows) {
    sessions[r.session] = Number((r._sum.litres ?? 0).toFixed(1));
  }

  // Resolve cow display fields for the best/lowest pickers. We only
  // fetch tag + nickname for the cows that actually showed up in the
  // window — avoids loading the whole herd.
  const cowIds = perCowRows.map((r) => r.cowId);
  const cows = cowIds.length
    ? await prisma.cow.findMany({
        where: { id: { in: cowIds } },
        select: { id: true, tag: true, nickname: true },
      })
    : [];
  const cowById = new Map(cows.map((c) => [c.id, c]));

  const perCow = perCowRows
    .map((r) => {
      const c = cowById.get(r.cowId);
      return {
        cowId: r.cowId,
        tag: c?.tag ?? "—",
        nickname: c?.nickname ?? null,
        litres: Number((r._sum.litres ?? 0).toFixed(1)),
      };
    })
    .filter((r) => r.litres > 0);

  const sorted = [...perCow].sort((a, b) => b.litres - a.litres);
  const best = sorted[0] ?? null;
  const lowest = sorted[sorted.length - 1] ?? null;

  const activeCows = perCow.length;
  const avgPerCow =
    activeCows > 0 ? Number((totalLitres / activeCows).toFixed(2)) : 0;

  return {
    period: {
      label: range.label,
      start: range.start,
      end: range.end,
      prevStart: range.prevStart,
      prevEnd: range.prevEnd,
    },
    filters: {
      animalId: filters.animalId ?? null,
      houseId: filters.houseId ?? null,
      workerId: filters.workerId ?? null,
    },
    totals: {
      litres: totalLitres,
      prevLitres,
      deltaPct,
      activeCows,
      avgPerCow,
      sessions,
    },
    best,
    lowest,
    daily: bucketByDay(dailyRecords, range.start, range.end),
  };
};

/* -------------------------------------------------------------------
 * Generic helpers shared across the non-milk reports
 * ----------------------------------------------------------------- */

// Build a Cow `where` fragment for animal/house/worker filters. Used
// for queries that pivot on Cow (Treatment looks up by tag → cow,
// VaccinationRecord pivots by unit so this only narrows when filters
// are supplied).
const buildCowFilter = (filters) => {
  const cowWhere = {};
  if (filters.animalId) cowWhere.id = filters.animalId;
  if (filters.houseId) cowWhere.houseId = filters.houseId;
  if (filters.workerId) cowWhere.workerId = filters.workerId;
  return cowWhere;
};

// Returns the set of cow tags that pass the scope filters, or null
// when no filters are set (= no narrowing). Used by Treatment and
// VaccinationRecord which reference animals by tag, not by FK.
const resolveScopedTags = async (filters) => {
  const cowWhere = buildCowFilter(filters);
  if (Object.keys(cowWhere).length === 0) return null;
  const cows = await prisma.cow.findMany({
    where: cowWhere,
    select: { tag: true },
  });
  return new Set(cows.map((c) => c.tag));
};

// Group records into per-day buckets across [start..end]. Generic
// version of bucketByDay — caller supplies the field to read each
// record's date from and an aggregation callback. Returns oldest-first.
const bucketByDayWith = (records, start, end, dateField, agg) => {
  const days = Math.floor((endOfDay(end) - startOfDay(start)) / DAY_MS) + 1;
  const buckets = [];
  for (let i = 0; i < days; i += 1) {
    const d = new Date(startOfDay(start).getTime() + i * DAY_MS);
    const key = d.toISOString().slice(0, 10);
    buckets.push({ date: key, dow: dowLabels[d.getDay()], count: 0 });
  }
  const byDate = new Map(buckets.map((b) => [b.date, b]));
  for (const r of records) {
    const k = new Date(r[dateField]).toISOString().slice(0, 10);
    const b = byDate.get(k);
    if (b) agg(b, r);
  }
  return buckets;
};

/* -------------------------------------------------------------------
 * Reproduction Report
 * ----------------------------------------------------------------- */

// Returns:
//   {
//     period, filters,
//     totals: {
//       aiCount, calvings, pregnanciesConfirmed,
//       pendingChecks, expectedCalvings, prevAiCount, deltaPct
//     },
//     pregnancyRate, conceptionRate,
//     aiTrend:  [{ date, dow, count }],
//     calvingTrend: [{ date, dow, count }],
//     upcomingCalvings: [{ cowId, tag, nickname, expectedCalvingDate, daysOut }],
//     recentEvents:    [{ id, eventType, eventDate, cow, sireCode, ... }]
//   }
export const getReproductionReport = async (filters = {}) => {
  const range = resolveRange(filters);
  const cowWhere = buildCowFilter(filters);
  const inScopeCow =
    Object.keys(cowWhere).length === 0 ? undefined : { is: cowWhere };

  const baseWhere = {
    deletedAt: null,
    eventDate: { gte: range.start, lte: range.end },
    ...(inScopeCow ? { cow: inScopeCow } : {}),
  };
  const prevWhere = {
    deletedAt: null,
    eventDate: { gte: range.prevStart, lte: range.prevEnd },
    ...(inScopeCow ? { cow: inScopeCow } : {}),
  };

  const [
    eventGroups,
    prevAiCount,
    statusGroups,
    upcomingCalvings,
    recentEvents,
    aiRecords,
    calvingRecords,
  ] = await Promise.all([
    prisma.reproductionRecord.groupBy({
      by: ["eventType"],
      where: baseWhere,
      _count: { _all: true },
    }),
    prisma.reproductionRecord.count({
      where: { ...prevWhere, eventType: "AI" },
    }),
    prisma.reproductionRecord.groupBy({
      by: ["pregnancyStatus"],
      where: { ...baseWhere, eventType: "AI" },
      _count: { _all: true },
    }),
    prisma.reproductionRecord.findMany({
      where: {
        deletedAt: null,
        pregnancyStatus: "CONFIRMED",
        expectedCalvingDate: { gte: new Date() },
        ...(inScopeCow ? { cow: inScopeCow } : {}),
      },
      orderBy: { expectedCalvingDate: "asc" },
      take: 12,
      include: {
        cow: {
          select: { id: true, tag: true, nickname: true },
        },
      },
    }),
    prisma.reproductionRecord.findMany({
      where: baseWhere,
      orderBy: { eventDate: "desc" },
      take: 15,
      include: {
        cow: {
          select: { id: true, tag: true, nickname: true },
        },
      },
    }),
    prisma.reproductionRecord.findMany({
      where: { ...baseWhere, eventType: "AI" },
      select: { eventDate: true },
    }),
    prisma.reproductionRecord.findMany({
      where: { ...baseWhere, eventType: "CALVING" },
      select: { eventDate: true },
    }),
  ]);

  const counts = { AI: 0, CALVING: 0 };
  for (const g of eventGroups) counts[g.eventType] = g._count._all;
  const aiCount = counts.AI;
  const calvings = counts.CALVING;

  const status = { CONFIRMED: 0, PENDING: 0, FAILED: 0 };
  for (const g of statusGroups) status[g.pregnancyStatus] = g._count._all;

  const pregnanciesConfirmed = status.CONFIRMED;
  const pendingChecks = status.PENDING;

  // Pregnancy rate: confirmed / AI events that have a status decision.
  const decided = status.CONFIRMED + status.FAILED;
  const pregnancyRate =
    decided > 0
      ? Number(((status.CONFIRMED / decided) * 100).toFixed(1))
      : null;
  // Conception rate: confirmed / total AI events (incl. still-pending).
  const conceptionRate =
    aiCount > 0
      ? Number(((status.CONFIRMED / aiCount) * 100).toFixed(1))
      : null;

  const deltaPct =
    prevAiCount > 0
      ? Number((((aiCount - prevAiCount) / prevAiCount) * 100).toFixed(1))
      : null;

  const now = new Date();
  const upcoming = upcomingCalvings.map((r) => ({
    id: r.id,
    cowId: r.cow?.id ?? null,
    tag: r.cow?.tag ?? null,
    nickname: r.cow?.nickname ?? null,
    sireCode: r.sireCode,
    expectedCalvingDate: r.expectedCalvingDate,
    daysOut: r.expectedCalvingDate
      ? Math.round((new Date(r.expectedCalvingDate) - now) / DAY_MS)
      : null,
  }));

  return {
    period: {
      label: range.label,
      start: range.start,
      end: range.end,
      prevStart: range.prevStart,
      prevEnd: range.prevEnd,
    },
    filters: {
      animalId: filters.animalId ?? null,
      houseId: filters.houseId ?? null,
      workerId: filters.workerId ?? null,
    },
    totals: {
      aiCount,
      calvings,
      pregnanciesConfirmed,
      pendingChecks,
      expectedCalvings: upcoming.length,
      prevAiCount,
      deltaPct,
    },
    pregnancyRate,
    conceptionRate,
    aiTrend: bucketByDayWith(
      aiRecords,
      range.start,
      range.end,
      "eventDate",
      (b) => b.count++,
    ),
    calvingTrend: bucketByDayWith(
      calvingRecords,
      range.start,
      range.end,
      "eventDate",
      (b) => b.count++,
    ),
    upcomingCalvings: upcoming,
    recentEvents: recentEvents.map((r) => ({
      id: r.id,
      eventType: r.eventType,
      eventDate: r.eventDate,
      sireCode: r.sireCode,
      pregnancyStatus: r.pregnancyStatus,
      expectedCalvingDate: r.expectedCalvingDate,
      calfTag: r.calfTag,
      calfSex: r.calfSex,
      cow: r.cow
        ? {
            id: r.cow.id,
            tag: r.cow.tag,
            nickname: r.cow.nickname,
          }
        : null,
    })),
  };
};

/* -------------------------------------------------------------------
 * Health Report
 * ----------------------------------------------------------------- */

// Treatment rows reference animals by tag (operational id), not by FK.
// We resolve cow rows separately by tag so we can derive house breakdowns
// and apply scope filters. Vet visits / sick reports both surface in
// Treatment with conventions captured in ReportSickDialog (severity
// encoded in notes; medication="Pending vet review" until triaged).
export const getHealthReport = async (filters = {}) => {
  const range = resolveRange(filters);
  const scopedTags = await resolveScopedTags(filters);

  const where = {
    unit: "Dairy",
    startDate: { gte: range.start, lte: range.end },
    ...(scopedTags ? { tag: { in: Array.from(scopedTags) } } : {}),
  };
  const prevWhere = {
    unit: "Dairy",
    startDate: { gte: range.prevStart, lte: range.prevEnd },
    ...(scopedTags ? { tag: { in: Array.from(scopedTags) } } : {}),
  };

  // Active = not yet resolved at end of window. Critical = severity
  // SEVERE which is encoded in the `notes` text (per ReportSickDialog
  // convention). We pull notes for that subset only.
  const [statusGroups, prevCount, diagnosisRows, recentCases, activeCases] =
    await Promise.all([
      prisma.treatment.groupBy({
        by: ["status"],
        where,
        _count: { _all: true },
      }),
      prisma.treatment.count({ where: prevWhere }),
      prisma.treatment.groupBy({
        by: ["diagnosis"],
        where,
        _count: { _all: true },
      }),
      prisma.treatment.findMany({
        where,
        orderBy: { startDate: "desc" },
        take: 12,
      }),
      prisma.treatment.findMany({
        where: {
          ...where,
          status: { in: ["ACTIVE", "IMPROVING"] },
        },
        orderBy: { startDate: "desc" },
        take: 30,
      }),
    ]);

  const statusCounts = {
    ACTIVE: 0,
    IMPROVING: 0,
    RECOVERED: 0,
    CANCELLED: 0,
  };
  for (const g of statusGroups) statusCounts[g.status] = g._count._all;

  const total =
    statusCounts.ACTIVE +
    statusCounts.IMPROVING +
    statusCounts.RECOVERED +
    statusCounts.CANCELLED;
  const critical = recentCases.filter((t) =>
    /\bSEVERE\b/i.test(t.notes ?? ""),
  ).length;

  // House breakdown. Group all active cases by their cow's house. We
  // grab the relevant cow rows once and group in memory rather than
  // round-tripping per case.
  const activeTags = [...new Set(activeCases.map((c) => c.tag))];
  const cows = activeTags.length
    ? await prisma.cow.findMany({
        where: { tag: { in: activeTags } },
        select: {
          id: true,
          tag: true,
          nickname: true,
          house: { select: { id: true, name: true } },
        },
      })
    : [];
  const cowByTag = new Map(cows.map((c) => [c.tag, c]));
  const houseMap = new Map();
  for (const c of activeCases) {
    const house = cowByTag.get(c.tag)?.house;
    const key = house?.id ?? "__unhoused__";
    const row = houseMap.get(key) ?? {
      houseId: house?.id ?? null,
      houseName: house?.name ?? "Unhoused",
      count: 0,
    };
    row.count += 1;
    houseMap.set(key, row);
  }

  const diseases = diagnosisRows
    .map((g) => ({
      diagnosis: g.diagnosis,
      count: g._count._all,
    }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 10);

  const deltaPct =
    prevCount > 0
      ? Number((((total - prevCount) / prevCount) * 100).toFixed(1))
      : null;

  return {
    period: {
      label: range.label,
      start: range.start,
      end: range.end,
      prevStart: range.prevStart,
      prevEnd: range.prevEnd,
    },
    filters: {
      animalId: filters.animalId ?? null,
      houseId: filters.houseId ?? null,
      workerId: filters.workerId ?? null,
    },
    totals: {
      sick: total,
      active: statusCounts.ACTIVE + statusCounts.IMPROVING,
      recovered: statusCounts.RECOVERED,
      critical,
      prev: prevCount,
      deltaPct,
    },
    diseases,
    houseBreakdown: Array.from(houseMap.values()).sort(
      (a, b) => b.count - a.count,
    ),
    pendingCases: activeCases.slice(0, 15).map((t) => ({
      id: t.id,
      tag: t.tag,
      nickname: cowByTag.get(t.tag)?.nickname ?? null,
      diagnosis: t.diagnosis,
      medication: t.medication,
      status: t.status,
      startDate: t.startDate,
      attendingVet: t.attendingVet,
      notes: t.notes,
    })),
    recentCases: recentCases.map((t) => ({
      id: t.id,
      tag: t.tag,
      diagnosis: t.diagnosis,
      status: t.status,
      startDate: t.startDate,
      endDate: t.endDate,
      attendingVet: t.attendingVet,
    })),
  };
};

/* -------------------------------------------------------------------
 * Vaccination Report
 * ----------------------------------------------------------------- */

// Sourced from the Health module's VaccinationRecord table — no
// duplication in Dairy. We narrow to unit='Dairy' so the dairy report
// only shows whole-herd dairy vaccines (FMD, LSD, Anthrax, Brucellosis).
// Animal-id filter is a no-op because vaccinations are administered
// herd-wide; house/worker filters likewise (you don't vaccinate just
// one house). Filters apply only to the *upcoming* list when we can
// derive a per-cow expectation, but Phase 1 just shows herd-wide.
export const getVaccinationReport = async (filters = {}) => {
  const range = resolveRange(filters);

  // We need three slices:
  //   1. completed in window  (VaccinationRecord.administeredAt in range)
  //   2. completed previous window (for delta)
  //   3. upcoming / overdue: derive from active VaccineProtocols whose
  //      next-due falls in the future or just-past — same logic the
  //      Health page uses, but Dairy-scoped.
  const [recentRows, prevCount, dairyProtocols] = await Promise.all([
    prisma.vaccinationRecord.findMany({
      where: {
        unit: "Dairy",
        administeredAt: { gte: range.start, lte: range.end },
      },
      orderBy: { administeredAt: "desc" },
      include: { protocol: { select: { name: true } } },
    }),
    prisma.vaccinationRecord.count({
      where: {
        unit: "Dairy",
        administeredAt: { gte: range.prevStart, lte: range.prevEnd },
      },
    }),
    prisma.vaccineProtocol.findMany({
      where: { active: true, unit: "Dairy" },
      include: {
        records: { orderBy: { administeredAt: "desc" }, take: 1 },
      },
    }),
  ]);

  const completed = recentRows.length;
  const totalCows = await prisma.cow.count({
    where: { deletedAt: null, releasedAt: null },
  });

  // Per-protocol status. Rough heuristic — we're not duplicating the
  // health module's view computation here, just answering "is this
  // protocol overdue or imminent?". Annual protocols are overdue when
  // their last record is older than 12mo; recurring when older than
  // recurrenceMonths.
  const today = new Date();
  const monthMs = 30 * DAY_MS;
  let overdue = 0;
  let upcoming = 0;
  const schedules = [];
  const upcomingVaccinations = [];

  for (const p of dairyProtocols) {
    const last = p.records[0];
    const lastAt = last ? new Date(last.administeredAt) : null;
    const cadenceMonths = p.recurrenceMonths ?? 12;
    const nextDueAt = lastAt
      ? new Date(lastAt.getTime() + cadenceMonths * monthMs)
      : today; // never done → due now
    const daysUntilDue = Math.round((nextDueAt - today) / DAY_MS);
    let status;
    if (daysUntilDue < -7) {
      status = "OVERDUE";
      overdue += 1;
    } else if (daysUntilDue <= 30) {
      status = "DUE_SOON";
      upcoming += 1;
    } else {
      status = "OK";
    }
    schedules.push({
      protocolId: p.id,
      name: p.name,
      species: p.species,
      type: p.type,
      lastAdministeredAt: lastAt,
      nextDueAt,
      daysUntilDue,
      status,
    });
    if (status !== "OK") {
      upcomingVaccinations.push({
        protocolId: p.id,
        name: p.name,
        nextDueAt,
        daysUntilDue,
        status,
      });
    }
  }

  // Coverage: of active dairy protocols, what fraction is OK or DUE_SOON
  // (i.e. not OVERDUE). Treats "due soon but on schedule" as covered.
  const coveredCount = schedules.filter((s) => s.status !== "OVERDUE").length;
  const coveragePct =
    schedules.length > 0
      ? Number(((coveredCount / schedules.length) * 100).toFixed(1))
      : null;

  // Monthly trend across the window. Bucket by month for readability —
  // a daily chart for vaccinations is mostly empty.
  const monthBuckets = new Map();
  const monthLabel = (d) =>
    `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
  // Seed empty months in range.
  {
    const cur = new Date(range.start);
    cur.setDate(1);
    cur.setHours(0, 0, 0, 0);
    while (cur <= range.end) {
      monthBuckets.set(monthLabel(cur), {
        month: monthLabel(cur),
        count: 0,
      });
      cur.setMonth(cur.getMonth() + 1);
    }
  }
  for (const r of recentRows) {
    const key = monthLabel(new Date(r.administeredAt));
    const b = monthBuckets.get(key);
    if (b) b.count += 1;
  }

  const deltaPct =
    prevCount > 0
      ? Number((((completed - prevCount) / prevCount) * 100).toFixed(1))
      : null;

  return {
    period: {
      label: range.label,
      start: range.start,
      end: range.end,
      prevStart: range.prevStart,
      prevEnd: range.prevEnd,
    },
    filters: {
      animalId: filters.animalId ?? null,
      houseId: filters.houseId ?? null,
      workerId: filters.workerId ?? null,
    },
    totals: {
      completed,
      upcoming,
      overdue,
      coveragePct,
      activeCows: totalCows,
      prev: prevCount,
      deltaPct,
    },
    schedules,
    upcomingVaccinations: upcomingVaccinations.sort(
      (a, b) => a.daysUntilDue - b.daysUntilDue,
    ),
    recentVaccinations: recentRows.slice(0, 15).map((r) => ({
      id: r.id,
      vaccine: r.protocol?.name ?? r.vaccineName ?? "—",
      animalCount: r.animalCount,
      administeredAt: r.administeredAt,
      notes: r.notes,
    })),
    monthlyTrend: Array.from(monthBuckets.values()),
  };
};
