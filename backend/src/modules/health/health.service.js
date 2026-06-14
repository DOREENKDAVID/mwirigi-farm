import prisma from "../../prisma/client.js";
import { getBrooderScheduleRows } from "../layers/layersUnit.service.js";
import {
  computeProtocolView,
  countsForDue7d,
  startOfDay,
  addYears,
  daysBetween,
} from "./health.statusEngine.js";
import { writeAuditLog } from "../../utils/audit.js";

// =====================================================================
// HEALTH SERVICE
// =====================================================================
// Top-level orchestration for the cross-unit Health & Vaccines module.
// All status / KPI / cycle math is delegated to health.statusEngine —
// this file only composes data sources and shapes responses.

// ---------------------------------------------------------------------
// listVaccinations — unified schedule view
// ---------------------------------------------------------------------
// Composes:
//   1. DB-stored protocols (ANNUAL + RECURRING) with their VaccinationRecords
//   2. Brooder protocol rows from the Layers domain
// into one normalized list, sorted with actionable rows first.
export const listVaccinations = async () => {
  const today = startOfDay(new Date());

  const [protocols, brooderRows] = await Promise.all([
    prisma.vaccineProtocol.findMany({
      where: { active: true },
      include: {
        records: {
          orderBy: { administeredAt: "desc" },
        },
      },
    }),
    getBrooderScheduleRows(),
  ]);

  // Resolve animal counts per unit so the "Animals" column can override
  // hardcoded counts in records when the actual herd has grown/shrunk.
  const liveCounts = await resolveAnimalCounts();

  const dbRows = protocols.map((p) => {
    const view = computeProtocolView({
      protocol: p,
      records: p.records,
      today,
    });

    // Animal count: prefer the latest record's count (matches what was
    // actually administered last), falling back to the live unit count.
    const fromRecord = p.records[0]?.animalCount;
    const animals = fromRecord ?? liveCounts[p.unit] ?? 0;

    return {
      id: p.id,
      source: "DB",
      protocolId: p.id,
      vaccine: p.name,
      unit: p.unit,
      species: p.species,
      type: p.type,
      animals,
      lastDone: view.lastDone,
      lastDoneAt: view.lastDoneAt,
      nextDue: view.nextDue,
      nextDueAt: view.nextDueAt,
      status: view.status,
      daysUntilDue: view.daysUntilDue,
      cycleStart: view.cycleStart,
      cycleEnd: view.cycleEnd,
      notes: p.notes,
      // Forward the protocol's calendar metadata so the frontend can
      // build the annual herd-vaccine calendar tile from the same source.
      allowedMonths: p.allowedMonths ?? [],
      recurrenceMonths: p.recurrenceMonths,
      // Latest record identifiers — needed by the edit dialog to pre-fill
      // fields and call PATCH /vaccinations/records/:id.
      lastRecordId: p.records[0]?.id ?? null,
      lastRecordNotes: p.records[0]?.notes ?? null,
      lastRecordNextDue: p.records[0]?.nextDueOverride?.toISOString() ?? null,
      lastRecordAdministeredBy: p.records[0]?.administeredBy ?? null,
    };
  });

  // Tag brooder rows with a synthetic id so the frontend can key on it.
  const brooderTagged = brooderRows.map((r, i) => ({
    id: `brooder:${r.brooderId}:${r.dayOffsetStart}`,
    source: r.source,
    protocolId: null,
    brooderId: r.brooderId,
    vaccine: r.vaccine,
    unit: r.unit,
    species: "Layer",
    type: r.type,
    animals: r.animals,
    lastDone: r.lastDone,
    lastDoneAt: r.lastDoneAt,
    nextDue: r.nextDue,
    nextDueAt: r.nextDueAt,
    status: r.status,
    daysUntilDue: r.daysUntilDue,
    dayOffsetStart: r.dayOffsetStart,
    dayOffsetEnd: r.dayOffsetEnd,
    milestone: r.milestone,
    lastRecordId: r.lastRecordId ?? null,
    lastRecordNotes: r.lastRecordNotes ?? null,
    lastRecordNextDue: r.lastRecordNextDue ?? null,
    lastRecordAdministeredBy: r.lastRecordAdministeredBy ?? null,
  }));

  // Sort: actionable rows first, then by daysUntilDue.
  const order = {
    DUE_NOW: 0,
    DUE_WINDOW_OPEN: 1,
    OVERDUE: 2,
    DUE_SOON: 3,
    UPCOMING: 4,
    DONE: 5,
  };
  const all = [...dbRows, ...brooderTagged].sort((a, b) => {
    const oa = order[a.status] ?? 99;
    const ob = order[b.status] ?? 99;
    if (oa !== ob) return oa - ob;
    if (a.daysUntilDue == null) return 1;
    if (b.daysUntilDue == null) return -1;
    return a.daysUntilDue - b.daysUntilDue;
  });

  return all;
};

// ---------------------------------------------------------------------
// resolveAnimalCounts — total animals per HealthUnit from existing tables
// ---------------------------------------------------------------------
const resolveAnimalCounts = async () => {
  const [cows, pigs, sheep, bulls, brooder] = await Promise.all([
    prisma.cow.count(),
    prisma.pig.count({ where: { deletedAt: null } }),
    prisma.sheep.count({ where: { deletedAt: null } }),
    prisma.bull.count({ where: { deletedAt: null } }),
    prisma.brooder.findFirst({ orderBy: { receivedDate: "desc" } }),
  ]);
  return {
    Dairy: cows,
    Piggery: pigs,
    Doopers: sheep,
    Feedlot: bulls,
    Layers: brooder?.population ?? 0,
  };
};

// ---------------------------------------------------------------------
// createVaccinationRecord
// ---------------------------------------------------------------------
// Logs a new administered vaccination. Polymorphic by shape (validation
// in health.validation.js guarantees exactly one of the two modes):
//
//   * `protocolId` set → cross-unit annual/recurring administration,
//     filed against a stored VaccineProtocol row.
//
//   * `brooderId` + `vaccineName` + `dayOffset` set → brooder/chick
//     event. The Layers dashboard's `buildVaccinationView` overlays
//     these rows on `BROODER_VACCINE_PROTOCOL` to compute DONE state.
export const createVaccinationRecord = async (input, userId) => {
  if (input.protocolId) {
    const protocol = await prisma.vaccineProtocol.findUnique({
      where: { id: input.protocolId },
    });
    if (!protocol) throw new Error("Protocol not found");

    return prisma.$transaction(async (tx) => {
      const record = await tx.vaccinationRecord.create({
        data: {
          protocolId: protocol.id,
          unit: input.unit ?? protocol.unit,
          animalCount: input.animalCount,
          administeredAt: input.administeredAt,
          nextDueOverride: input.nextDueOverride ?? null,
          statusOverride: input.statusOverride ?? null,
          notes: input.notes ?? null,
          administeredBy: input.administeredBy ?? null,
          recordedById: userId ?? null,
        },
      });
      await writeAuditLog(tx, {
        entity: "VaccinationRecord",
        entityId: record.id,
        action: "CREATE",
        module: "health",
        actorId: userId ?? null,
        snapshot: {
          protocolId: protocol.id,
          vaccineName: protocol.name,
          unit: record.unit,
          animalCount: record.animalCount,
          administeredAt: record.administeredAt,
          nextDueOverride: record.nextDueOverride,
        },
      });
      return record;
    });
  }

  // Brooder shape.
  const brooder = await prisma.brooder.findUnique({
    where: { id: input.brooderId },
  });
  if (!brooder) throw new Error("Brooder not found");

  return prisma.$transaction(async (tx) => {
    const record = await tx.vaccinationRecord.create({
      data: {
        protocolId: null,
        brooderId: brooder.id,
        vaccineName: input.vaccineName,
        dayOffset: input.dayOffset,
        unit: input.unit ?? "Layers",
        animalCount: input.animalCount,
        administeredAt: input.administeredAt,
        nextDueOverride: input.nextDueOverride ?? null,
        statusOverride: input.statusOverride ?? null,
        notes: input.notes ?? null,
        administeredBy: input.administeredBy ?? null,
        recordedById: userId ?? null,
      },
    });
    await writeAuditLog(tx, {
      entity: "VaccinationRecord",
      entityId: record.id,
      action: "CREATE",
      module: "health",
      actorId: userId ?? null,
      snapshot: {
        brooderId: brooder.id,
        vaccineName: input.vaccineName,
        unit: record.unit,
        animalCount: record.animalCount,
        administeredAt: record.administeredAt,
      },
    });
    return record;
  });
};

// ---------------------------------------------------------------------
// updateVaccinationRecord — PATCH the most-recent (or any) record
// ---------------------------------------------------------------------
// Only the mutable fields (count, date, next-due override, notes) can
// be changed. The protocolId / brooderId association is immutable once
// created — changing the vaccine would need a delete + new record.
export const updateVaccinationRecord = async (recordId, patch, userId) => {
  const record = await prisma.vaccinationRecord.findUnique({
    where: { id: recordId },
  });
  if (!record) throw new Error("Vaccination record not found");

  return prisma.$transaction(async (tx) => {
    const updated = await tx.vaccinationRecord.update({
      where: { id: recordId },
      data: {
        animalCount: patch.animalCount ?? record.animalCount,
        administeredAt: patch.administeredAt ?? record.administeredAt,
        nextDueOverride:
          patch.nextDueOverride !== undefined
            ? patch.nextDueOverride
            : record.nextDueOverride,
        statusOverride:
          patch.statusOverride !== undefined
            ? patch.statusOverride
            : record.statusOverride,
        notes: patch.notes !== undefined ? patch.notes : record.notes,
        administeredBy:
          patch.administeredBy !== undefined
            ? patch.administeredBy
            : record.administeredBy,
      },
    });
    await writeAuditLog(tx, {
      entity: "VaccinationRecord",
      entityId: record.id,
      action: "UPDATE",
      module: "health",
      actorId: userId ?? null,
      oldValue: {
        animalCount: record.animalCount,
        administeredAt: record.administeredAt,
        nextDueOverride: record.nextDueOverride,
        notes: record.notes,
      },
      snapshot: {
        animalCount: updated.animalCount,
        administeredAt: updated.administeredAt,
        nextDueOverride: updated.nextDueOverride,
        notes: updated.notes,
      },
    });
    return updated;
  });
};

// ---------------------------------------------------------------------
// listProtocols — for an admin UI to manage protocol definitions
// ---------------------------------------------------------------------
export const listProtocols = async () => {
  return prisma.vaccineProtocol.findMany({
    where: { active: true },
    orderBy: [{ unit: "asc" }, { name: "asc" }],
  });
};

// ---------------------------------------------------------------------
// listTreatments — active + recently-resolved
// ---------------------------------------------------------------------
// Computes daysUnderTreatment at read time so the day-count pill stays
// accurate without nightly cron jobs.
export const listTreatments = async ({ activeOnly = true } = {}) => {
  const today = startOfDay(new Date());
  const where = activeOnly
    ? { status: { in: ["ACTIVE", "IMPROVING"] } }
    : {};
  const rows = await prisma.treatment.findMany({
    where,
    orderBy: { startDate: "desc" },
  });
  return rows.map((t) => {
    const days = Math.max(1, daysBetween(t.startDate, today));
    return {
      id: t.id,
      tag: t.tag,
      unit: t.unit,
      diagnosis: t.diagnosis,
      medication: t.medication,
      startDate: t.startDate.toISOString(),
      endDate: t.endDate ? t.endDate.toISOString() : null,
      status: t.status,
      // Display string used by the HTML:
      //   ACTIVE → "Day N"
      //   IMPROVING → "Improving"
      //   RECOVERED → "Recovered"
      //   CANCELLED → "Cancelled"
      statusLabel:
        t.status === "ACTIVE"
          ? `Day ${days}`
          : t.status.charAt(0) + t.status.slice(1).toLowerCase(),
      daysUnderTreatment: days,
      attendingVet: t.attendingVet,
      notes: t.notes,
    };
  });
};

// ---------------------------------------------------------------------
// createTreatment / updateTreatment
// ---------------------------------------------------------------------
export const createTreatment = async (input) => {
  return prisma.treatment.create({
    data: {
      tag: input.tag,
      unit: input.unit,
      diagnosis: input.diagnosis,
      medication: input.medication,
      startDate: input.startDate,
      attendingVet: input.attendingVet ?? null,
      notes: input.notes ?? null,
    },
  });
};

export const updateTreatment = async (id, input) => {
  const existing = await prisma.treatment.findUnique({ where: { id } });
  if (!existing) throw new Error("Treatment not found");
  return prisma.treatment.update({
    where: { id },
    data: {
      diagnosis: input.diagnosis ?? existing.diagnosis,
      medication: input.medication ?? existing.medication,
      status: input.status ?? existing.status,
      endDate:
        input.endDate !== undefined ? input.endDate : existing.endDate,
      notes: input.notes ?? existing.notes,
    },
  });
};

// ---------------------------------------------------------------------
// getProtocolReference — Vet Protocol Reference card (Chicks/Calves/Piglets)
// ---------------------------------------------------------------------
// Returns one entry per group with ordered steps. Frontend renders the
// tabs without needing to know about VetProtocolGroup directly.
export const getProtocolReference = async () => {
  const templates = await prisma.vetProtocolTemplate.findMany({
    include: { steps: { orderBy: { order: "asc" } } },
  });

  const out = { chicks: [], calves: [], piglets: [] };
  for (const t of templates) {
    const key = t.group.toLowerCase();
    if (out[key] === undefined) continue;
    out[key] = t.steps.map((s) => ({
      id: s.id,
      dayLabel: s.dayLabel,
      procedure: s.procedure,
      notes: s.notes,
    }));
  }
  return out;
};

// ---------------------------------------------------------------------
// KPIs: vaccinesDue7d, underTreatment, complianceRate
// ---------------------------------------------------------------------
//
// Compliance rate (per user spec):
//   Of vaccination cycles whose due-window has ENDED in the trailing
//   365 days, the fraction that have a record covering that cycle.
//   * Annual: each year's window is one cycle (counts once).
//   * Recurring: each `recurrenceMonths` interval is one cycle.
//   * Brooder: each protocol step in the latest brooder batch is one cycle.
export const getKpis = async () => {
  const today = startOfDay(new Date());
  const oneYearAgo = addYears(today, -1);

  const [vaccinations, treatments, complianceRate] = await Promise.all([
    listVaccinations(),
    prisma.treatment.findMany({
      where: { status: { in: ["ACTIVE", "IMPROVING"] } },
      select: { unit: true },
    }),
    computeComplianceRate({ today, since: oneYearAgo }),
  ]);

  const vaccinesDue7d = vaccinations
    .filter(countsForDue7d)
    .reduce((s, r) => s + (r.animals ?? 0), 0);

  const underTreatment = treatments.length;
  const underTreatmentByUnit = treatments.reduce((acc, t) => {
    acc[t.unit] = (acc[t.unit] ?? 0) + 1;
    return acc;
  }, {});

  return {
    vaccinesDue7d,
    underTreatment,
    underTreatmentByUnit,
    complianceRate, // 0..100, integer
  };
};

// ---------------------------------------------------------------------
// computeComplianceRate
// ---------------------------------------------------------------------
const computeComplianceRate = async ({ today, since }) => {
  const [protocols, brooder] = await Promise.all([
    prisma.vaccineProtocol.findMany({
      where: { active: true },
      include: { records: true },
    }),
    prisma.brooder.findFirst({
      orderBy: { receivedDate: "desc" },
      // Source of truth for "covered" state is the unified
      // VaccinationRecord table, not the legacy BrooderVaccination one.
      include: { vaccinationRecords: true },
    }),
  ]);

  let expected = 0;
  let completed = 0;

  for (const p of protocols) {
    const cycles = enumerateCycles({ protocol: p, since, today });
    for (const cyc of cycles) {
      expected += 1;
      // ANNUAL: late-but-done counts. A record covers the cycle if its
      // administeredAt is anywhere between this cycle's window-start and
      // the next cycle's window-start (i.e. inside the cycle's calendar
      // year). RECURRING: tight match — the record must fall within the
      // recurrence interval.
      const inCycle =
        p.type === "ANNUAL" ? cyc.coverageEnd : cyc.end;
      const covered = p.records.some(
        (r) => r.administeredAt >= cyc.start && r.administeredAt < inCycle,
      );
      if (covered) completed += 1;
    }
  }

  // Brooder: each protocol step that has reached its scheduled date in
  // the trailing 365 days counts as one cycle.
  if (brooder) {
    const { BROODER_VACCINE_PROTOCOL } = await import(
      "../layers/layersUnit.service.js"
    );
    const received = startOfDay(brooder.receivedDate);
    for (const step of BROODER_VACCINE_PROTOCOL) {
      const due = new Date(received);
      due.setDate(due.getDate() + step.dayOffset);
      if (due > today) continue; // not yet due → don't count
      if (due < since) continue; // outside trailing 365 days
      expected += 1;
      const covered = brooder.vaccinationRecords.some(
        (v) => v.dayOffset === step.dayOffset,
      );
      if (covered) completed += 1;
    }
  }

  if (expected === 0) return 100; // No history yet → assume compliant.
  return Math.round((completed / expected) * 100);
};

// Enumerates the cycles for a protocol that fall entirely or partly in
// [since, today]. Each cycle is { start, end } where the window for an
// ANNUAL is the calendar year's allowedMonths, and for RECURRING it's
// the interval anchored on the last administeredAt before that interval.
const enumerateCycles = ({ protocol, since, today }) => {
  const cycles = [];

  if (protocol.type === "ANNUAL") {
    const months = protocol.allowedMonths ?? [];
    if (!months.length) return cycles;
    const earliestMonth = Math.min(...months);
    const latestMonth = Math.max(...months);

    for (let year = since.getFullYear(); year <= today.getFullYear(); year += 1) {
      const start = new Date(year, earliestMonth - 1, 1);
      const end = new Date(year, latestMonth, 0); // last day of latestMonth
      end.setHours(23, 59, 59, 999);
      // Coverage extends to the next year's window-start so a late-done
      // record (e.g. FMD administered in May after missing Feb-Mar) still
      // counts as covering the cycle.
      const coverageEnd = new Date(year + 1, earliestMonth - 1, 1);
      // Only count cycles whose window has already ENDED on or before today.
      if (end > today) continue;
      // Cycle's end must be in the trailing window.
      if (end < since) continue;
      cycles.push({ start, end, coverageEnd });
    }
  } else if (protocol.type === "RECURRING") {
    const months = protocol.recurrenceMonths ?? 6;
    // Walk from `since` forward by `months` step. Each interval ending
    // on/before today is one expected cycle.
    let cursor = new Date(since);
    while (cursor <= today) {
      const next = new Date(cursor);
      next.setMonth(next.getMonth() + months);
      // Cycle window: [cursor, next). The cycle is "done" if a record
      // exists in [cursor, next). Mark it expected if next <= today.
      if (next <= today) {
        cycles.push({ start: cursor, end: next });
      }
      cursor = next;
    }
  }
  return cycles;
};
