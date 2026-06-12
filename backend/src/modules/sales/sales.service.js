import prisma from "../../prisma/client.js";
import { writeAuditLog } from "../../utils/audit.js";

// ── module → finance mapping ──────────────────────────────────────────────

const REVENUE_CATEGORY = {
  LAYERS: "EGG_SALES",
  DAIRY:  "MILK_SALES",
};

const UNIT_LABEL = {
  LAYERS: "crates",
  DAIRY:  "L",
};

const FINANCE_UNIT = {
  LAYERS: "Layers",
  DAIRY:  "Dairy",
};

const assertMapped = (module) => {
  if (!REVENUE_CATEGORY[module]) {
    throw new Error(
      `Sale module "${module}" has no Finance mapping. ` +
      `Add it to REVENUE_CATEGORY, UNIT_LABEL, and FINANCE_UNIT.`,
    );
  }
};

// ── helpers ───────────────────────────────────────────────────────────────

const startOfDay = (d) => { const x = new Date(d); x.setHours(0,0,0,0); return x; };
const endOfDay   = (d) => { const x = new Date(d); x.setHours(23,59,59,999); return x; };

const buildRevenueNotes = ({ buyerName, quantity, unitLabel, paymentMode, paymentReference, notes }) =>
  [buyerName, `${quantity} ${unitLabel}`, paymentMode, paymentReference ? `ref: ${paymentReference}` : null, notes]
    .filter(Boolean)
    .join(" · ");

// ── list ──────────────────────────────────────────────────────────────────

export const listSales = async ({ module, buyerType, paymentMode, startDate, endDate, limit, offset }) => {
  const where = {};
  if (module)    where.module    = module;
  if (buyerType) where.buyerType = buyerType;
  if (paymentMode) where.paymentMode = paymentMode;
  if (startDate || endDate) {
    where.saleDate = {};
    if (startDate) where.saleDate.gte = startOfDay(startDate);
    if (endDate)   where.saleDate.lte = endOfDay(endDate);
  }

  const [total, rows] = await Promise.all([
    prisma.productSale.count({ where }),
    prisma.productSale.findMany({
      where,
      orderBy: { saleDate: "desc" },
      take: limit,
      skip: offset,
      include: { createdBy: { select: { id: true, userName: true } } },
    }),
  ]);

  return { total, rows };
};

// ── create ────────────────────────────────────────────────────────────────

export const createSale = async (input, actorId) => {
  assertMapped(input.module);

  const saleDate  = input.saleDate ?? new Date();
  const unitLabel = UNIT_LABEL[input.module];

  return prisma.$transaction(async (tx) => {
    // 1. Create Revenue row when money was actually received.
    let revenueId = null;
    if (input.amountPaid > 0) {
      const rev = await tx.revenue.create({
        data: {
          unit:        FINANCE_UNIT[input.module],
          category:    REVENUE_CATEGORY[input.module],
          amount:      input.amountPaid,
          quantity:    input.quantity,
          unitLabel,
          date:        saleDate,
          notes:       buildRevenueNotes({ ...input, unitLabel }),
          createdById: actorId ?? null,
        },
      });
      revenueId = rev.id;
    }

    // 2. Create the sale, linking to Revenue (or null when unpaid).
    const sale = await tx.productSale.create({
      data: {
        module:           input.module,
        saleDate,
        quantity:         input.quantity,
        unitLabel,
        buyerType:        input.buyerType,
        buyerName:        input.buyerName,
        paymentMode:      input.paymentMode,
        paymentReference: input.paymentReference ?? null,
        amountPaid:       input.amountPaid,
        notes:            input.notes ?? null,
        revenueId,
        createdById:      actorId ?? null,
      },
    });

    // 3. Audit trail.
    await writeAuditLog(tx, {
      entity:   "ProductSale",
      entityId: sale.id,
      action:   "CREATE",
      actorId:  actorId ?? null,
      module:   FINANCE_UNIT[input.module],
      snapshot: { quantity: sale.quantity, unitLabel: sale.unitLabel, buyerName: sale.buyerName, amountPaid: sale.amountPaid, paymentMode: sale.paymentMode },
    });

    return sale;
  });
};

// ── update ────────────────────────────────────────────────────────────────

export const updateSale = async (id, patch, actorId) => {
  const existing = await prisma.productSale.findUnique({
    where: { id },
    include: { revenue: true },
  });
  if (!existing) throw new Error("Sale not found");

  const newAmount = patch.amountPaid ?? existing.amountPaid;

  return prisma.$transaction(async (tx) => {
    let revenueId = existing.revenueId;

    if (existing.revenueId) {
      if (newAmount <= 0) {
        // Amount zeroed out — unlink the Revenue row (preserve it for audit,
        // just remove the Sale→Revenue foreign key).
        revenueId = null;
      } else {
        // Patch the existing Revenue row to stay in sync.
        const buyer  = patch.buyerName        ?? existing.buyerName;
        const qty    = patch.quantity          ?? existing.quantity;
        const mode   = patch.paymentMode       ?? existing.paymentMode;
        const ref    = patch.paymentReference  ?? existing.paymentReference;
        const notes  = patch.notes             ?? existing.notes;

        const revPatch = {};
        if (patch.amountPaid !== undefined) revPatch.amount   = patch.amountPaid;
        if (patch.quantity   !== undefined) revPatch.quantity = patch.quantity;
        if (patch.saleDate   !== undefined) revPatch.date     = patch.saleDate;
        // Rebuild notes whenever any display field changes.
        if (patch.amountPaid !== undefined || patch.quantity !== undefined ||
            patch.buyerName  !== undefined || patch.paymentMode !== undefined ||
            patch.paymentReference !== undefined || patch.notes !== undefined) {
          revPatch.notes = buildRevenueNotes({ buyerName: buyer, quantity: qty, unitLabel: existing.unitLabel, paymentMode: mode, paymentReference: ref, notes });
        }
        if (Object.keys(revPatch).length > 0) {
          await tx.revenue.update({ where: { id: existing.revenueId }, data: revPatch });
        }
      }
    } else if (newAmount > 0) {
      // Sale was created unpaid (amountPaid = 0) and is now being paid —
      // create the missing Revenue row and link it.
      const saleDate = patch.saleDate ?? existing.saleDate;
      const qty      = patch.quantity ?? existing.quantity;
      const buyer    = patch.buyerName ?? existing.buyerName;
      const mode     = patch.paymentMode ?? existing.paymentMode;
      const ref      = patch.paymentReference ?? existing.paymentReference;
      const notes    = patch.notes ?? existing.notes;

      const rev = await tx.revenue.create({
        data: {
          unit:        FINANCE_UNIT[existing.module],
          category:    REVENUE_CATEGORY[existing.module],
          amount:      newAmount,
          quantity:    qty,
          unitLabel:   existing.unitLabel,
          date:        saleDate,
          notes:       buildRevenueNotes({ buyerName: buyer, quantity: qty, unitLabel: existing.unitLabel, paymentMode: mode, paymentReference: ref, notes }),
          createdById: actorId ?? null,
        },
      });
      revenueId = rev.id;
    }

    const updated = await tx.productSale.update({
      where: { id },
      data: {
        ...(patch.saleDate           !== undefined && { saleDate: patch.saleDate }),
        ...(patch.quantity           !== undefined && { quantity: patch.quantity }),
        ...(patch.buyerType          !== undefined && { buyerType: patch.buyerType }),
        ...(patch.buyerName          !== undefined && { buyerName: patch.buyerName }),
        ...(patch.paymentMode        !== undefined && { paymentMode: patch.paymentMode }),
        ...(patch.paymentReference   !== undefined && { paymentReference: patch.paymentReference }),
        ...(patch.amountPaid         !== undefined && { amountPaid: patch.amountPaid }),
        ...(patch.notes              !== undefined && { notes: patch.notes }),
        revenueId,
      },
    });

    await writeAuditLog(tx, {
      entity:   "ProductSale",
      entityId: id,
      action:   "UPDATE",
      actorId:  actorId ?? null,
      module:   FINANCE_UNIT[existing.module],
      snapshot: patch,
    });

    return updated;
  });
};

// ── delete ────────────────────────────────────────────────────────────────

// Hard-deletes the sale. The linked Revenue row is preserved — the
// onDelete: SetNull FK means Prisma clears the back-reference on Revenue
// automatically when the Sale row is deleted.
export const deleteSale = async (id, actorId) => {
  const existing = await prisma.productSale.findUnique({ where: { id } });
  if (!existing) throw new Error("Sale not found");

  await prisma.$transaction(async (tx) => {
    await tx.productSale.delete({ where: { id } });

    await writeAuditLog(tx, {
      entity:   "ProductSale",
      entityId: id,
      action:   "DELETE",
      actorId:  actorId ?? null,
      module:   FINANCE_UNIT[existing.module],
      snapshot: { buyerName: existing.buyerName, amountPaid: existing.amountPaid },
    });
  });
};

// ── summary KPIs ──────────────────────────────────────────────────────────

// Today's sale totals per module. Used by the Sales page KPI strip.
// Reads from ProductSale (not Revenue) — this is the operational view,
// not the finance ledger.
export const getSalesSummary = async (module) => {
  const now   = new Date();
  const start = startOfDay(now);
  const end   = endOfDay(now);

  const rows = await prisma.productSale.findMany({
    where: { module, saleDate: { gte: start, lte: end } },
    select: { quantity: true, amountPaid: true },
  });

  const totalQuantity = rows.reduce((s, r) => s + r.quantity, 0);
  const totalRevenue  = rows.reduce((s, r) => s + r.amountPaid, 0);
  return { totalQuantity, totalRevenue, count: rows.length };
};
