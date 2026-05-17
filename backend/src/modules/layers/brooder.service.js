import prisma from "../../prisma/client.js";
import { writeAuditLog } from "../../utils/audit.js";

// MORTALITY occurrences add to the brooder's cumulative mortality
// counter so the layers dashboard stays consistent without forcing
// readers to aggregate occurrences themselves.
export const logOccurrence = async (input, reportedById) => {
  const brooder = await prisma.brooder.findUnique({
    where: { id: input.brooderId },
  });
  if (!brooder) throw new Error("Brooder not found");

  return prisma.$transaction(async (tx) => {
    const occurrence = await tx.brooderOccurrence.create({
      data: {
        brooderId: input.brooderId,
        type: input.type,
        severity: input.severity ?? "LOW",
        occurredAt: input.occurredAt ?? new Date(),
        numberAffected: input.numberAffected ?? 0,
        description: input.description ?? null,
        actionTaken: input.actionTaken ?? null,
        imageUrl: input.imageUrl ?? null,
        followUpNeeded: input.followUpNeeded ?? false,
        reportedById: reportedById ?? null,
      },
    });

    if (input.type === "MORTALITY" && (input.numberAffected ?? 0) > 0) {
      await tx.brooder.update({
        where: { id: input.brooderId },
        data: { mortality: { increment: input.numberAffected } },
      });
    }

    return occurrence;
  });
};

export const listOccurrencesForBrooder = async (brooderId) => {
  return prisma.brooderOccurrence.findMany({
    where: { brooderId },
    orderBy: { occurredAt: "desc" },
    include: {
      reportedBy: { select: { id: true, userName: true } },
    },
  });
};

// Append a new allocation plan revision for a brooder. The schema
// keeps every historical row — the latest one per type wins on read
// (buildAllocationView in layersUnit.service). Wrapped in a
// transaction with the audit-log write so the trail can't fall out
// of sync with the actual data.
export const createAllocationPlan = async (input, actorId) => {
  const brooder = await prisma.brooder.findUnique({
    where: { id: input.brooderId },
  });
  if (!brooder) throw new Error("Brooder not found");

  return prisma.$transaction(async (tx) => {
    const plan = await tx.allocationPlan.create({
      data: {
        brooderId: input.brooderId,
        cycleId: input.brooderId,
        type: input.type,
        birds: input.birds,
        description: input.description,
        createdById: actorId ?? null,
      },
    });
    await writeAuditLog(tx, {
      entity: "AllocationPlan",
      entityId: input.brooderId,
      action: "CREATE",
      actorId,
      reason: input.reason ?? null,
      snapshot: {
        type: plan.type,
        birds: plan.birds,
        description: plan.description,
      },
    });
    return plan;
  });
};

// Weekly summary — counts and total affected for each occurrence type
// over the last 7 days. Used by the brooder weekly report card.
export const weeklyOccurrenceReport = async (brooderId) => {
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

  const rows = await prisma.brooderOccurrence.groupBy({
    by: ["type"],
    where: {
      brooderId,
      occurredAt: { gte: sevenDaysAgo },
    },
    _count: { _all: true },
    _sum: { numberAffected: true },
  });

  return {
    windowStart: sevenDaysAgo.toISOString(),
    windowEnd: new Date().toISOString(),
    byType: rows.map((r) => ({
      type: r.type,
      count: r._count._all,
      affected: r._sum.numberAffected ?? 0,
    })),
  };
};
