import prisma from "../prisma/client.js";

// Append a row to the generic AuditLog table. Designed to be called
// inside a Prisma transaction (`tx`) so the audit write and the
// business mutation succeed-or-fail together; pass the tx client as
// the first argument and the transaction will scope both writes.
// Falls back to the singleton client when no tx is provided.
export const writeAuditLog = async (
  txOrPrisma,
  { entity, entityId, action, actorId, module, reason, oldValue, snapshot },
) => {
  const client = txOrPrisma ?? prisma;
  return client.auditLog.create({
    data: {
      entity,
      entityId,
      action,
      module: module ?? null,
      actorId: actorId ?? null,
      reason: reason ?? null,
      oldValue: oldValue ? JSON.stringify(oldValue) : null,
      snapshot: snapshot ? JSON.stringify(snapshot) : null,
    },
  });
};

export const listAuditLogs = async ({
  entity,
  entityId,
  module,
  actorId,
  from,
  to,
  limit = 50,
  offset = 0,
} = {}) => {
  const where = {
    ...(entity ? { entity } : {}),
    ...(entityId ? { entityId } : {}),
    ...(module ? { module } : {}),
    ...(actorId ? { actorId } : {}),
    ...(from || to
      ? {
          createdAt: {
            ...(from ? { gte: new Date(from) } : {}),
            ...(to ? { lte: new Date(to) } : {}),
          },
        }
      : {}),
  };

  const [rows, total] = await Promise.all([
    prisma.auditLog.findMany({
      where,
      orderBy: { createdAt: "desc" },
      take: Number(limit),
      skip: Number(offset),
      include: {
        actor: { select: { id: true, userName: true } },
      },
    }),
    prisma.auditLog.count({ where }),
  ]);

  return { rows, total };
};
