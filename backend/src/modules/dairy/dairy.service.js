import prisma from "../../prisma/client.js";

//////////////////////////////////////////////////////
// COW SERVICES
//////////////////////////////////////////////////////

// Statuses that require a `statusReason` — surfaces in the herd table
// and reports so the why is visible without joining Treatment.
const STATUSES_REQUIRING_REASON = new Set(["SICK", "DRY_OFF"]);

const assertStatusReasonIfRequired = (status, statusReason) => {
  if (!STATUSES_REQUIRING_REASON.has(status)) return;
  const trimmed = typeof statusReason === "string" ? statusReason.trim() : "";
  if (trimmed.length === 0) {
    throw new Error(`A reason is required when status is ${status}`);
  }
};

export const createCow = async (input) => {
  const tag = input.tag;
  const normalizedTag =
    tag.trim().charAt(0).toUpperCase() + tag.trim().slice(1).toLowerCase();

  assertStatusReasonIfRequired(input.status, input.statusReason);

  const existingCow = await prisma.cow.findUnique({
    where: { tag: normalizedTag },
  });

  if (existingCow) {
    throw new Error("Cow with this tag already exists");
  }

  // If a houseId was provided but no workerId, default the worker to
  // the one assigned to that house (via House.worker 1:1). Keeps the
  // operational link consistent on creation; admins can change it later.
  let resolvedWorkerId = input.workerId ?? null;
  if (!resolvedWorkerId && input.houseId) {
    const w = await prisma.worker.findUnique({
      where: { houseId: input.houseId },
    });
    if (w) resolvedWorkerId = w.id;
  }

  return prisma.cow.create({
    data: {
      tag: normalizedTag,
      breed: input.breed,
      dateOfBirth: input.dateOfBirth,
      status: input.status,
      statusReason: trimOrNull(input.statusReason),
      houseId: input.houseId ?? null,
      workerId: resolvedWorkerId,
      // Extended Register Cow fields. Coerce empty strings → null so
      // the DB doesn't store " ".
      nickname: trimOrNull(input.nickname),
      imageUrl: trimOrNull(input.imageUrl),
      breedOrigin: trimOrNull(input.breedOrigin),
      lactationNumber: input.lactationNumber ?? null,
      weightKg: input.weightKg ?? null,
      colorMarkings: trimOrNull(input.colorMarkings),
      acquisitionDate: input.acquisitionDate ?? null,
      acquisitionType: trimOrNull(input.acquisitionType),
      motherTag: trimOrNull(input.motherTag),
      fatherTag: trimOrNull(input.fatherTag),
      healthNotes: trimOrNull(input.healthNotes),
    },
    include: { house: true, worker: true },
  });
};

// Helper: empty/whitespace-only strings should become null so they
// don't pollute the DB or appear as "  " in the UI.
const trimOrNull = (v) => {
  if (v === undefined || v === null) return null;
  if (typeof v !== "string") return v;
  const s = v.trim();
  return s.length === 0 ? null : s;
};

// Returns each cow with two derived numbers used by the Cow records table:
//   todayLitres — sum of milk records dated today
//   weekAvg     — sum over the last 7 days divided by 7
// Uses a single round-trip: include only the last 7 days of milk records,
// then compute in JS.
//
// Filtering (controller forwards from query string):
//   workerId — exact match (null/'unassigned' both surfaced specially)
//   houseId  — exact match
//   search   — case-insensitive substring across tag / nickname / breed
// Filters compose with AND semantics — passing both narrows the result.
export const getAllCows = async ({
  workerId,
  houseId,
  search,
} = {}) => {
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);
  const endOfToday = new Date();
  endOfToday.setHours(23, 59, 59, 999);
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6);
  sevenDaysAgo.setHours(0, 0, 0, 0);

  // Active herd only — released cows live in history reports.
  const where = { releasedAt: null };
  if (workerId === "unassigned") {
    where.workerId = null;
  } else if (workerId) {
    where.workerId = workerId;
  }
  if (houseId === "unassigned") {
    where.houseId = null;
  } else if (houseId) {
    where.houseId = houseId;
  }
  if (search && search.trim().length > 0) {
    const q = search.trim();
    const or = [
      { tag: { contains: q, mode: "insensitive" } },
      { nickname: { contains: q, mode: "insensitive" } },
    ];
    // Breed is an enum — only include the equals clause when the
    // search term is itself a valid breed value (otherwise Prisma
    // rejects the whole query).
    const BREED_VALUES = new Set([
      "FRIESIAN",
      "AYRSHIRE",
      "JERSEY",
      "SAHIWAL",
      "CROSSBREED",
    ]);
    const upper = q.toUpperCase();
    if (BREED_VALUES.has(upper)) {
      or.push({ breed: { equals: upper } });
    }
    where.OR = or;
  }

  const cows = await prisma.cow.findMany({
    where,
    include: {
      house: { select: { id: true, name: true, color: true } },
      worker: { select: { id: true, name: true } },
      milkRecords: {
        where: { date: { gte: sevenDaysAgo, lte: endOfToday } },
        orderBy: { date: "desc" },
      },
      reproductionRecords: {
        where: { eventType: "CALVING", deletedAt: null },
        select: { id: true },
      },
    },
    orderBy: { tag: "asc" },
  });

  return cows.map((cow) => {
    let todayLitres = 0;
    let weekTotal = 0;
    for (const r of cow.milkRecords) {
      weekTotal += r.litres;
      if (r.date >= startOfToday && r.date <= endOfToday) {
        todayLitres += r.litres;
      }
    }
    const weekAvg = Number((weekTotal / 7).toFixed(2));
    const calvesLifetime = cow.reproductionRecords.length;
    return {
      ...cow,
      todayLitres,
      weekAvg,
      calvesLifetime,
      // Strip the relation arrays we only used for derivation.
      milkRecords: undefined,
      reproductionRecords: undefined,
    };
  });
};

export const getCowByTag = async (tag) => {
  const normalizedTag =
    tag.trim().charAt(0).toUpperCase() + tag.trim().slice(1).toLowerCase();
  return await prisma.cow.findUnique({
    where: { tag: normalizedTag },
    include: {
      house: true,
      worker: true,
      milkRecords: { orderBy: { date: "desc" }, take: 30 },
    },
  });
};

export const updateCow = async (tag, data) => {
  const normalizedTag =
    tag.trim().charAt(0).toUpperCase() + tag.trim().slice(1).toLowerCase();

  // If status is being changed to SICK / DRY_OFF, require a reason.
  // Use the incoming statusReason if provided, otherwise fall back to
  // whatever is already on the row so an existing reason isn't lost.
  if (data.status !== undefined && STATUSES_REQUIRING_REASON.has(data.status)) {
    const incomingReason =
      data.statusReason !== undefined
        ? data.statusReason
        : (await prisma.cow.findUnique({
            where: { tag: normalizedTag },
            select: { statusReason: true },
          }))?.statusReason;
    assertStatusReasonIfRequired(data.status, incomingReason);
  }

  // Only forward known fields so updates can't sneak past validation.
  const safe = {};
  for (const key of [
    "breed",
    "dateOfBirth",
    "status",
    "statusReason",
    "houseId",
    "workerId",
    // Extended Register Cow fields — same allowlist on update.
    "nickname",
    "imageUrl",
    "breedOrigin",
    "lactationNumber",
    "weightKg",
    "colorMarkings",
    "acquisitionDate",
    "acquisitionType",
    "motherTag",
    "fatherTag",
    "healthNotes",
  ]) {
    if (data[key] !== undefined) {
      // Trim string fields, coerce empty → null so PATCHing "" clears.
      const v = data[key];
      safe[key] = typeof v === "string" ? trimOrNull(v) : v;
    }
  }
  return prisma.cow.update({
    where: { tag: normalizedTag },
    data: safe,
    include: { house: true, worker: true },
  });
};

export const deleteCow = async (tag) => {
    const normalizedTag =
  tag.trim().charAt(0).toUpperCase() + tag.trim().slice(1).toLowerCase();
  return await prisma.cow.delete({
    where: { tag: normalizedTag },
  });
};

// Mark a cow as released from the active herd. The cow row stays
// (for milk-history reports) but releasedAt + releaseType etc. are
// set, so getAllCows / dashboards filter it out. authorizedById is
// taken from the JWT (controller passes req.user.id), not the body.
export const releaseCow = async (tag, payload, authorizedById) => {
  const normalizedTag =
    tag.trim().charAt(0).toUpperCase() + tag.trim().slice(1).toLowerCase();
  const cow = await prisma.cow.findUnique({ where: { tag: normalizedTag } });
  if (!cow) throw new Error("Cow not found");
  if (cow.releasedAt) throw new Error("Cow is already released");

  return prisma.cow.update({
    where: { tag: normalizedTag },
    data: {
      releasedAt: new Date(),
      releaseType: payload.releaseType,
      releaseDate: payload.releaseDate ?? new Date(),
      releaseDestination: trimOrNull(payload.destination),
      releaseReason: trimOrNull(payload.reason),
      releaseDocumentUrl: trimOrNull(payload.documentUrl),
      authorizedById,
    },
  });
};

//////////////////////////////////////////////////////
// MILK RECORD SERVICES
//////////////////////////////////////////////////////

// Accepts either { cowId } or { tag } (validated upstream). Looks up by
// whichever was provided and creates the milk record.
export const createMilkRecord = async ({ cowId, tag, litres, session, date, userId }) => {
  let resolvedCowId = cowId;

  if (!resolvedCowId) {
    const normalizedTag =
      tag.trim().charAt(0).toUpperCase() + tag.trim().slice(1).toLowerCase();
    const cow = await prisma.cow.findUnique({ where: { tag: normalizedTag } });
    if (!cow) throw new Error("Cow not found");
    resolvedCowId = cow.id;
  }

  return prisma.milkRecord.create({
    data: {
      cowId: resolvedCowId,
      litres,
      session,
      date,
      userId,
    },
  });
};

export const getMilkRecords = async () => {
  return await prisma.milkRecord.findMany({
    include: {
      cow: true,
      user: true,
    },
    orderBy: {
      date: "desc",
    },
  });
};

// Filter by the actual relation column. The route param is named `cowId`
// and is expected to be a UUID; we no longer treat it as a tag.
export const getMilkRecordsByCow = async (cowId) => {
  return prisma.milkRecord.findMany({
    where: { cowId },
    orderBy: { date: "desc" },
  });
};

export const deleteMilkRecord = async (id) => {
  return await prisma.milkRecord.delete({
    where: { id },
  });
};

//////////////////////////////////////////////////////
// DASHBOARD / SUMMARY SERVICES
//////////////////////////////////////////////////////

// Bounds for "today" in the server's local timezone.
const todayRange = () => {
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const end = new Date();
  end.setHours(23, 59, 59, 999);
  return { start, end };
};

// Full dashboard payload: counts + today's totals + last 10 records.
export const getDashboard = async () => {
  const { start, end } = todayRange();

  const [totalCows, milkAgg, recentRecords] = await Promise.all([
    prisma.cow.count(),
    prisma.milkRecord.aggregate({
      where: { date: { gte: start, lte: end } },
      _sum: { litres: true },
    }),
    prisma.milkRecord.findMany({
      take: 10,
      orderBy: { date: "desc" },
      include: { cow: { select: { id: true, tag: true, breed: true } } },
    }),
  ]);

  return {
    totalCows,
    milkToday: milkAgg._sum.litres ?? 0,
    recentRecords,
  };
};

// Compact summary card used by the Flutter dairy KPIs.
export const getSummary = async () => {
  const { start, end } = todayRange();

  const [totalCows, milkAgg, milkingTodayAgg] = await Promise.all([
    prisma.cow.count(),
    prisma.milkRecord.aggregate({
      where: { date: { gte: start, lte: end } },
      _sum: { litres: true },
    }),
    // Distinct cows that contributed milk today.
    prisma.milkRecord.findMany({
      where: { date: { gte: start, lte: end } },
      distinct: ["cowId"],
      select: { cowId: true },
    }),
  ]);

  const milkToday = milkAgg._sum.litres ?? 0;
  const milkingToday = milkingTodayAgg.length;
  const avgPerCow =
    milkingToday > 0 ? Number((milkToday / milkingToday).toFixed(2)) : 0;

  // AM / MID / PM split for the "AM: 487 · PM: 360" sub-line.
  const sessionRows = await prisma.milkRecord.groupBy({
    by: ["session"],
    where: { date: { gte: start, lte: end } },
    _sum: { litres: true },
  });
  const sessions = { AM: 0, MID: 0, PM: 0 };
  for (const r of sessionRows) {
    sessions[r.session] = r._sum.litres ?? 0;
  }

  // "In maternity" = cows with status PREGNANT, used by the KPI card.
  const inMaternity = await prisma.cow.count({
    where: { status: "PREGNANT" },
  });

  return {
    totalCows,
    milkingToday,
    milkToday,
    avgPerCow,
    sessions,
    inMaternity,
  };
};

//////////////////////////////////////////////////////
// WORKERS
//////////////////////////////////////////////////////

// List all dairy workers with their assigned-cow counts. Drives the
// worker-bar pills + the cow-records "filter by worker" pills.
export const getDairyWorkers = async () => {
  const workers = await prisma.worker.findMany({
    where: { unit: { in: ["Dairy", "DAIRY", "dairy"] } },
    orderBy: { name: "asc" },
    include: {
      house: { select: { id: true, name: true, color: true } },
      _count: { select: { cows: true } },
    },
  });
  return workers.map((w) => ({
    id: w.id,
    name: w.name,
    role: w.role,
    house: w.house,
    cowCount: w._count.cows,
  }));
};

// All cows assigned to one worker (workerId = direct assignment, not via
// house). Drives the cow-grid in the milk-logging worker view.
export const getCowsByWorkerId = async (workerId) => {
  return prisma.cow.findMany({
    where: { workerId },
    orderBy: { tag: "asc" },
    include: {
      house: { select: { id: true, name: true, color: true } },
    },
  });
};

//////////////////////////////////////////////////////
// HOUSES OVERVIEW (Phase 2a)
//////////////////////////////////////////////////////

// One row per dairy-relevant house (type=Dairy) plus the synthetic
// "Maternity" entry derived from cows in PREGNANT status without a
// physical maternity house. Returns:
//   { id, name, color, totalCows, milkingCount, litresToday, workers[] }
export const getHousesOverview = async () => {
  const { start, end } = todayRange();

  const [houses, maternityCount] = await Promise.all([
    prisma.house.findMany({
      where: { type: "Dairy" },
      orderBy: { name: "asc" },
      include: {
        worker: { select: { id: true, name: true } },
        cows: {
          select: {
            id: true,
            status: true,
            workerId: true,
            milkRecords: {
              where: { date: { gte: start, lte: end } },
              select: { litres: true },
            },
          },
        },
      },
    }),
    prisma.cow.count({ where: { status: "PREGNANT" } }),
  ]);

  const houseRows = houses.map((h) => {
    const totalCows = h.cows.length;
    const milkingCount = h.cows.filter((c) => c.status === "MILKING").length;
    const litresToday = Number(
      h.cows
        .reduce(
          (sum, c) => sum + c.milkRecords.reduce((s, r) => s + r.litres, 0),
          0,
        )
        .toFixed(1),
    );
    // Workers list combines: the house's default supervisor (House.worker)
    // and every distinct worker explicitly assigned to a cow in this
    // house. De-duped by id so a 1-worker house shows just one chip.
    const workers = new Map();
    if (h.worker) workers.set(h.worker.id, h.worker.name);
    for (const c of h.cows) {
      if (c.workerId && !workers.has(c.workerId)) {
        workers.set(c.workerId, null); // names filled below
      }
    }
    return {
      id: h.id,
      name: h.name,
      color: h.color,
      totalCows,
      milkingCount,
      litresToday,
      // Names get joined upstream so the synthetic Maternity row can
      // share the same shape.
      workerIds: Array.from(workers.keys()),
      status:
        totalCows === 0
          ? "EMPTY"
          : milkingCount === totalCows
            ? "ALL_MILKING"
            : milkingCount > 0
              ? "PARTIAL"
              : "DRY",
    };
  });

  // Resolve worker names for any IDs we collected (the per-cow workers
  // not on the house's default).
  const allWorkerIds = new Set(houseRows.flatMap((h) => h.workerIds));
  const workerLookup = new Map();
  if (allWorkerIds.size > 0) {
    const ws = await prisma.worker.findMany({
      where: { id: { in: Array.from(allWorkerIds) } },
      select: { id: true, name: true },
    });
    for (const w of ws) workerLookup.set(w.id, w.name);
  }

  const decorated = houseRows.map((h) => ({
    id: h.id,
    name: h.name,
    color: h.color,
    totalCows: h.totalCows,
    milkingCount: h.milkingCount,
    litresToday: h.litresToday,
    workers: h.workerIds.map((id) => ({
      id,
      name: workerLookup.get(id) ?? "—",
    })),
    status: h.status,
  }));

  // Synthetic Maternity card — not a real House row, but the HTML lists
  // it alongside houses with the awaiting-calving count.
  decorated.push({
    id: "__maternity__",
    name: "Maternity",
    color: "#854F0B",
    totalCows: maternityCount,
    milkingCount: 0,
    litresToday: 0,
    workers: [],
    status: "MATERNITY",
  });

  return decorated;
};

//////////////////////////////////////////////////////
// TODAY'S SESSIONS (Phase 2b)
//////////////////////////////////////////////////////

// Bounds for the trailing 7 days, ending yesterday — used as the basis
// for a cow's per-session 7-day average. We deliberately exclude today's
// reading so flagging is comparing today vs the *prior* week.
const trailing7DayRange = () => {
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);
  const start = new Date(startOfToday);
  start.setDate(start.getDate() - 7);
  const end = new Date(startOfToday);
  end.setMilliseconds(-1);
  return { start, end };
};

// Returns the per-worker / per-session view used by both the worker
// view (only that worker's row) and the manager view (all workers).
//
// Shape:
//   {
//     date: ISO,
//     belowAvgThreshold: 0.7,      // configurable
//     workers: [
//       {
//         id, name,
//         cowCount,
//         progress: { AM: {logged, total}, MID: {...}, PM: {...} },
//         totals:   { AM: 12, MID: 0, PM: 7, day: 19 },
//         cows: [
//           {
//             id, tag, name, status,
//             entries: { AM: 4.2, MID: null, PM: 3.1 },
//             avg: { AM: 5.0, MID: 4.6, PM: 3.8 },   // trailing-7-day avg per session
//             flagged: { AM: false, MID: false, PM: true },  // today vs avg
//           }
//         ],
//       }
//     ]
//   }
export const getTodaySessions = async ({
  belowAvgThreshold = 0.7,
} = {}) => {
  const { start: dayStart, end: dayEnd } = todayRange();
  const { start: weekStart, end: weekEnd } = trailing7DayRange();

  // Pull every dairy worker with their cows + the milk records we need
  // for both today (entries) and the prior 7 days (averages).
  const workers = await prisma.worker.findMany({
    where: { unit: { in: ["Dairy", "DAIRY", "dairy"] } },
    orderBy: { name: "asc" },
    include: {
      cows: {
        orderBy: { tag: "asc" },
        include: {
          milkRecords: {
            where: { date: { gte: weekStart, lte: dayEnd } },
            select: { litres: true, session: true, date: true },
          },
        },
      },
    },
  });

  const SESSIONS = ["AM", "MID", "PM"];

  const workerViews = workers.map((w) => {
    const cowViews = w.cows.map((cow) => {
      // Bucket records into today vs prior week, and per session.
      const entries = { AM: null, MID: null, PM: null };
      const weekTotals = { AM: 0, MID: 0, PM: 0 };
      const weekCounts = { AM: 0, MID: 0, PM: 0 };
      for (const r of cow.milkRecords) {
        if (r.date >= dayStart && r.date <= dayEnd) {
          // Most-recent record for this session wins (idempotent upsert).
          entries[r.session] = r.litres;
        } else if (r.date >= weekStart && r.date <= weekEnd) {
          weekTotals[r.session] += r.litres;
          weekCounts[r.session] += 1;
        }
      }
      const avg = {};
      const flagged = {};
      for (const s of SESSIONS) {
        avg[s] =
          weekCounts[s] > 0
            ? Number((weekTotals[s] / weekCounts[s]).toFixed(2))
            : 0;
        flagged[s] =
          entries[s] !== null &&
          avg[s] > 0 &&
          entries[s] < avg[s] * belowAvgThreshold;
      }
      return {
        id: cow.id,
        tag: cow.tag,
        // Local name shown in the milk-logging grid. Falls back to
        // tag when not set so existing rows render without empty
        // chips.
        nickname: cow.nickname ?? null,
        breed: cow.breed,
        status: cow.status,
        houseId: cow.houseId,
        entries,
        avg,
        flagged,
      };
    });

    const progress = {
      AM: { logged: 0, total: cowViews.length },
      MID: { logged: 0, total: cowViews.length },
      PM: { logged: 0, total: cowViews.length },
    };
    const totals = { AM: 0, MID: 0, PM: 0 };
    for (const c of cowViews) {
      for (const s of SESSIONS) {
        if (c.entries[s] !== null) {
          progress[s].logged += 1;
          totals[s] += c.entries[s];
        }
      }
    }
    const dayTotal = totals.AM + totals.MID + totals.PM;

    return {
      id: w.id,
      name: w.name,
      cowCount: cowViews.length,
      progress,
      totals: {
        AM: Number(totals.AM.toFixed(1)),
        MID: Number(totals.MID.toFixed(1)),
        PM: Number(totals.PM.toFixed(1)),
        day: Number(dayTotal.toFixed(1)),
      },
      cows: cowViews,
    };
  });

  return {
    date: dayStart.toISOString(),
    belowAvgThreshold,
    workers: workerViews,
  };
};

//////////////////////////////////////////////////////
// BULK SESSION SUBMIT (Phase 3)
//////////////////////////////////////////////////////

// POST /api/dairy/milk/sessions
//
// Atomic batch of milk readings for one (worker, date, session). For
// each entry we upsert keyed on (cowId, date-day, session) — re-submits
// overwrite the prior value rather than appending. Returns the updated
// today-sessions slice for that worker so the UI can refresh without a
// follow-up GET.
//
// Deductions (calf + household) live on FarmConfig and are surfaced
// upstream in the summary endpoint, not applied to individual records.
export const submitMilkSession = async ({
  workerId,
  session,
  date,
  entries,
  userId,
}) => {
  if (!Array.isArray(entries) || entries.length === 0) {
    throw new Error("entries must be a non-empty array");
  }

  const baseDate = date instanceof Date ? new Date(date) : new Date();
  // Normalize to midnight so two submits on the same day collide on the
  // upsert key regardless of submit time.
  baseDate.setHours(0, 0, 0, 0);

  return prisma.$transaction(async (tx) => {
    // Resolve cows in one round-trip + reject any that don't belong to
    // the submitting worker (catches mis-routed UI submits early).
    const cowIds = entries.map((e) => e.cowId);
    const cows = await tx.cow.findMany({
      where: { id: { in: cowIds } },
      select: { id: true, workerId: true, tag: true },
    });
    const cowMap = new Map(cows.map((c) => [c.id, c]));

    for (const e of entries) {
      const cow = cowMap.get(e.cowId);
      if (!cow) throw new Error(`Cow not found: ${e.cowId}`);
      if (workerId && cow.workerId && cow.workerId !== workerId) {
        throw new Error(
          `Cow ${cow.tag} is not assigned to this worker`,
        );
      }
    }

    // Upsert each entry. Idempotency key is (cowId, date, session) —
    // there's no compound unique index in the schema, so we do a
    // findFirst+update/create pattern inside the txn.
    for (const e of entries) {
      const litres = Number(e.litres);
      if (!Number.isFinite(litres) || litres <= 0 || litres > 100) continue;
      const existing = await tx.milkRecord.findFirst({
        where: { cowId: e.cowId, session, date: baseDate },
        select: { id: true },
      });
      if (existing) {
        await tx.milkRecord.update({
          where: { id: existing.id },
          data: {
            litres,
            ...(userId
              ? { user: { connect: { id: userId } } }
              : {}),
          },
        });
      } else {
        // Prisma 7 expects relation-form `cow: { connect }` rather than
        // the raw FK. `user` is required on MilkRecord — when no userId
        // (script context, unauthenticated submit), fall back to the
        // first available user so the FK satisfies.
        let recorderId = userId;
        if (!recorderId) {
          const fallback = await tx.user.findFirst({ select: { id: true } });
          recorderId = fallback?.id;
        }
        if (!recorderId) {
          throw new Error(
            "No user available to record milk session — create a user first",
          );
        }
        await tx.milkRecord.create({
          data: {
            cow: { connect: { id: e.cowId } },
            user: { connect: { id: recorderId } },
            litres,
            session,
            date: baseDate,
          },
        });
      }
    }
  });
};

//////////////////////////////////////////////////////
// TODAY'S NET (deductions applied)
//////////////////////////////////////////////////////

// Pulls calf + household deductions from FarmConfig (fall back to
// sensible defaults if no config exists yet) and returns gross / net
// for each session + the day. Used by the summary panel under the
// session tabs.
export const getTodayNetSummary = async () => {
  const { start, end } = todayRange();

  const [aggs, config] = await Promise.all([
    prisma.milkRecord.groupBy({
      by: ["session"],
      where: { date: { gte: start, lte: end } },
      _sum: { litres: true },
    }),
    prisma.farmConfig.findFirst(),
  ]);

  const gross = { AM: 0, MID: 0, PM: 0 };
  for (const r of aggs) {
    gross[r.session] = r._sum.litres ?? 0;
  }
  const dayGross = gross.AM + gross.MID + gross.PM;

  const calfDeduction = config?.calfDeduction ?? 5; // 5 calves × 1L by default
  const householdDeduct = config?.householdDeduct ?? 35; // ~35 L typical

  // Apply household + calf as a flat day-level deduction (HTML shows
  // these together in the bottom summary panel).
  const totalDeductions = calfDeduction + householdDeduct;
  const dayNet = Math.max(0, dayGross - totalDeductions);

  return {
    sessions: gross,
    deductions: {
      calf: calfDeduction,
      household: householdDeduct,
      total: totalDeductions,
    },
    dayGross: Number(dayGross.toFixed(1)),
    dayNet: Number(dayNet.toFixed(1)),
  };
};

//////////////////////////////////////////////////////
// 📈 DAILY MILK — 7-DAY TREND
//////////////////////////////////////////////////////
//
// Returns one row per day for the last 7 days (oldest first), each row
// is { date: ISO yyyy-mm-dd, dow: "Mon".."Sun", litres }. Drives the
// "Daily milk — 7 days" bar chart on the Dairy page.

export const getDailyMilkTrend = async ({ days = 7 } = {}) => {
  const today = new Date();
  today.setHours(23, 59, 59, 999);
  const start = new Date(today);
  start.setDate(start.getDate() - (days - 1));
  start.setHours(0, 0, 0, 0);

  // Fetch the raw records and aggregate in JS — Prisma's groupBy can't
  // easily project the `date` column to day-only, and the volume here
  // is small (a single farm × 7 days).
  const records = await prisma.milkRecord.findMany({
    where: { date: { gte: start, lte: today } },
    select: { date: true, litres: true },
  });

  const dowLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const buckets = [];
  for (let i = 0; i < days; i += 1) {
    const d = new Date(start);
    d.setDate(d.getDate() + i);
    const key = d.toISOString().slice(0, 10);
    buckets.push({
      date: key,
      dow: dowLabels[d.getDay()],
      litres: 0,
    });
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

//////////////////////////////////////////////////////
// 🐮 CALVES REGISTER
//////////////////////////////////////////////////////
//
// One row per CALVING ReproductionRecord. Joins the dam (mother) cow,
// and — when calfTag matches a Cow row in the herd — the calf cow too,
// so the UI can show the worker / house / image / nickname.
//
// Computed fields:
//   ageDays  — days between eventDate and today
//   stage    — "Newborn" (<7d) · "Calf" (<60d) · "Weaner" (<180d) · "Heifer/Steer" (≥180d)

const calfStageFromAgeDays = (days) => {
  if (days < 7)   return "Newborn";
  if (days < 60)  return "Calf";
  if (days < 180) return "Weaner";
  return "Heifer/Steer";
};

export const getCalvesRegister = async () => {
  const records = await prisma.reproductionRecord.findMany({
    where: { eventType: "CALVING", deletedAt: null },
    orderBy: { eventDate: "desc" },
    include: {
      cow: {
        select: {
          id: true,
          tag: true,
          nickname: true,
          breed: true,
          house: { select: { id: true, name: true, color: true } },
          worker: { select: { id: true, name: true } },
        },
      },
    },
  });

  // Try to resolve calfTag → Cow row so the UI can show the calf's photo
  // and current house/worker. Done in one batched query.
  const calfTags = records
    .map((r) => r.calfTag)
    .filter((t) => typeof t === "string" && t.trim().length > 0);

  const calfCows = calfTags.length
    ? await prisma.cow.findMany({
        where: { tag: { in: calfTags } },
        select: {
          id: true,
          tag: true,
          nickname: true,
          breed: true,
          dateOfBirth: true,
          imageUrl: true,
          status: true,
          house:  { select: { id: true, name: true, color: true } },
          worker: { select: { id: true, name: true } },
        },
      })
    : [];

  const calfByTag = new Map(calfCows.map((c) => [c.tag, c]));

  const today = new Date();
  return records.map((r) => {
    const ageMs   = today.getTime() - new Date(r.eventDate).getTime();
    const ageDays = Math.max(0, Math.floor(ageMs / 86_400_000));
    return {
      id: r.id,
      eventDate: r.eventDate,
      ageDays,
      stage: calfStageFromAgeDays(ageDays),
      calfTag: r.calfTag,
      calfSex: r.calfSex,
      calfBirthWeightKg: r.calfBirthWeightKg,
      calvingEase: r.calvingEase,
      calvingFate: r.calvingFate,
      sireCode: r.sireCode,
      notes: r.notes,
      dam: r.cow
        ? {
            id: r.cow.id,
            tag: r.cow.tag,
            nickname: r.cow.nickname,
            breed: r.cow.breed,
            houseName: r.cow.house?.name ?? null,
            houseColor: r.cow.house?.color ?? null,
            workerName: r.cow.worker?.name ?? null,
          }
        : null,
      calf: r.calfTag && calfByTag.has(r.calfTag)
        ? (() => {
            const c = calfByTag.get(r.calfTag);
            return {
              id: c.id,
              tag: c.tag,
              nickname: c.nickname,
              breed: c.breed,
              imageUrl: c.imageUrl,
              status: c.status,
              houseName: c.house?.name ?? null,
              houseColor: c.house?.color ?? null,
              workerName: c.worker?.name ?? null,
            };
          })()
        : null,
    };
  });
};

//////////////////////////////////////////////////////
// 📦 DAIRY INVENTORY
//////////////////////////////////////////////////////

export const getDairyInventory = async () => {
  return prisma.dairyInventoryItem.findMany({
    where: { deletedAt: null },
    orderBy: [{ category: "asc" }, { name: "asc" }],
  });
};

export const createDairyInventoryItem = async (input) => {
  return prisma.dairyInventoryItem.create({
    data: {
      name: input.name.trim(),
      category: input.category,
      quantity: input.quantity,
      unit: trimOrNull(input.unit),
      location: trimOrNull(input.location),
      condition: trimOrNull(input.condition),
      notes: trimOrNull(input.notes),
    },
  });
};

export const updateDairyInventoryItem = async (id, patch) => {
  const data = {};
  if (patch.name      !== undefined) data.name      = patch.name.trim();
  if (patch.category  !== undefined) data.category  = patch.category;
  if (patch.quantity  !== undefined) data.quantity  = patch.quantity;
  if (patch.unit      !== undefined) data.unit      = trimOrNull(patch.unit);
  if (patch.location  !== undefined) data.location  = trimOrNull(patch.location);
  if (patch.condition !== undefined) data.condition = trimOrNull(patch.condition);
  if (patch.notes     !== undefined) data.notes     = trimOrNull(patch.notes);
  return prisma.dairyInventoryItem.update({ where: { id }, data });
};

export const softDeleteDairyInventoryItem = async (id) => {
  return prisma.dairyInventoryItem.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
};