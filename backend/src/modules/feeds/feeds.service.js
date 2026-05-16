import prisma from "../../prisma/client.js";
import {
  FEED_STATUS,
  calculateDaysLeft,
  decorateMaterial,
  determineFeedStatus,
} from "./feeds.utils.js";

//////////////////////////////////////////////////////
// MATERIALS
//////////////////////////////////////////////////////

// GET /feeds/materials
//
// Status filtering is done in JS rather than SQL because `status` is a
// computed field. The DB filters by name/category/etc to keep the working
// set small, then we decorate + filter, then paginate. With <500 active
// materials this stays cheap (single SELECT, no extra round-trips).
//
// Soft-deleted materials are always excluded.
export const listMaterials = async ({
  search,
  status,
  category,
  page = 1,
  limit = 50,
}) => {
  const where = { deletedAt: null };
  if (search) where.name = { contains: search, mode: "insensitive" };
  if (category) where.category = category;

  const all = await prisma.feedMaterial.findMany({
    where,
    orderBy: { name: "asc" },
  });

  const decorated = all.map(decorateMaterial);
  const filtered = status
    ? decorated.filter((m) => m.status === status)
    : decorated;

  const total = filtered.length;
  const skip = (page - 1) * limit;
  const items = filtered.slice(skip, skip + limit);

  return {
    items,
    pagination: {
      page,
      limit,
      total,
      pages: Math.max(1, Math.ceil(total / limit)),
    },
  };
};

export const getMaterialById = async (id) => {
  const m = await prisma.feedMaterial.findUnique({ where: { id } });
  if (!m || m.deletedAt) throw new Error("Material not found");
  return decorateMaterial(m);
};

// POST /feeds/materials
//
// `name` is @unique, so a soft-deleted row with the same name would
// block re-creation. If the existing row is soft-deleted we revive it
// (and reset its stock/dailyUse to the new payload) instead of
// throwing — this matches typical "undo delete then re-add" expectations.
export const createMaterial = async (input) => {
  const existing = await prisma.feedMaterial.findUnique({
    where: { name: input.name },
  });
  if (existing && !existing.deletedAt) {
    throw new Error("Material with this name already exists");
  }
  if (existing && existing.deletedAt) {
    const revived = await prisma.feedMaterial.update({
      where: { id: existing.id },
      data: {
        deletedAt: null,
        category: input.category,
        packSize: input.packSize.trim(),
        stockOnHandKg: input.stockOnHandKg ?? 0,
        dailyUseKg: input.dailyUseKg ?? 0,
        reorderLevelDays: input.reorderLevelDays ?? 5,
        supplier: input.supplier?.trim() ?? null,
        costPerKg: input.costPerKg ?? null,
      },
    });
    return decorateMaterial(revived);
  }

  const m = await prisma.feedMaterial.create({
    data: {
      name: input.name.trim(),
      category: input.category,
      packSize: input.packSize.trim(),
      stockOnHandKg: input.stockOnHandKg ?? 0,
      dailyUseKg: input.dailyUseKg ?? 0,
      reorderLevelDays: input.reorderLevelDays ?? 5,
      supplier: input.supplier?.trim() ?? null,
      costPerKg: input.costPerKg ?? null,
    },
  });
  return decorateMaterial(m);
};

// PATCH /feeds/materials/:id
//
// Mass-assignment guarded — only listed metadata fields are forwarded.
// stockOnHandKg / dailyUseKg are intentionally absent (deliveries +
// consumption mutate them so the audit history stays coherent).
export const updateMaterial = async (id, patch) => {
  const m = await prisma.feedMaterial.findUnique({ where: { id } });
  if (!m || m.deletedAt) throw new Error("Material not found");

  const data = {};
  for (const key of [
    "name",
    "category",
    "packSize",
    "reorderLevelDays",
    "supplier",
    "costPerKg",
  ]) {
    if (patch[key] !== undefined) data[key] = patch[key];
  }

  const updated = await prisma.feedMaterial.update({
    where: { id },
    data,
  });
  return decorateMaterial(updated);
};

// DELETE /feeds/materials/:id (soft).
//
// History (deliveries + consumption logs) stays intact so reports keep
// working; the row simply disappears from the inventory list and KPI
// counts.
export const softDeleteMaterial = async (id) => {
  const m = await prisma.feedMaterial.findUnique({ where: { id } });
  if (!m || m.deletedAt) throw new Error("Material not found");
  return prisma.feedMaterial.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
};

//////////////////////////////////////////////////////
// DELIVERIES
//////////////////////////////////////////////////////

// POST /feeds/deliveries
//
// Atomic: insert the delivery and bump stockOnHandKg in one transaction
// so a partial failure can't desync stock.
export const createDelivery = async (input, userId = null) => {
  return prisma.$transaction(async (tx) => {
    const material = await tx.feedMaterial.findUnique({
      where: { id: input.materialId },
    });
    if (!material || material.deletedAt) {
      throw new Error("Material not found");
    }

    const delivery = await tx.feedDelivery.create({
      data: {
        materialId: material.id,
        quantityKg: input.quantityKg,
        unitCost: input.unitCost ?? null,
        supplier: input.supplier?.trim() ?? null,
        invoiceNumber: input.invoiceNumber?.trim() ?? null,
        deliveredAt: input.deliveredAt,
        notes: input.notes ?? null,
        createdById: userId,
      },
    });

    await tx.feedMaterial.update({
      where: { id: material.id },
      data: { stockOnHandKg: { increment: input.quantityKg } },
    });

    return delivery;
  });
};

// GET /feeds/deliveries
export const listDeliveries = async ({
  materialId,
  from,
  to,
  page = 1,
  limit = 50,
}) => {
  const where = {};
  if (materialId) where.materialId = materialId;
  if (from || to) {
    where.deliveredAt = {};
    if (from) where.deliveredAt.gte = from;
    if (to) where.deliveredAt.lte = to;
  }

  const skip = (page - 1) * limit;

  const [items, total] = await Promise.all([
    prisma.feedDelivery.findMany({
      where,
      orderBy: { deliveredAt: "desc" },
      skip,
      take: limit,
      include: {
        material: { select: { id: true, name: true, packSize: true } },
      },
    }),
    prisma.feedDelivery.count({ where }),
  ]);

  return {
    items,
    pagination: {
      page,
      limit,
      total,
      pages: Math.max(1, Math.ceil(total / limit)),
    },
  };
};

//////////////////////////////////////////////////////
// CONSUMPTION
//////////////////////////////////////////////////////

// POST /feeds/consumption
//
// Atomic: write the log and update FeedMaterial.dailyUseKg in one
// transaction. The new daily-use figure becomes the live consumption
// rate going forward.
export const createConsumptionLog = async (input, userId = null) => {
  const calculatedDailyUseKg = input.quantityUsedKg / input.durationDays;

  return prisma.$transaction(async (tx) => {
    const material = await tx.feedMaterial.findUnique({
      where: { id: input.materialId },
    });
    if (!material || material.deletedAt) {
      throw new Error("Material not found");
    }

    const log = await tx.feedConsumptionLog.create({
      data: {
        materialId: material.id,
        quantityUsedKg: input.quantityUsedKg,
        durationDays: input.durationDays,
        calculatedDailyUseKg,
        notes: input.notes ?? null,
        createdById: userId,
      },
    });

    await tx.feedMaterial.update({
      where: { id: material.id },
      data: { dailyUseKg: calculatedDailyUseKg },
    });

    return log;
  });
};

// POST /feeds/consumption/bulk
//
// Apply many consumption updates in a single transaction. If any one
// entry references an unknown / soft-deleted material the whole batch
// rolls back — partial updates are not allowed.
//
// Returns the list of newly-created log rows in the same order as the
// input so the UI can correlate entries with results.
export const createBulkConsumptionLogs = async (entries, userId = null) => {
  return prisma.$transaction(async (tx) => {
    const created = [];
    for (const e of entries) {
      const material = await tx.feedMaterial.findUnique({
        where: { id: e.materialId },
      });
      if (!material || material.deletedAt) {
        throw new Error(`Material not found: ${e.materialId}`);
      }
      const calculatedDailyUseKg = e.quantityUsedKg / e.durationDays;
      const log = await tx.feedConsumptionLog.create({
        data: {
          materialId: material.id,
          quantityUsedKg: e.quantityUsedKg,
          durationDays: e.durationDays,
          calculatedDailyUseKg,
          notes: e.notes ?? null,
          createdById: userId,
        },
      });
      await tx.feedMaterial.update({
        where: { id: material.id },
        data: { dailyUseKg: calculatedDailyUseKg },
      });
      created.push(log);
    }
    return created;
  });
};

//////////////////////////////////////////////////////
// BULK FEED
//////////////////////////////////////////////////////

// GET /feeds/bulk-feed
export const listBulkFeed = async () => {
  return prisma.bulkFeedStock.findMany({ orderBy: { type: "asc" } });
};

// PATCH /feeds/bulk-feed/:id
export const updateBulkFeed = async (id, patch) => {
  const found = await prisma.bulkFeedStock.findUnique({ where: { id } });
  if (!found) throw new Error("Bulk feed entry not found");

  const data = {};
  for (const key of ["quantity", "unit", "status", "notes"]) {
    if (patch[key] !== undefined) data[key] = patch[key];
  }

  return prisma.bulkFeedStock.update({ where: { id }, data });
};

//////////////////////////////////////////////////////
// DISTRIBUTION
//////////////////////////////////////////////////////

// GET /feeds/distribution
//
// Returns the latest row per livestockUnit. We pull rows ordered by
// recordedAt DESC and dedupe in JS — keeps the query simple and avoids
// a per-unit subquery.
export const listDistribution = async () => {
  const rows = await prisma.feedDistribution.findMany({
    orderBy: { recordedAt: "desc" },
  });
  const seen = new Set();
  const latest = [];
  for (const r of rows) {
    if (seen.has(r.livestockUnit)) continue;
    seen.add(r.livestockUnit);
    latest.push(r);
  }
  return latest;
};

// POST /feeds/distribution
//
// Upsert keyed on `livestockUnit`. Two POSTs for DAIRY won't append —
// the second replaces the first. The createdAt timestamps form the
// audit trail.
export const upsertDistribution = async (input) => {
  const existing = await prisma.feedDistribution.findFirst({
    where: { livestockUnit: input.livestockUnit },
    orderBy: { recordedAt: "desc" },
  });

  const data = {
    livestockUnit: input.livestockUnit,
    concentrateKg: input.concentrateKg ?? 0,
    silageKg: input.silageKg ?? 0,
    napierKg: input.napierKg ?? 0,
    animalCount: input.animalCount ?? 0,
    recordedAt: input.recordedAt ?? new Date(),
  };

  if (existing) {
    return prisma.feedDistribution.update({
      where: { id: existing.id },
      data,
    });
  }
  return prisma.feedDistribution.create({ data });
};

//////////////////////////////////////////////////////
// DASHBOARD
//////////////////////////////////////////////////////

// GET /feeds/dashboard
//
//   materialsTracked — total active materials
//   critical / low / adequate — bucket counts using computed status
export const getDashboardKpis = async () => {
  const all = await prisma.feedMaterial.findMany({
    where: { deletedAt: null },
    select: {
      stockOnHandKg: true,
      dailyUseKg: true,
      reorderLevelDays: true,
    },
  });

  let critical = 0;
  let low = 0;
  let adequate = 0;

  for (const m of all) {
    const days = calculateDaysLeft(m.stockOnHandKg, m.dailyUseKg);
    const status = determineFeedStatus(days, m.reorderLevelDays);
    if (status === FEED_STATUS.CRITICAL) critical += 1;
    else if (status === FEED_STATUS.LOW) low += 1;
    else adequate += 1;
  }

  return {
    materialsTracked: all.length,
    critical,
    low,
    adequate,
  };
};
