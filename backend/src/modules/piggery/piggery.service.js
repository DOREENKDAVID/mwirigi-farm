import prisma from "../../prisma/client.js";

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

const startOfMonth = (d) => new Date(d.getFullYear(), d.getMonth(), 1);
const startOfNextMonth = (d) => new Date(d.getFullYear(), d.getMonth() + 1, 1);

// ── Lifecycle constants ──
const GESTATION_DAYS = 114;
const LACTATING_WINDOW_DAYS = 28;
const FARROWING_SOON_WINDOW_DAYS = 14;

const DAY_MS = 86_400_000;

// House config — static metadata mirroring the v4.2 HTML mockup. Returned
// from listHouses with computed counts merged in.
export const PIG_HOUSES = {
  A:  { label: "House A",   role: "Main farrowing & late gestation",  manager: "Simiyu",    pens: 14 },
  B:  { label: "House B",   role: "Gestation + service + dry sows",   manager: "Simiyu",    pens: 16 },
  C:  { label: "House C",   role: "AI farrowing & nursery",           manager: "Simiyu",    pens: 17 },
  D:  { label: "House D",   role: "Gestation + boars + spare capacity", manager: "David",   pens: 20 },
  E:  { label: "House E",   role: "Fattening (Beaconners building weight)", manager: "David", pens: 20 },
  F:  { label: "House F",   role: "Finishing (final stage before FC)", manager: "Sam Bwira", pens: 20 },
  EM: { label: "Emergency", role: "Emergency / isolation",            manager: "Simiyu",    pens: 4  },
};

// Derive the effective sow status. Honors explicit DRY/SERVICE (the master
// register stores these directly), otherwise computes from lifecycle dates.
export const deriveStatus = (pig, now = new Date()) => {
  if (pig.status === "DRY" || pig.status === "SERVICE") return pig.status;

  const lf = pig.lastFarrowed?.getTime();
  const dd = pig.dueDate?.getTime();
  const t = now.getTime();

  if (lf != null && t - lf <= LACTATING_WINDOW_DAYS * DAY_MS) {
    return "LACTATING";
  }
  if (pig.status === "LACTATING") return "LACTATING";
  if (dd != null) {
    const daysUntil = (dd - t) / DAY_MS;
    if (daysUntil <= FARROWING_SOON_WINDOW_DAYS) return "FARROWING_SOON";
    return "GESTATING";
  }
  if (lf != null && t - lf > LACTATING_WINDOW_DAYS * DAY_MS) {
    return "WEANED";
  }
  return pig.status ?? null;
};

//////////////////////////////////////////////////////
// KPIs
//////////////////////////////////////////////////////

// GET /api/piggery/kpis
//   {
//     totalPigs, totalSows, totalBoars, pigletsMTD, farrowingDue,
//     activeLitters, pigletsOnMilk, saleReady, monthlyBeaconners,
//     totalHead
//   }
export const getKpis = async () => {
  const now = new Date();
  const monthStart = startOfMonth(now);
  const nextMonth = startOfNextMonth(now);
  const horizon = endOfDay(now);
  horizon.setDate(horizon.getDate() + 14);
  const notDeleted = { deletedAt: null };

  const [
    totalPigs,
    totalSows,
    totalBoars,
    mtdAgg,
    farrowingDue,
    litterStats,
    saleReadyAgg,
    eHeadAgg,
    fHeadAgg,
    nurseryHeadAgg,
    monthBeaAgg,
  ] = await Promise.all([
    prisma.pig.count({ where: notDeleted }),
    prisma.pig.count({ where: { ...notDeleted, category: "SOW" } }),
    prisma.pig.count({ where: { ...notDeleted, category: "BOAR" } }),
    prisma.farrowingRecord.aggregate({
      where: { date: { gte: monthStart, lt: nextMonth }, sow: notDeleted },
      _sum: { pigletsBorn: true },
    }),
    prisma.pig.count({
      where: {
        ...notDeleted,
        category: "SOW",
        dueDate: { gte: startOfDay(now), lte: horizon },
      },
    }),
    prisma.litter.aggregate({
      where: notDeleted,
      _count: { _all: true },
      _sum: { count: true },
    }),
    prisma.fattenPen.aggregate({
      where: { ...notDeleted, saleReady: true },
      _sum: { count: true },
    }),
    prisma.fattenPen.aggregate({
      where: { ...notDeleted, house: "E" },
      _sum: { count: true },
    }),
    prisma.fattenPen.aggregate({
      where: { ...notDeleted, house: "F" },
      _sum: { count: true },
    }),
    prisma.nurseryGroup.aggregate({
      where: notDeleted,
      _sum: { count: true },
    }),
    prisma.farrowingRecord.aggregate({
      where: { date: { gte: monthStart, lt: nextMonth }, sow: notDeleted },
      _sum: { beaconners: true },
    }),
  ]);

  const activeLitters = litterStats._count._all ?? 0;
  const pigletsOnMilk = litterStats._sum.count ?? 0;
  const eHead = eHeadAgg._sum.count ?? 0;
  const fHead = fHeadAgg._sum.count ?? 0;
  const nurseryHead = nurseryHeadAgg._sum.count ?? 0;

  return {
    totalPigs,
    totalSows,
    totalBoars,
    pigletsMTD: mtdAgg._sum.pigletsBorn ?? 0,
    farrowingDue,
    activeLitters,
    pigletsOnMilk,
    saleReady: saleReadyAgg._sum.count ?? 0,
    monthlyBeaconners: monthBeaAgg._sum.beaconners ?? 0,
    // Sows + boars + piglets on milk + nursery + fattening + finishing.
    totalHead: totalSows + totalBoars + pigletsOnMilk + nurseryHead + eHead + fHead,
  };
};

//////////////////////////////////////////////////////
// HOUSES
//////////////////////////////////////////////////////

// GET /api/piggery/houses
// Returns the 7 house tiles with live counts merged in.
export const listHouses = async () => {
  const notDeleted = { deletedAt: null };
  const [sows, boars, litterAgg, eAgg, fAgg] = await Promise.all([
    prisma.pig.findMany({
      where: { ...notDeleted, category: "SOW" },
      select: { house: true, status: true },
    }),
    prisma.pig.findMany({
      where: { ...notDeleted, category: "BOAR" },
      select: { house: true },
    }),
    prisma.litter.findMany({
      where: notDeleted,
      select: { count: true, sow: { select: { house: true } } },
    }),
    prisma.fattenPen.aggregate({
      where: { ...notDeleted, house: "E" },
      _sum: { count: true },
    }),
    prisma.fattenPen.aggregate({
      where: { ...notDeleted, house: "F" },
      _sum: { count: true },
    }),
  ]);

  const counts = {};
  for (const code of Object.keys(PIG_HOUSES)) {
    counts[code] = { sows: 0, boars: 0, litters: 0, piglets: 0 };
  }
  for (const s of sows) {
    if (s.house && counts[s.house]) counts[s.house].sows += 1;
  }
  for (const b of boars) {
    if (b.house && counts[b.house]) counts[b.house].boars += 1;
  }
  for (const l of litterAgg) {
    const h = l.sow?.house;
    if (h && counts[h]) {
      counts[h].litters += 1;
      counts[h].piglets += l.count ?? 0;
    }
  }

  return Object.entries(PIG_HOUSES).map(([code, info]) => {
    let count;
    let subline;
    if (code === "E") {
      count = eAgg._sum.count ?? 0;
      subline = "Fatteners";
    } else if (code === "F") {
      count = fAgg._sum.count ?? 0;
      subline = "Finishers";
    } else {
      const c = counts[code];
      count = c.sows;
      const parts = [];
      if (c.boars > 0) parts.push(`${c.boars} boar${c.boars > 1 ? "s" : ""}`);
      if (c.litters > 0) parts.push(`${c.litters} litter${c.litters > 1 ? "s" : ""}`);
      subline = parts.length ? parts.join(" · ") : "Sows";
    }
    return {
      code,
      label: info.label,
      role: info.role,
      manager: info.manager,
      pens: info.pens,
      count,
      subline,
      sows: counts[code].sows,
      boars: counts[code].boars,
      litters: counts[code].litters,
      piglets: counts[code].piglets,
    };
  });
};

//////////////////////////////////////////////////////
// SOW REGISTER
//////////////////////////////////////////////////////

// GET /api/piggery/sows?search=&house=&status=
export const listSows = async ({ search, house, status } = {}) => {
  const where = { category: "SOW", deletedAt: null };
  if (search && search.trim()) {
    where.tag = { contains: search.trim(), mode: "insensitive" };
  }
  if (house) where.house = house;

  const sows = await prisma.pig.findMany({
    where,
    orderBy: [{ house: "asc" }, { pen: "asc" }, { tag: "asc" }],
    select: {
      id: true,
      tag: true,
      house: true,
      pen: true,
      status: true,
      litterCount: true,
      lastFarrowed: true,
      dueDate: true,
      serviceDate: true,
      expFarrow: true,
      note: true,
      litters: {
        where: { deletedAt: null },
        select: { litterId: true, count: true, born: true },
        take: 1,
      },
    },
  });

  const now = new Date();
  const out = sows.map((s) => {
    const litter = s.litters?.[0];
    return {
      id: s.id,
      tag: s.tag,
      house: s.house,
      pen: s.pen,
      status: deriveStatus(s, now),
      litterCount: s.litterCount,
      lastFarrowed: s.lastFarrowed,
      dueDate: s.dueDate,
      serviceDate: s.serviceDate,
      expFarrow: s.expFarrow,
      note: s.note,
      litterId: litter?.litterId ?? null,
      pigletCount: litter?.count ?? null,
      born: litter?.born ?? null,
    };
  });

  return status ? out.filter((s) => s.status === status) : out;
};

//////////////////////////////////////////////////////
// BOAR REGISTER
//////////////////////////////////////////////////////

// GET /api/piggery/boars
export const listBoars = async () => {
  return prisma.pig.findMany({
    where: { category: "BOAR", deletedAt: null },
    orderBy: { tag: "asc" },
    select: {
      id: true,
      tag: true,
      house: true,
      pen: true,
      breed: true,
      age: true,
      role: true,
    },
  });
};

//////////////////////////////////////////////////////
// LITTERS
//////////////////////////////////////////////////////

// GET /api/piggery/litters — currently-active litters, newest first.
export const listLitters = async () => {
  const litters = await prisma.litter.findMany({
    where: { deletedAt: null },
    orderBy: [{ born: "desc" }, { litterId: "asc" }],
    select: {
      id: true,
      litterId: true,
      born: true,
      count: true,
      note: true,
      sow: {
        select: { id: true, tag: true, pen: true, house: true },
      },
    },
  });
  return litters.map((l) => ({
    id: l.id,
    litterId: l.litterId,
    born: l.born,
    count: l.count,
    note: l.note,
    sowId: l.sow?.id ?? null,
    sowTag: l.sow?.tag ?? null,
    pen: l.sow?.pen ?? null,
    house: l.sow?.house ?? null,
  }));
};

//////////////////////////////////////////////////////
// NURSERY
//////////////////////////////////////////////////////

// GET /api/piggery/nursery
export const listNursery = async () => {
  return prisma.nurseryGroup.findMany({
    where: { deletedAt: null },
    orderBy: { pen: "asc" },
  });
};

//////////////////////////////////////////////////////
// FATTENING (House E) + FINISHING (House F)
//////////////////////////////////////////////////////

// GET /api/piggery/fattening
export const listFattening = async () => {
  return prisma.fattenPen.findMany({
    where: { house: "E", deletedAt: null },
    orderBy: { pen: "asc" },
  });
};

// GET /api/piggery/finishing
export const listFinishing = async () => {
  return prisma.fattenPen.findMany({
    where: { house: "F", deletedAt: null },
    orderBy: { pen: "asc" },
  });
};

//////////////////////////////////////////////////////
// MONTHLY PIGLET TREND
//////////////////////////////////////////////////////

export const getTrend = async ({ months }) => {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth() - (months - 1), 1);
  const end = startOfNextMonth(now);

  const records = await prisma.farrowingRecord.findMany({
    where: { date: { gte: start, lt: end }, sow: { deletedAt: null } },
    select: { date: true, pigletsBorn: true, beaconners: true },
  });

  const buckets = new Map();
  for (let i = 0; i < months; i += 1) {
    const d = new Date(start);
    d.setMonth(start.getMonth() + i);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
    buckets.set(key, { piglets: 0, beaconners: 0 });
  }
  for (const r of records) {
    const d = r.date;
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
    const b = buckets.get(key);
    if (b) {
      b.piglets += r.pigletsBorn;
      b.beaconners += r.beaconners ?? 0;
    }
  }

  return Array.from(buckets.entries()).map(([month, v]) => ({
    month,
    piglets: v.piglets,
    beaconners: v.beaconners,
  }));
};

// GET /api/piggery/farrowing — paginated farrowing records, newest first.
export const listFarrowing = async ({ limit = 50 } = {}) => {
  const rows = await prisma.farrowingRecord.findMany({
    where: { sow: { deletedAt: null } },
    orderBy: { date: "desc" },
    take: limit,
    select: {
      id: true,
      date: true,
      service: true,
      pigletsBorn: true,
      pigletsAlive: true,
      pigletsDead: true,
      winners: true,
      fatteners: true,
      beaconners: true,
      remarks: true,
      sow: { select: { id: true, tag: true } },
    },
  });
  return rows.map((r) => ({
    id: r.id,
    date: r.date,
    service: r.service,
    pigletsBorn: r.pigletsBorn,
    pigletsAlive: r.pigletsAlive,
    pigletsDead: r.pigletsDead,
    winners: r.winners,
    fatteners: r.fatteners,
    beaconners: r.beaconners,
    remarks: r.remarks,
    sowId: r.sow?.id ?? null,
    sowTag: r.sow?.tag ?? null,
  }));
};

//////////////////////////////////////////////////////
// CREATE PIG
//////////////////////////////////////////////////////

export const createPig = async (input) => {
  const existing = await prisma.pig.findUnique({ where: { tag: input.tag } });
  if (existing) throw new Error("Pig with this tag already exists");

  const isSow = input.category === "SOW";
  return prisma.pig.create({
    data: {
      tag: input.tag.trim(),
      category: input.category,
      status: isSow ? input.status ?? null : null,
      litterCount: isSow ? input.litterCount ?? 0 : 0,
      lastFarrowed: isSow ? input.lastFarrowed ?? null : null,
      dueDate: isSow ? input.dueDate ?? null : null,
      house: input.house ?? null,
      pen: input.pen ?? null,
      serviceDate: input.serviceDate ?? null,
      expFarrow: input.expFarrow ?? null,
      breed: input.breed ?? null,
      age: input.age ?? null,
      role: input.role ?? null,
      note: input.note ?? null,
    },
  });
};

//////////////////////////////////////////////////////
// LOG FARROWING
//////////////////////////////////////////////////////

export const logFarrowing = async (input) => {
  const date = input.date ?? new Date();
  const nextDueDate = new Date(date);
  nextDueDate.setDate(nextDueDate.getDate() + GESTATION_DAYS);

  return prisma.$transaction(async (tx) => {
    const sow = await tx.pig.findUnique({ where: { id: input.sowId } });
    if (!sow) throw new Error("Sow not found");
    if (sow.deletedAt) throw new Error("Sow has been deleted");
    if (sow.category !== "SOW") {
      throw new Error("Only sows can have farrowing records");
    }

    const record = await tx.farrowingRecord.create({
      data: {
        sowId: sow.id,
        date,
        pigletsBorn: input.pigletsBorn,
        pigletsAlive: input.pigletsAlive,
        pigletsDead: input.pigletsDead,
        winners: input.winners ?? null,
        fatteners: input.fatteners ?? null,
        beaconners: input.beaconners ?? null,
        remarks: input.remarks ?? null,
        service: input.service ?? null,
      },
    });

    await tx.pig.update({
      where: { id: sow.id },
      data: {
        litterCount: { increment: 1 },
        lastFarrowed: date,
        status: "LACTATING",
        dueDate: nextDueDate,
      },
    });

    return record;
  });
};

//////////////////////////////////////////////////////
// UPDATE / SOFT DELETE
//////////////////////////////////////////////////////

export const updatePig = async (id, patch) => {
  const existing = await prisma.pig.findUnique({ where: { id } });
  if (!existing || existing.deletedAt) throw new Error("Pig not found");

  const data = {};
  for (const k of [
    "status",
    "dueDate",
    "litterCount",
    "house",
    "pen",
    "serviceDate",
    "expFarrow",
    "breed",
    "age",
    "role",
    "note",
  ]) {
    if (k in patch) data[k] = patch[k];
  }

  return prisma.pig.update({ where: { id }, data });
};

export const softDeletePig = async (id) => {
  const existing = await prisma.pig.findUnique({ where: { id } });
  if (!existing || existing.deletedAt) throw new Error("Pig not found");
  return prisma.pig.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
};

// =====================================================================
// LITTER CRUD
// =====================================================================

export const createLitter = async (input) => {
  return prisma.litter.create({
    data: {
      litterId: input.litterId.trim(),
      sowId: input.sowId,
      born: input.born ?? null,
      count: input.count ?? 0,
      note: input.note ?? null,
    },
  });
};

export const updateLitter = async (id, patch) => {
  const data = {};
  if ("litterId" in patch) data.litterId = patch.litterId;
  if ("sowId" in patch) data.sowId = patch.sowId;
  if ("born" in patch) data.born = patch.born;
  if ("count" in patch) data.count = patch.count;
  if ("note" in patch) data.note = patch.note;
  return prisma.litter.update({ where: { id }, data });
};

export const softDeleteLitter = async (id) => {
  return prisma.litter.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
};

// =====================================================================
// NURSERY GROUP CRUD
// =====================================================================

export const createNurseryGroup = async (input) => {
  return prisma.nurseryGroup.create({
    data: {
      pen: input.pen.trim(),
      count: input.count,
      age: input.age ?? null,
      born: input.born ?? null,
      breed: input.breed ?? null,
      note: input.note ?? null,
    },
  });
};

export const updateNurseryGroup = async (id, patch) => {
  const data = {};
  if ("pen" in patch) data.pen = patch.pen;
  if ("count" in patch) data.count = patch.count;
  if ("age" in patch) data.age = patch.age;
  if ("born" in patch) data.born = patch.born;
  if ("breed" in patch) data.breed = patch.breed;
  if ("note" in patch) data.note = patch.note;
  return prisma.nurseryGroup.update({ where: { id }, data });
};

export const softDeleteNurseryGroup = async (id) => {
  return prisma.nurseryGroup.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
};

// =====================================================================
// FATTEN PEN CRUD (House E + F)
// =====================================================================

export const createFattenPen = async (input) => {
  return prisma.fattenPen.create({
    data: {
      pen: input.pen.trim(),
      house: input.house,
      count: input.count,
      age: input.age ?? null,
      saleReady: input.saleReady ?? false,
      saleWindow: input.saleWindow ?? null,
    },
  });
};

export const updateFattenPen = async (id, patch) => {
  const data = {};
  if ("pen" in patch) data.pen = patch.pen;
  if ("house" in patch) data.house = patch.house;
  if ("count" in patch) data.count = patch.count;
  if ("age" in patch) data.age = patch.age;
  if ("saleReady" in patch) data.saleReady = patch.saleReady;
  if ("saleWindow" in patch) data.saleWindow = patch.saleWindow;
  return prisma.fattenPen.update({ where: { id }, data });
};

export const softDeleteFattenPen = async (id) => {
  return prisma.fattenPen.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
};

// =====================================================================
// PIGGERY INVENTORY
// =====================================================================

const trimOrNullInv = (v) => {
  if (v === undefined || v === null) return null;
  if (typeof v !== "string") return v;
  const t = v.trim();
  return t.length === 0 ? null : t;
};

export const listPiggeryInventory = async () => {
  return prisma.piggeryInventoryItem.findMany({
    where: { deletedAt: null },
    orderBy: [{ category: "asc" }, { name: "asc" }],
  });
};

export const createPiggeryInventoryItem = async (input) => {
  return prisma.piggeryInventoryItem.create({
    data: {
      name: input.name.trim(),
      category: input.category,
      quantity: input.quantity,
      unit: trimOrNullInv(input.unit),
      location: trimOrNullInv(input.location),
      condition: trimOrNullInv(input.condition),
      notes: trimOrNullInv(input.notes),
    },
  });
};

export const updatePiggeryInventoryItem = async (id, patch) => {
  const data = {};
  if (patch.name      !== undefined) data.name      = patch.name.trim();
  if (patch.category  !== undefined) data.category  = patch.category;
  if (patch.quantity  !== undefined) data.quantity  = patch.quantity;
  if (patch.unit      !== undefined) data.unit      = trimOrNullInv(patch.unit);
  if (patch.location  !== undefined) data.location  = trimOrNullInv(patch.location);
  if (patch.condition !== undefined) data.condition = trimOrNullInv(patch.condition);
  if (patch.notes     !== undefined) data.notes     = trimOrNullInv(patch.notes);
  return prisma.piggeryInventoryItem.update({ where: { id }, data });
};

export const softDeletePiggeryInventoryItem = async (id) => {
  return prisma.piggeryInventoryItem.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
};
