import prisma from "../prisma/client.js";

// Append a row to the generic AuditLog table. Designed to be called
// inside a Prisma transaction (`tx`) so the audit write and the
// business mutation succeed-or-fail together; pass the tx client as
// the first argument and the transaction will scope both writes.
// Falls back to the singleton client when no tx is provided.
export const writeAuditLog = async (
  txOrPrisma,
  { entity, entityId, action, actorId, reason, snapshot },
) => {
  const client = txOrPrisma ?? prisma;
  return client.auditLog.create({
    data: {
      entity,
      entityId,
      action,
      actorId: actorId ?? null,
      reason: reason ?? null,
      snapshot: snapshot ? JSON.stringify(snapshot) : null,
    },
  });
};

export const listAuditLogs = async ({ entity, entityId, limit = 50 } = {}) => {
  return prisma.auditLog.findMany({
    where: {
      ...(entity ? { entity } : {}),
      ...(entityId ? { entityId } : {}),
    },
    orderBy: { createdAt: "desc" },
    take: limit,
    include: {
      actor: { select: { id: true, userName: true } },
    },
  });
};
