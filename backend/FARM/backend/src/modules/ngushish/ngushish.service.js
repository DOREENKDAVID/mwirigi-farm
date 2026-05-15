import prisma from "../../prisma/client.js";

// Statuses that count as "active" in the dashboard KPI. Excludes
// HARVESTED, FAILED, and INFRASTRUCTURE (non-crop blocks).
const ACTIVE_CROP_STATUSES = [
  "PLANTED",
  "ACTIVE",
  "GROWING",
  "MATURING",
  "TASSELING",
  "READY_SOON",
  "READY",
  "AWAITING",
];

const startOfDay = (d) => {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
};
const startOfNextDay = (d) => {
  const x = startOfDay(d);
  x.setDate(x.getDate() + 1);
  return x;
};

// Used by createX endpoints to fail fast when the FK doesn't exist or
// points at a soft-deleted crop. Throws a normal Error — the controller
// maps "Crop not found" to 404.
const ensureCropExists = async (cropId, tx = prisma) => {
  const crop = await tx.crop.findUnique({ where: { id: cropId } });
  if (!crop || crop.deletedAt) throw new Error("Crop not found");
  return crop;
};

//////////////////////////////////////////////////////
// CROPS
//////////////////////////////////////////////////////

// GET /api/ngushish/crops
//
// Supports search (name contains), status filter, irrigated filter, and
// pagination. Soft-deleted rows are always excluded.
export const listCrops = async ({
  search,
  status,
  irrigated,
  page = 1,
  limit = 20,
}) => {
  const where = { deletedAt: null };
  if (search) where.name = { contains: search, mode: "insensitive" };
  if (status) where.status = status;
  if (typeof irrigated === "boolean") where.irrigated = irrigated;

  const skip = (page - 1) * limit;

  const [items, total] = await Promise.all([
    prisma.crop.findMany({
      where,
      orderBy: { createdAt: "desc" },
      skip,
      take: limit,
    }),
    prisma.crop.count({ where }),
  ]);

  return {
    items,
    pagination: {
      page,
      limit,
      total,
      pages: Math.ceil(total / limit),
    },
  };
};

// GET /api/ngushish/crops/:id
//
// Returns the crop with its harvest, dispatch, and irrigation history. We
// pull each relation ordered by date desc and capped at 100 — caller can
// hit the dedicated history endpoints for full pagination.
export const getCropById = async (id) => {
  const crop = await prisma.crop.findUnique({
    where: { id },
    include: {
      harvests: { orderBy: { harvestDate: "desc" }, take: 100 },
      dispatches: { orderBy: { dispatchDate: "desc" }, take: 100 },
      irrigation: { orderBy: { irrigationDate: "desc" }, take: 100 },
    },
  });
  if (!crop || crop.deletedAt) throw new Error("Crop not found");
  return crop;
};

// POST /api/ngushish/crops
export const createCrop = async (input) => {
  return prisma.crop.create({
    data: {
      name: input.name.trim(),
      acreage: input.acreage,
      plantedDate: input.plantedDate ?? null,
      expectedHarvest: input.expectedHarvest ?? null,
      harvestFrequency: input.harvestFrequency?.trim() ?? null,
      status: input.status,
      destination: input.destination?.trim() ?? null,
      notes: input.notes ?? null,
      isPerennial: input.isPerennial,
      irrigationType: input.irrigationType?.trim() ?? null,
      irrigated: input.irrigated,
      block: input.block?.trim() ?? null,
      age: input.age?.trim() ?? null,
      dueDate: input.dueDate ?? null,
      season: input.season?.trim() ?? null,
      actionNote: input.actionNote?.trim() ?? null,
    },
  });
};

// PATCH /api/ngushish/crops/:id
//
// Mass-assignment guard: we only forward the keys present in `patch`,
// so anything not in the validation schema is dropped.
export const updateCrop = async (id, patch) => {
  const crop = await prisma.crop.findUnique({ where: { id } });
  if (!crop || crop.deletedAt) throw new Error("Crop not found");

  const data = {};
  for (const key of [
    "name",
    "acreage",
    "plantedDate",
    "expectedHarvest",
    "harvestFrequency",
    "status",
    "destination",
    "notes",
    "isPerennial",
    "irrigationType",
    "irrigated",
    "block",
    "age",
    "dueDate",
    "season",
    "actionNote",
  ]) {
    if (patch[key] !== undefined) data[key] = patch[key];
  }

  return prisma.crop.update({ where: { id }, data });
};

// DELETE /api/ngushish/crops/:id
//
// Soft-delete only; downstream relations stay intact so historical
// reports keep working.
export const softDeleteCrop = async (id) => {
  const crop = await prisma.crop.findUnique({ where: { id } });
  if (!crop || crop.deletedAt) throw new Error("Crop not found");
  return prisma.crop.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
};

//////////////////////////////////////////////////////
// HARVESTS
//////////////////////////////////////////////////////

// POST /api/ngushish/harvests
export const createHarvest = async (input) => {
  return prisma.$transaction(async (tx) => {
    await ensureCropExists(input.cropId, tx);
    return tx.harvest.create({
      data: {
        cropId: input.cropId,
        quantityKg: input.quantityKg,
        harvestDate: input.harvestDate,
        qualityGrade: input.qualityGrade ?? null,
        notes: input.notes ?? null,
      },
    });
  });
};

// GET /api/ngushish/harvests
export const listHarvests = async ({
  cropId,
  from,
  to,
  page = 1,
  limit = 50,
}) => {
  const where = {};
  if (cropId) where.cropId = cropId;
  if (from || to) {
    where.harvestDate = {};
    if (from) where.harvestDate.gte = from;
    if (to) where.harvestDate.lte = to;
  }

  const skip = (page - 1) * limit;

  const [items, total] = await Promise.all([
    prisma.harvest.findMany({
      where,
      orderBy: { harvestDate: "desc" },
      skip,
      take: limit,
      include: { crop: { select: { id: true, name: true } } },
    }),
    prisma.harvest.count({ where }),
  ]);

  return {
    items,
    pagination: { page, limit, total, pages: Math.ceil(total / limit) },
  };
};

//////////////////////////////////////////////////////
// DISPATCHES
//////////////////////////////////////////////////////

// POST /api/ngushish/dispatches
export const createDispatch = async (input) => {
  return prisma.$transaction(async (tx) => {
    await ensureCropExists(input.cropId, tx);
    return tx.produceDispatch.create({
      data: {
        cropId: input.cropId,
        quantityKg: input.quantityKg,
        destination: input.destination.trim(),
        revenue: input.revenue,
        dispatchDate: input.dispatchDate,
        buyerName: input.buyerName?.trim() ?? null,
        transportCost: input.transportCost ?? null,
        notes: input.notes ?? null,
      },
    });
  });
};

// GET /api/ngushish/dispatches
export const listDispatches = async ({
  cropId,
  from,
  to,
  page = 1,
  limit = 50,
}) => {
  const where = {};
  if (cropId) where.cropId = cropId;
  if (from || to) {
    where.dispatchDate = {};
    if (from) where.dispatchDate.gte = from;
    if (to) where.dispatchDate.lte = to;
  }

  const skip = (page - 1) * limit;

  const [items, total] = await Promise.all([
    prisma.produceDispatch.findMany({
      where,
      orderBy: { dispatchDate: "desc" },
      skip,
      take: limit,
      include: { crop: { select: { id: true, name: true } } },
    }),
    prisma.produceDispatch.count({ where }),
  ]);

  return {
    items,
    pagination: { page, limit, total, pages: Math.ceil(total / limit) },
  };
};

//////////////////////////////////////////////////////
// IRRIGATION
//////////////////////////////////////////////////////

// POST /api/ngushish/irrigation
export const createIrrigationLog = async (input) => {
  return prisma.$transaction(async (tx) => {
    await ensureCropExists(input.cropId, tx);
    return tx.irrigationLog.create({
      data: {
        cropId: input.cropId,
        irrigationDate: input.irrigationDate,
        durationMinutes: input.durationMinutes ?? null,
        waterSource: input.waterSource?.trim() ?? null,
        notes: input.notes ?? null,
      },
    });
  });
};

// GET /api/ngushish/irrigation
export const listIrrigation = async ({
  cropId,
  from,
  to,
  page = 1,
  limit = 50,
}) => {
  const where = {};
  if (cropId) where.cropId = cropId;
  if (from || to) {
    where.irrigationDate = {};
    if (from) where.irrigationDate.gte = from;
    if (to) where.irrigationDate.lte = to;
  }

  const skip = (page - 1) * limit;

  const [items, total] = await Promise.all([
    prisma.irrigationLog.findMany({
      where,
      orderBy: { irrigationDate: "desc" },
      skip,
      take: limit,
      include: { crop: { select: { id: true, name: true } } },
    }),
    prisma.irrigationLog.count({ where }),
  ]);

  return {
    items,
    pagination: { page, limit, total, pages: Math.ceil(total / limit) },
  };
};

//////////////////////////////////////////////////////
// DASHBOARD
//////////////////////////////////////////////////////

// GET /api/ngushish/dashboard
//
//   activeCrops             — count of non-deleted crops in active statuses
//   irrigatedArea           — sum acreage where irrigated=true and not deleted
//   produceDispatchedTodayKg— today's total dispatched qty
//   revenueToday            — today's total revenue
//
// All four queries run in parallel for a single round-trip dashboard load.
export const getDashboardKpis = async (now = new Date()) => {
  const dayStart = startOfDay(now);
  const dayEnd = startOfNextDay(now);

  const [activeCrops, irrigatedAgg, dispatchedToday] = await Promise.all([
    prisma.crop.count({
      where: {
        deletedAt: null,
        status: { in: ACTIVE_CROP_STATUSES },
      },
    }),
    prisma.crop.aggregate({
      where: { deletedAt: null, irrigated: true },
      _sum: { acreage: true },
    }),
    prisma.produceDispatch.aggregate({
      where: { dispatchDate: { gte: dayStart, lt: dayEnd } },
      _sum: { quantityKg: true, revenue: true },
    }),
  ]);

  return {
    activeCrops,
    irrigatedArea: Number((irrigatedAgg._sum.acreage ?? 0).toFixed(2)),
    produceDispatchedTodayKg: Number(
      (dispatchedToday._sum.quantityKg ?? 0).toFixed(2),
    ),
    revenueToday: Number((dispatchedToday._sum.revenue ?? 0).toFixed(2)),
  };
};

// =====================================================================
// NGUSHISH INVENTORY (mirrors Dairy / Layers / Feedlot / Piggery inventory)
// =====================================================================

const trimOrNullInv = (v) => {
  if (v === undefined || v === null) return null;
  if (typeof v !== "string") return v;
  const t = v.trim();
  return t.length === 0 ? null : t;
};

export const listNgushishInventory = async () => {
  return prisma.ngushishInventoryItem.findMany({
    where: { deletedAt: null },
    orderBy: [{ category: "asc" }, { name: "asc" }],
  });
};

export const createNgushishInventoryItem = async (input) => {
  return prisma.ngushishInventoryItem.create({
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

export const updateNgushishInventoryItem = async (id, patch) => {
  const data = {};
  if (patch.name      !== undefined) data.name      = patch.name.trim();
  if (patch.category  !== undefined) data.category  = patch.category;
  if (patch.quantity  !== undefined) data.quantity  = patch.quantity;
  if (patch.unit      !== undefined) data.unit      = trimOrNullInv(patch.unit);
  if (patch.location  !== undefined) data.location  = trimOrNullInv(patch.location);
  if (patch.condition !== undefined) data.condition = trimOrNullInv(patch.condition);
  if (patch.notes     !== undefined) data.notes     = trimOrNullInv(patch.notes);
  return prisma.ngushishInventoryItem.update({ where: { id }, data });
};

export const softDeleteNgushishInventoryItem = async (id) => {
  return prisma.ngushishInventoryItem.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
};
