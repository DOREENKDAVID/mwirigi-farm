import prisma from "../../prisma/client.js";

// Gestation length used for expected calving date calculation.
const GESTATION_DAYS = 283;
// Minimum spacing between AI events for the same cow (duplicate guard).
const MIN_AI_INTERVAL_DAYS = 21;

const addDays = (date, n) => {
  const d = new Date(date);
  d.setDate(d.getDate() + n);
  return d;
};

const dayDiff = (a, b) => Math.abs((a.getTime() - b.getTime()) / 86_400_000);

// Resolve a cow id by tag OR id. Tag normalization matches dairy.service
// (first char upper, rest lower) so `MW-001`, `mw-001` and `Mw-001` all match.
const resolveCowId = async ({ tag, cowId }) => {
  if (cowId) {
    const exists = await prisma.cow.findUnique({ where: { id: cowId } });
    if (!exists) throw new Error("Cow not found");
    return exists.id;
  }
  const normalizedTag =
    tag.trim().charAt(0).toUpperCase() + tag.trim().slice(1).toLowerCase();
  const cow = await prisma.cow.findUnique({ where: { tag: normalizedTag } });
  if (!cow) throw new Error(`Cow with tag '${normalizedTag}' not found`);
  return cow.id;
};

// Create either an AI or CALVING event. Behaviour:
//   AI:      stores PENDING, leaves expectedCalvingDate null.
//            Rejects if another AI for the same cow is within 21 days.
//   CALVING: marks the cow's most recent open AI (PENDING/CONFIRMED) as OPEN
//            so the row leaves the active-pregnancy state.
export const createReproductionRecord = async (input) => {
  const cowId = await resolveCowId({ tag: input.tag, cowId: input.cowId });

  if (input.eventType === "AI") {
    const recent = await prisma.reproductionRecord.findFirst({
      where: {
        cowId,
        eventType: "AI",
        deletedAt: null,
      },
      orderBy: { eventDate: "desc" },
    });
    if (recent && dayDiff(recent.eventDate, input.eventDate) < MIN_AI_INTERVAL_DAYS) {
      throw new Error(
        `Likely duplicate: previous AI was ${Math.round(
          dayDiff(recent.eventDate, input.eventDate),
        )} day(s) ago (minimum interval is ${MIN_AI_INTERVAL_DAYS} days)`,
      );
    }

    return prisma.reproductionRecord.create({
      data: {
        cowId,
        eventType: "AI",
        eventDate: input.eventDate,
        sireCode: input.sireCode ?? null,
        pregnancyStatus: "PENDING",
        notes: input.notes ?? null,
      },
    });
  }

  // CALVING
  const created = await prisma.$transaction(async (tx) => {
    // Mark any active AI for this cow as OPEN (no longer pregnant).
    await tx.reproductionRecord.updateMany({
      where: {
        cowId,
        eventType: "AI",
        deletedAt: null,
        pregnancyStatus: { in: ["PENDING", "CONFIRMED"] },
      },
      data: { pregnancyStatus: "OPEN" },
    });

    return tx.reproductionRecord.create({
      data: {
        cowId,
        eventType: "CALVING",
        eventDate: input.eventDate,
        calfTag: input.calfTag ?? null,
        calfSex: input.calfSex ?? null,
        calfBirthWeightKg: input.calfBirthWeightKg ?? null,
        sireCode: input.sireCode ?? null,
        calvingEase: input.calvingEase ?? null,
        calvingFate: input.calvingFate ?? null,
        notes: input.notes ?? null,
      },
    });
  });
  return created;
};

// Update the pregnancy status of an AI record. When transitioning to
// CONFIRMED, fill expectedCalvingDate = eventDate + 283 days. Other transitions
// leave expectedCalvingDate untouched.
export const updateReproductionRecord = async (id, patch) => {
  const existing = await prisma.reproductionRecord.findUnique({ where: { id } });
  if (!existing || existing.deletedAt) throw new Error("Record not found");

  const data = { ...patch };

  if (patch.pregnancyStatus === "CONFIRMED" && existing.eventType === "AI") {
    data.expectedCalvingDate = addDays(existing.eventDate, GESTATION_DAYS);
  }

  return prisma.reproductionRecord.update({
    where: { id },
    data,
  });
};

// Confirm the cow's most recent AI in a single call. Used by the "Pregnancy
// confirmed" option in the modal. Delegates to updateReproductionRecord so
// the 283-day expectedCalvingDate auto-fill rule applies uniformly.
export const confirmMostRecentAi = async ({ tag, cowId, checkDate }) => {
  const resolvedCowId = await resolveCowId({ tag, cowId });
  const latestAi = await prisma.reproductionRecord.findFirst({
    where: {
      cowId: resolvedCowId,
      eventType: "AI",
      deletedAt: null,
    },
    orderBy: { eventDate: "desc" },
  });
  if (!latestAi) {
    throw new Error("No AI record to confirm for this cow");
  }
  return updateReproductionRecord(latestAi.id, {
    pregnancyStatus: "CONFIRMED",
    pregnancyCheckDate: checkDate ?? new Date(),
  });
};

export const softDeleteReproductionRecord = async (id) => {
  const existing = await prisma.reproductionRecord.findUnique({ where: { id } });
  if (!existing || existing.deletedAt) throw new Error("Record not found");
  return prisma.reproductionRecord.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
};

// Per-cow history for /api/reproduction/:cowId.
export const getHistoryForCow = async (cowId) => {
  const cow = await prisma.cow.findUnique({ where: { id: cowId } });
  if (!cow) throw new Error("Cow not found");
  const records = await prisma.reproductionRecord.findMany({
    where: { cowId, deletedAt: null },
    orderBy: { eventDate: "desc" },
  });
  return { cow: { id: cow.id, tag: cow.tag, breed: cow.breed }, records };
};

// List view used by the table. One row per cow that has any reproduction
// record. Computes:
//   lastAiDate          — most recent non-deleted AI event date
//   pregnancyStatus     — pregnancyStatus of that AI event
//   expectedCalvingDate — expectedCalvingDate of that AI event (may be null)
//   lifetimeCalvesCount — count of CALVING records for the cow
//
// Filters: ?search= (cow tag, case-insensitive contains) and ?status= (current
// pregnancyStatus). Pagination via page/limit.
export const listReproductionRows = async ({ search, status, page, limit }) => {
  const cowWhere = {
    reproductionRecords: { some: { deletedAt: null } },
    ...(search ? { tag: { contains: search, mode: "insensitive" } } : {}),
  };

  const cows = await prisma.cow.findMany({
    where: cowWhere,
    include: {
      reproductionRecords: {
        where: { deletedAt: null },
        orderBy: { eventDate: "desc" },
      },
    },
    orderBy: { tag: "asc" },
  });

  let rows = cows.map((cow) => {
    const records = cow.reproductionRecords;
    const ais = records.filter((r) => r.eventType === "AI");
    const calvings = records.filter((r) => r.eventType === "CALVING");
    const lastAi = ais[0] ?? null;
    return {
      cowId: cow.id,
      tag: cow.tag,
      lastAiDate: lastAi?.eventDate ?? null,
      pregnancyStatus: lastAi?.pregnancyStatus ?? null,
      expectedCalvingDate: lastAi?.expectedCalvingDate ?? null,
      lifetimeCalvesCount: calvings.length,
    };
  });

  if (status) {
    rows = rows.filter((r) => r.pregnancyStatus === status);
  }

  const total = rows.length;
  const start = (page - 1) * limit;
  const paged = rows.slice(start, start + limit);

  return { rows: paged, total, page, limit };
};
