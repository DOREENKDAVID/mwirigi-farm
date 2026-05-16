// Reminders — virtual feed composed from existing source tables. The
// only persisted state is `ReminderOverride` rows (mark done / snooze).
//
// Each reminder is identified by a stable `syntheticId` of the form
//   "<sourceType>:<sourceId>:<facet>"
// so an override survives across regeneration.
//
// Active generators (each is a small async fn returning a list):
//   • health vaccinations → upcoming/overdue protocol cycles + brooder schedule
//   • dairy reproduction  → pregnancy check (≈42d after AI), expected calving
//   • piggery sows        → farrowing due date
//   • active treatments   → review/follow-up reminder per active treatment
//
// Status buckets the UI renders:
//   OVERDUE    — dueDate < today (and not done/snoozed-out)
//   DUE        — dueDate within 3 days
//   UPCOMING   — dueDate within 14 days
//   FUTURE     — dueDate beyond 14 days
//   DONE       — override status = DONE
//
// All status / urgency math happens here so the frontend just renders.

import prisma from "../../prisma/client.js";
import { listVaccinations } from "../health/health.service.js";

const MS_PER_DAY = 86_400_000;
const DUE_DAYS = 3;
const UPCOMING_DAYS = 14;

const startOfDay = (d) => {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
};

const daysBetween = (from, to) =>
  Math.round((startOfDay(to).getTime() - startOfDay(from).getTime()) / MS_PER_DAY);

const bucketize = (dueDate, today) => {
  if (!dueDate) return "FUTURE";
  const d = daysBetween(today, dueDate);
  if (d < 0) return "OVERDUE";
  if (d <= DUE_DAYS) return "DUE";
  if (d <= UPCOMING_DAYS) return "UPCOMING";
  return "FUTURE";
};

const priorityFromBucket = (b) => {
  switch (b) {
    case "OVERDUE": return 0;
    case "DUE":     return 1;
    case "UPCOMING": return 2;
    case "FUTURE":   return 3;
    case "DONE":     return 4;
    default:         return 5;
  }
};

// ===================================================================
// Generators
// ===================================================================

// 1. Health vaccinations — DB-stored protocols + brooder schedule.
//    Reuses health.service.listVaccinations() so logic stays unified.
const genVaccinations = async () => {
  const rows = await listVaccinations();
  return rows
    .filter((r) => r.nextDueAt)
    .map((r) => {
      // Brooder rows already have ids of form "brooder:<id>:<offset>".
      // For DB-protocol rows, encode as "vaccine:<protocolId>:next-due".
      const syntheticId = r.source === "DB"
        ? `vaccine:${r.protocolId}:next-due`
        : r.id; // already "brooder:..."
      const unit = r.unit || "Herd";
      return {
        syntheticId,
        sourceType: r.source === "DB" ? "vaccine" : "brooderVaccine",
        sourceId: r.protocolId ?? r.brooderId,
        module: unit,
        title: `${r.vaccine} — ${unit}`,
        description: r.animals
          ? `${r.animals} ${unit === "Layers" ? "birds" : "animals"} · ${r.type ?? "vaccination"}`
          : (r.type ?? "vaccination"),
        dueDate: r.nextDueAt,
        icon: "vaccine",
        unit,
      };
    });
};

// 2. Dairy reproduction — AI ~42 days after → pregnancy check; expected
//    calving date → calving prep reminder.
const genDairyReproduction = async () => {
  const records = await prisma.reproductionRecord.findMany({
    where: {
      deletedAt: null,
      eventType: "AI",
      // PENDING (no preg-check yet) → still actionable. CONFIRMED →
      // surface the calving date too. OPEN/ABORTED have no follow-up.
      pregnancyStatus: { in: ["PENDING", "CONFIRMED"] },
    },
    include: {
      cow: { select: { id: true, tag: true, nickname: true } },
    },
  });

  const out = [];
  for (const r of records) {
    const cowName = r.cow.nickname ?? r.cow.tag;

    // Pregnancy check window: AI date + 42 days (default heat-return
    // gate). Only emit when no check has been logged yet.
    if (!r.pregnancyCheckDate) {
      const dueDate = new Date(r.eventDate);
      dueDate.setDate(dueDate.getDate() + 42);
      out.push({
        syntheticId: `repro:${r.id}:pregcheck`,
        sourceType: "repro",
        sourceId: r.id,
        module: "Dairy",
        title: `${cowName} — pregnancy check due`,
        description: `42-day check after AI on ${r.eventDate.toISOString().slice(0, 10)}`,
        dueDate,
        icon: "breeding",
        unit: "Dairy",
      });
    }

    if (r.expectedCalvingDate) {
      out.push({
        syntheticId: `repro:${r.id}:calving`,
        sourceType: "repro",
        sourceId: r.id,
        module: "Dairy",
        title: `${cowName} — expected calving`,
        description: r.sireCode
          ? `Bred to ${r.sireCode}. Move to maternity 1 week prior.`
          : "Move to maternity 1 week prior.",
        dueDate: r.expectedCalvingDate,
        icon: "calving",
        unit: "Dairy",
      });
    }
  }
  return out;
};

// 3. Piggery sows — Pig.dueDate (next farrowing date for SOW pigs).
const genPiggerySows = async () => {
  const sows = await prisma.pig.findMany({
    where: {
      deletedAt: null,
      category: "SOW",
      dueDate: { not: null },
    },
    select: { id: true, tag: true, dueDate: true, status: true },
  });
  return sows.map((s) => ({
    syntheticId: `pig:${s.id}:duedate`,
    sourceType: "pig",
    sourceId: s.id,
    module: "Piggery",
    title: `Sow ${s.tag} — farrowing due`,
    description: s.status
      ? `Status: ${s.status}. Prepare farrowing crate 3–5 days prior.`
      : "Prepare farrowing crate 3–5 days prior.",
    dueDate: s.dueDate,
    icon: "farrow",
    unit: "Piggery",
  }));
};

// 4. Active treatments — emit a 7-day follow-up reminder per active
//    case. Anchor on `startDate + 7d` so the reminder appears after a
//    week of treatment for vet review.
const genActiveTreatments = async () => {
  const treatments = await prisma.treatment.findMany({
    where: { status: { in: ["ACTIVE", "IMPROVING"] } },
    select: {
      id: true,
      tag: true,
      unit: true,
      diagnosis: true,
      medication: true,
      startDate: true,
      status: true,
    },
  });
  return treatments.map((t) => {
    const due = new Date(t.startDate);
    due.setDate(due.getDate() + 7);
    return {
      syntheticId: `treatment:${t.id}:review`,
      sourceType: "treatment",
      sourceId: t.id,
      module: t.unit,
      title: `${t.tag} (${t.unit}) — treatment review`,
      description: `${t.diagnosis} · ${t.medication} · ${t.status}`,
      dueDate: due,
      icon: "health",
      unit: t.unit,
    };
  });
};

// ===================================================================
// Compose + apply overrides
// ===================================================================

const composeAll = async () => {
  const lists = await Promise.all([
    genVaccinations().catch(() => []),
    genDairyReproduction().catch(() => []),
    genPiggerySows().catch(() => []),
    genActiveTreatments().catch(() => []),
  ]);
  return lists.flat();
};

// Pull every override and key it by syntheticId so the merge is O(1).
const fetchOverrideMap = async () => {
  const rows = await prisma.reminderOverride.findMany();
  const map = new Map();
  for (const r of rows) map.set(r.syntheticId, r);
  return map;
};

const decorate = (raw, overrideMap, today) => {
  const override = overrideMap.get(raw.syntheticId);
  let bucket = bucketize(raw.dueDate, today);
  let effectiveDueDate = raw.dueDate;
  let snoozedUntil = null;
  let completedAt = null;
  let status = bucket;

  if (override) {
    if (override.status === "DONE") {
      bucket = "DONE";
      status = "DONE";
      completedAt = override.completedAt;
    } else if (override.status === "SNOOZED" && override.snoozedUntil) {
      // Snoozed reminders effectively shift the due date forward but
      // keep their original date for context.
      snoozedUntil = override.snoozedUntil;
      // If the snooze window hasn't ended yet, treat as FUTURE.
      if (override.snoozedUntil > today) {
        bucket = "FUTURE";
        status = "SNOOZED";
        effectiveDueDate = override.snoozedUntil;
      }
    }
  }

  return {
    ...raw,
    overrideId: override?.id ?? null,
    status,
    bucket,
    effectiveDueDate,
    daysUntilDue:
      effectiveDueDate ? daysBetween(today, effectiveDueDate) : null,
    completedAt,
    snoozedUntil,
    priority: priorityFromBucket(bucket),
  };
};

// ===================================================================
// Public API
// ===================================================================

export const listReminders = async ({ unit, status } = {}) => {
  const today = startOfDay(new Date());
  const [raw, overrideMap] = await Promise.all([
    composeAll(),
    fetchOverrideMap(),
  ]);

  let decorated = raw.map((r) => decorate(r, overrideMap, today));

  // Drop reminders whose due date is more than 90 days out — keeps the
  // feed actionable. Done items: keep the most recent 30 days only.
  decorated = decorated.filter((r) => {
    if (r.bucket === "DONE") {
      if (!r.completedAt) return true;
      return daysBetween(r.completedAt, today) <= 30;
    }
    if (!r.effectiveDueDate) return false;
    return daysBetween(today, r.effectiveDueDate) <= 90;
  });

  if (unit) {
    decorated = decorated.filter(
      (r) => (r.unit ?? "").toLowerCase() === unit.toLowerCase(),
    );
  }
  if (status) {
    decorated = decorated.filter((r) => r.bucket === status.toUpperCase());
  }

  // Sort: priority asc, then dueDate asc.
  decorated.sort((a, b) => {
    if (a.priority !== b.priority) return a.priority - b.priority;
    const ad = a.effectiveDueDate ? new Date(a.effectiveDueDate).getTime() : Infinity;
    const bd = b.effectiveDueDate ? new Date(b.effectiveDueDate).getTime() : Infinity;
    return ad - bd;
  });

  return decorated;
};

export const getKpis = async () => {
  const all = await listReminders();
  const counts = { OVERDUE: 0, DUE: 0, UPCOMING: 0, FUTURE: 0, DONE: 0 };
  for (const r of all) {
    counts[r.bucket] = (counts[r.bucket] ?? 0) + 1;
  }
  const active = counts.OVERDUE + counts.DUE + counts.UPCOMING + counts.FUTURE;
  return {
    overdue: counts.OVERDUE,
    due: counts.DUE,
    upcoming: counts.UPCOMING,
    future: counts.FUTURE,
    done: counts.DONE,
    active,
  };
};

export const markDone = async (syntheticId, userId) => {
  return prisma.reminderOverride.upsert({
    where: { syntheticId },
    create: {
      syntheticId,
      status: "DONE",
      completedAt: new Date(),
      completedById: userId ?? null,
    },
    update: {
      status: "DONE",
      completedAt: new Date(),
      completedById: userId ?? null,
      snoozedUntil: null,
    },
  });
};

export const snooze = async (syntheticId, days) => {
  const safe = Math.max(1, Math.min(30, Number(days) || 1));
  const until = new Date();
  until.setDate(until.getDate() + safe);
  return prisma.reminderOverride.upsert({
    where: { syntheticId },
    create: {
      syntheticId,
      status: "SNOOZED",
      snoozedUntil: until,
    },
    update: {
      status: "SNOOZED",
      snoozedUntil: until,
      completedAt: null,
    },
  });
};

export const undo = async (syntheticId) => {
  // Hard-delete the override so the reminder snaps back to its
  // computed-from-source state.
  return prisma.reminderOverride.deleteMany({ where: { syntheticId } });
};
