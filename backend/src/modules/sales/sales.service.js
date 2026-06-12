import prisma from "../../prisma/client.js";
import { writeAuditLog } from "../../utils/audit.js";

// Revenue category mapping per sale module
const REVENUE_CATEGORY = {
  LAYERS: "EGG_SALES",
  DAIRY: "MILK_SALES",
};

const UNIT_LABEL = {
  LAYERS: "crates",
  DAIRY: "L",
};

const FINANCE_UNIT = {
  LAYERS: "Layers",
  DAIRY: "Dairy",
};

// ── helpers ──────────────────────────────────────────────────────────────

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

// ── list ──────────────────────────────────────────────────────────────────

// GET /api/sales
// Returns a page of sales rows, newest first. Supports filtering by
// module, buyerType, paymentMode, and date range.
export const listSales = async ({
  module,
  buyerType,
  paymentMode,
  startDate,
  endDate,
  limit,
  offset,
}) => {
  const where = {};
  if (module) where.module = module;
  if (buyerType) where.buyerType = buyerType;
  if (paymentMode) where.paymentMode = paymentMode;
  if (startDate || endDate) {
    where.saleDate = {};
    if (startDate) where.saleDate.gte = startOfDay(startDate);
    if (endDate) where.saleDate.lte = endOfDay(endDate);
  }

  const [total, rows] = await Promise.all([
    prisma.productSale.count({ where }),
    prisma.productSale.findMany({
      where,
      orderBy: { saleDate: "desc" },
      take: limit,
      skip: offset,
      include: {
        createdBy: { select: { id: true, userName: true } },
      },
    }),
  ]);

  return { total, rows };
};

// ── create ────────────────────────────────────────────────────────────────

// POST /api/sales
// Atomically creates a ProductSale row + a Revenue row (Finance integration).
// Also writes an AuditLog entry.
export const createSale = async (input, actorId) => {
  const saleDate = input.saleDate ?? new Date();
  const unitLabel = UNIT_LABEL[input.module];

  return prisma.$transaction(async (tx) => {
    // 1. Auto-create a Finance Revenue row when amountPaid > 0.
    let revenueId = null;
    if (input.amountPaid > 0) {
      const rev = await tx.revenue.create({
        data: {
          unit: FINANCE_UNIT[input.module],
          category: REVENUE_CATEGORY[input.module],
          amount: input.amountPaid,
          quantity: input.quantity,
          unitLabel,
          date: saleDate,
          notes: [
            input.buyerName,
            `${input.quantity} ${unitLabel}`,
            input.paymentMode,
            input.paymentReference ? `ref: ${input.paymentReference}` : null,
            input.notes,
          ]
            .filter(Boolean)
            .join(" · "),
          createdById: actorId ?? null,
        },
      });
      revenueId = rev.id;
    }

    // 2. Create the sale record.
    const sale = await tx.productSale.create({
      data: {
        module: input.module,
        saleDate,
        quantity: input.quantity,
        unitLabel,
        buyerType: input.buyerType,
        buyerName: input.buyerName,
        paymentMode: input.paymentMode,
        paymentReference: input.paymentReference ?? null,
        amountPaid: input.amountPaid,
        notes: input.notes ?? null,
        revenueId,
        createdById: actorId ?? null,
      },
    });

    // 3. Audit log.
    await writeAuditLog(tx, {
      entity: "ProductSale",
      entityId: sale.id,
      action: "CREATE",
      actorId: actorId ?? null,
      module: input.module === "LAYERS" ? "Layers" : "Dairy",
      snapshot: {
        quantity: sale.quantity,
        unitLabel: sale.unitLabel,
        buyerName: sale.buyerName,
        amountPaid: sale.amountPaid,
        paymentMode: sale.paymentMode,
      },
    });

    return sale;
  });
};

// ── update ────────────────────────────────────────────────────────────────

// PATCH /api/sales/:id
// Updates the sale and, when amountPaid changed, patches the linked Revenue.
export const updateSale = async (id, patch, actorId) => {
  const existing = await prisma.productSale.findUnique({
    where: { id },
    include: { revenue: true },
  });
  if (!existing) throw new Error("Sale not found");

  return prisma.$transaction(async (tx) => {
    // Patch the Revenue row when amountPaid or quantity or date changed.
    if (existing.revenueId) {
      const revPatch = {};
      if (patch.amountPaid !== undefined) revPatch.amount = patch.amountPaid;
      if (patch.quantity !== undefined) revPatch.quantity = patch.quantity;
      if (patch.saleDate !== undefined) revPatch.date = patch.saleDate;
      if (patch.notes !== undefined || patch.buyerName !== undefined) {
        const buyer = patch.buyerName ?? existing.buyerName;
        const qty = patch.quantity ?? existing.quantity;
        const mode = patch.paymentMode ?? existing.paymentMode;
        const ref = patch.paymentReference ?? existing.paymentReference;
        const notes = patch.notes ?? existing.notes;
        revPatch.notes = [
          buyer,
          `${qty} ${existing.unitLabel}`,
          mode,
          ref ? `ref: ${ref}` : null,
          notes,
        ]
          .filter(Boolean)
          .join(" · ");
      }
      if (Object.keys(revPatch).length > 0) {
        await tx.revenue.update({ where: { id: existing.revenueId }, data: revPatch });
      }
    }

    const updated = await tx.productSale.update({
      where: { id },
      data: {
        ...(patch.saleDate !== undefined && { saleDate: patch.saleDate }),
        ...(patch.quantity !== undefined && { quantity: patch.quantity }),
        ...(patch.buyerType !== undefined && { buyerType: patch.buyerType }),
        ...(patch.buyerName !== undefined && { buyerName: patch.buyerName }),
        ...(patch.paymentMode !== undefined && { paymentMode: patch.paymentMode }),
        ...(patch.paymentReference !== undefined && { paymentReference: patch.paymentReference }),
        ...(patch.amountPaid !== undefined && { amountPaid: patch.amountPaid }),
        ...(patch.notes !== undefined && { notes: patch.notes }),
      },
    });

    await writeAuditLog(tx, {
      entity: "ProductSale",
      entityId: id,
      action: "UPDATE",
      actorId: actorId ?? null,
      module: existing.module === "LAYERS" ? "Layers" : "Dairy",
      snapshot: patch,
    });

    return updated;
  });
};

// ── delete ────────────────────────────────────────────────────────────────

// DELETE /api/sales/:id
// Hard-deletes the sale. The linked Revenue row is preserved (Finance
// needs the history) but its `sale` back-reference is cleared automatically
// via the onDelete: SetNull cascade on revenueId.
export const deleteSale = async (id, actorId) => {
  const existing = await prisma.productSale.findUnique({ where: { id } });
  if (!existing) throw new Error("Sale not found");

  await prisma.$transaction(async (tx) => {
    await tx.productSale.delete({ where: { id } });

    await writeAuditLog(tx, {
      entity: "ProductSale",
      entityId: id,
      action: "DELETE",
      actorId: actorId ?? null,
      module: existing.module === "LAYERS" ? "Layers" : "Dairy",
      snapshot: { buyerName: existing.buyerName, amountPaid: existing.amountPaid },
    });
  });
};

// ── summary KPIs ──────────────────────────────────────────────────────────

// Returns today's sale totals per module. Used by the KPI strip.
export const getSalesSummary = async (module) => {
  const now = new Date();
  const start = startOfDay(now);
  const end = endOfDay(now);

  const rows = await prisma.productSale.findMany({
    where: { module, saleDate: { gte: start, lte: end } },
    select: { quantity: true, amountPaid: true },
  });

  const totalQuantity = rows.reduce((s, r) => s + r.quantity, 0);
  const totalRevenue = rows.reduce((s, r) => s + r.amountPaid, 0);
  return { totalQuantity, totalRevenue, count: rows.length };
};
