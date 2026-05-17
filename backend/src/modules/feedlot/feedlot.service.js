import prisma from "../../prisma/client.js";

const DAY_MS = 86_400_000;

// Bulls finish at 60 days on feed.
const FEED_TARGET_DAYS = 60;
// When days_left ≤ 14 we switch the status pill from "On feed" to a
// countdown ("13 days left"). Matches the HTML mockup behavior:
// BL-005 at 36d shows "On feed", BL-001 at 47d shows "13 days left".
const COUNTDOWN_THRESHOLD = 14;

const startOfDay = (d) => {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
};
const startOfMonth = (d) => new Date(d.getFullYear(), d.getMonth(), 1);
const startOfNextMonth = (d) => new Date(d.getFullYear(), d.getMonth() + 1, 1);

const daysSince = (date, now = new Date()) => {
  const ms = startOfDay(now).getTime() - startOfDay(date).getTime();
  return Math.max(0, Math.floor(ms / DAY_MS));
};

// Per-bull derived view used by GET /bulls and POST /bulls /weights responses.
//   adg          = (currentWeight - entryWeight) / max(daysOnFeed, 1)
//   daysOnFeed   = today - entryDate (in days)
//   status       = string label per the threshold rules above
//   daysLeft     = signed integer; negative = overdue
const computeBullView = (bull, now = new Date()) => {
  const daysOnFeed = daysSince(bull.entryDate, now);
  const adg =
    daysOnFeed === 0
      ? 0
      : Number(((bull.currentWeight - bull.entryWeight) / daysOnFeed).toFixed(2));

  const daysLeft = FEED_TARGET_DAYS - daysOnFeed;
  let status;
  if (daysLeft > COUNTDOWN_THRESHOLD) status = "On feed";
  else if (daysLeft > 0) status = `${daysLeft} days left`;
  else if (daysLeft === 0) status = "Due today";
  else status = `Overdue ${-daysLeft}d`;

  return {
    id: bull.id,
    tag: bull.tag,
    breed: bull.breed,
    entryDate: bull.entryDate,
    entryWeight: bull.entryWeight,
    currentWeight: bull.currentWeight,
    adg,
    daysOnFeed,
    daysLeft,
    status,
  };
};

//////////////////////////////////////////////////////
// KPIs
//////////////////////////////////////////////////////

// GET /api/feedlot/kpis
//   { bullsOnFeed, avgDaysOnFeed, doopersFlock, lambsThisMonth }
// Soft-deleted bulls and sheep are excluded.
export const getKpis = async () => {
  const now = new Date();
  const monthStart = startOfMonth(now);
  const monthEnd = startOfNextMonth(now);
  const notDeleted = { deletedAt: null };

  const [bulls, doopersFlock, lambsAgg] = await Promise.all([
    prisma.bull.findMany({ where: notDeleted, select: { entryDate: true } }),
    prisma.sheep.count({ where: notDeleted }),
    prisma.lambingRecord.aggregate({
      where: { date: { gte: monthStart, lt: monthEnd } },
      _sum: { lambsBorn: true },
    }),
  ]);

  const bullsOnFeed = bulls.length;
  const avgDaysOnFeed =
    bullsOnFeed === 0
      ? 0
      : Math.round(
          bulls.reduce((sum, b) => sum + daysSince(b.entryDate, now), 0) /
            bullsOnFeed,
        );

  return {
    bullsOnFeed,
    avgDaysOnFeed,
    doopersFlock,
    lambsThisMonth: lambsAgg._sum.lambsBorn ?? 0,
  };
};

//////////////////////////////////////////////////////
// BULLS
//////////////////////////////////////////////////////

// GET /api/feedlot/bulls — register table data with computed columns.
// Soft-deleted bulls are excluded.
export const listBulls = async () => {
  const bulls = await prisma.bull.findMany({
    where: { deletedAt: null, soldAt: null },
    orderBy: { entryDate: "asc" },
  });
  const now = new Date();
  return bulls.map((b) => computeBullView(b, now));
};

// POST /api/feedlot/bulls
export const createBull = async (input) => {
  const existing = await prisma.bull.findUnique({ where: { tag: input.tag } });
  if (existing) throw new Error("Bull with this tag already exists");

  const bull = await prisma.bull.create({
    data: {
      tag: input.tag.trim(),
      breed: input.breed.trim(),
      entryDate: input.entryDate,
      entryWeight: input.entryWeight,
      // No history yet — currentWeight matches entryWeight at registration.
      currentWeight: input.entryWeight,
    },
  });
  return computeBullView(bull);
};

//////////////////////////////////////////////////////
// WEIGHTS
//////////////////////////////////////////////////////

// POST /api/feedlot/weights
//
// Atomic transaction:
//   1. Verify the bull exists and isn't soft-deleted.
//   2. Insert the WeightRecord.
//   3. Update Bull.currentWeight = the new weight (most recent reading
//      becomes the bull's current weight, regardless of date — caller is
//      expected to record weights chronologically).
export const logWeight = async (input) => {
  const date = input.date ?? new Date();

  return prisma.$transaction(async (tx) => {
    const bull = await tx.bull.findUnique({ where: { id: input.bullId } });
    if (!bull || bull.deletedAt) throw new Error("Bull not found");

    await tx.weightRecord.create({
      data: { bullId: bull.id, weight: input.weight, date },
    });

    const updated = await tx.bull.update({
      where: { id: bull.id },
      data: { currentWeight: input.weight },
    });

    return computeBullView(updated);
  });
};

// PATCH /api/feedlot/bulls/:id
//
// Updates breed and/or currentWeight. When currentWeight changes, also
// creates a WeightRecord so the audit trail isn't lost when weight is
// edited via the pencil instead of the explicit `Log Weight` action.
export const updateBull = async (id, patch) => {
  return prisma.$transaction(async (tx) => {
    const bull = await tx.bull.findUnique({ where: { id } });
    if (!bull || bull.deletedAt) throw new Error("Bull not found");

    const data = {};
    if (patch.breed !== undefined) data.breed = patch.breed;
    if (
      patch.currentWeight !== undefined &&
      patch.currentWeight !== bull.currentWeight
    ) {
      data.currentWeight = patch.currentWeight;
      // Audit log entry — keeps the WeightRecord history coherent.
      await tx.weightRecord.create({
        data: {
          bullId: bull.id,
          weight: patch.currentWeight,
          date: new Date(),
        },
      });
    }

    const updated = await tx.bull.update({ where: { id }, data });
    return computeBullView(updated);
  });
};

// DELETE /api/feedlot/bulls/:id (soft).
export const softDeleteBull = async (id) => {
  const bull = await prisma.bull.findUnique({ where: { id } });
  if (!bull || bull.deletedAt) throw new Error("Bull not found");
  return prisma.bull.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
};

// Record a bull sale. Sets soldAt and the sale columns together —
// after this call the bull falls out of listBulls and KPIs since
// those filter on soldAt = null. Idempotency: re-selling an already
// sold bull is rejected so accidental double-tap doesn't overwrite
// the first sale record.
export const sellBull = async (id, sale) => {
  const bull = await prisma.bull.findUnique({ where: { id } });
  if (!bull || bull.deletedAt) throw new Error("Bull not found");
  if (bull.soldAt) throw new Error("Bull is already sold");
  return prisma.bull.update({
    where: { id },
    data: {
      soldAt: sale.saleDate ?? new Date(),
      soldWeightKg: sale.soldWeightKg,
      salePrice: sale.salePrice,
      buyerName: sale.buyerName,
      buyerPhone: sale.buyerPhone ?? null,
      paymentMethod: sale.paymentMethod ?? null,
      saleNotes: sale.saleNotes ?? null,
      receiptUrl: sale.receiptUrl ?? null,
    },
  });
};

//////////////////////////////////////////////////////
// SHEEP / DOOPERS
//////////////////////////////////////////////////////

// Per-sheep derived view used by GET /sheep and PATCH /sheep/:id
// responses. Mirrors computeBullView but without the 60-day target
// (doopers don't have a fixed disposal window).
//   adg          = (currentWeight - entryWeight) / max(daysOnFeed, 1)
//   daysOnFeed   = today - entryDate (in days)
// When entryWeight or currentWeight is missing, adg is returned as null
// so the UI can render "—" rather than a misleading 0.00.
const computeSheepView = (sheep, now = new Date()) => {
  const daysOnFeed = daysSince(sheep.entryDate, now);
  const hasBothWeights =
    sheep.entryWeight !== null && sheep.currentWeight !== null;
  const adg =
    !hasBothWeights || daysOnFeed === 0
      ? null
      : Number(
          ((sheep.currentWeight - sheep.entryWeight) / daysOnFeed).toFixed(2),
        );
  return {
    id: sheep.id,
    tag: sheep.tag,
    category: sheep.category,
    entryDate: sheep.entryDate,
    entryWeight: sheep.entryWeight,
    currentWeight: sheep.currentWeight,
    adg,
    daysOnFeed,
  };
};

// POST /api/feedlot/sheep — register one tagged sheep.
export const createSheep = async ({ tag, category, entryDate, entryWeight }) => {
  const existing = await prisma.sheep.findUnique({ where: { tag } });
  if (existing) throw new Error("Sheep with this tag already exists");
  const sheep = await prisma.sheep.create({
    data: {
      tag: tag.trim(),
      category,
      entryDate,
      entryWeight: entryWeight ?? null,
      // currentWeight starts at entryWeight (mirrors bulls). Stays null
      // when no entryWeight was provided — common for lambs born in flock.
      currentWeight: entryWeight ?? null,
    },
  });
  return computeSheepView(sheep);
};

// GET /api/feedlot/sheep — list non-deleted sheep with computed ADG /
// daysOnFeed columns, ordered by tag.
export const listSheep = async () => {
  const sheep = await prisma.sheep.findMany({
    where: { deletedAt: null },
    orderBy: { tag: "asc" },
    select: {
      id: true,
      tag: true,
      category: true,
      entryDate: true,
      entryWeight: true,
      currentWeight: true,
    },
  });
  const now = new Date();
  return sheep.map((s) => computeSheepView(s, now));
};

// PATCH /api/feedlot/sheep/:id
// Updates category and/or currentWeight. ADG is derived server-side
// from the new currentWeight against entryWeight on every read.
export const updateSheep = async (id, patch) => {
  const sheep = await prisma.sheep.findUnique({ where: { id } });
  if (!sheep || sheep.deletedAt) throw new Error("Sheep not found");

  const data = {};
  if (patch.category !== undefined) data.category = patch.category;
  if (patch.currentWeight !== undefined) {
    data.currentWeight = patch.currentWeight;
  }

  const updated = await prisma.sheep.update({ where: { id }, data });
  return computeSheepView(updated);
};

// DELETE /api/feedlot/sheep/:id (soft).
export const softDeleteSheep = async (id) => {
  const sheep = await prisma.sheep.findUnique({ where: { id } });
  if (!sheep || sheep.deletedAt) throw new Error("Sheep not found");
  return prisma.sheep.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
};

//////////////////////////////////////////////////////
// LAMBING
//////////////////////////////////////////////////////

// POST /api/feedlot/lambing
export const logLambing = async (input) => {
  return prisma.lambingRecord.create({
    data: {
      date: input.date ?? new Date(),
      lambsBorn: input.lambsBorn,
    },
  });
};

// GET /api/feedlot/lambing?month=YYYY-MM (or 'current')
export const listLambing = async ({ month }) => {
  const now = new Date();
  let start;
  if (month === "current") {
    start = startOfMonth(now);
  } else {
    const [y, m] = month.split("-").map(Number);
    start = new Date(y, m - 1, 1);
  }
  const end = startOfNextMonth(start);

  const records = await prisma.lambingRecord.findMany({
    where: { date: { gte: start, lt: end } },
    orderBy: { date: "asc" },
    select: { date: true, lambsBorn: true },
  });
  return records;
};

// =====================================================================
// FEEDLOT INVENTORY — bedding · equipment · veterinary · feed
// =====================================================================
//
// Mirrors the DairyInventoryItem service. Soft-delete via `deletedAt`.

const trimOrNullInv = (v) => {
  if (v === undefined || v === null) return null;
  if (typeof v !== "string") return v;
  const t = v.trim();
  return t.length === 0 ? null : t;
};

export const listFeedlotInventory = async () => {
  return prisma.feedlotInventoryItem.findMany({
    where: { deletedAt: null },
    orderBy: [{ category: "asc" }, { name: "asc" }],
  });
};

export const createFeedlotInventoryItem = async (input) => {
  return prisma.feedlotInventoryItem.create({
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

export const updateFeedlotInventoryItem = async (id, patch) => {
  const data = {};
  if (patch.name      !== undefined) data.name      = patch.name.trim();
  if (patch.category  !== undefined) data.category  = patch.category;
  if (patch.quantity  !== undefined) data.quantity  = patch.quantity;
  if (patch.unit      !== undefined) data.unit      = trimOrNullInv(patch.unit);
  if (patch.location  !== undefined) data.location  = trimOrNullInv(patch.location);
  if (patch.condition !== undefined) data.condition = trimOrNullInv(patch.condition);
  if (patch.notes     !== undefined) data.notes     = trimOrNullInv(patch.notes);
  return prisma.feedlotInventoryItem.update({ where: { id }, data });
};

export const softDeleteFeedlotInventoryItem = async (id) => {
  return prisma.feedlotInventoryItem.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
};
