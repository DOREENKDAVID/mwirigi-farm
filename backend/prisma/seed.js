// Seed sample data so the dairy + reproduction screens render with realistic
// examples on a fresh install. Idempotent: re-running won't create duplicates.
//
// Usage: `node prisma/seed.js`  (run from d:/FARM/backend)

import "dotenv/config";
import prismaPkg from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";
import bcrypt from "bcrypt";

const { PrismaClient } = prismaPkg;
const adapter = new PrismaPg(process.env.DATABASE_URL);
const prisma = new PrismaClient({ adapter });

const addDays = (d, n) => {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
};

async function ensureCow(tag, breed, dateOfBirth, status) {
  const found = await prisma.cow.findUnique({ where: { tag } });
  if (found) return found;
  return prisma.cow.create({
    data: { tag, breed, dateOfBirth, status },
  });
}

async function ensureRepro(cowId, eventDate, payload) {
  const existing = await prisma.reproductionRecord.findFirst({
    where: { cowId, eventDate, eventType: payload.eventType, deletedAt: null },
  });
  if (existing) {
    // Re-runs should refresh calf detail fields (sex/weight/ease/fate)
    // added in 2026-05 — earlier seed rows didn't have them.
    return prisma.reproductionRecord.update({
      where: { id: existing.id },
      data: payload,
    });
  }
  return prisma.reproductionRecord.create({
    data: { cowId, eventDate, ...payload },
  });
}

async function ensureHouse(name, type, capacity, color, birdCount = 0) {
  const found = await prisma.house.findUnique({ where: { name } });
  if (found) {
    // Sync mutable fields so re-runs pick up updated HTML values without
    // needing to reset the DB.
    return prisma.house.update({
      where: { name },
      data: { type, capacity, color, birdCount },
    });
  }
  return prisma.house.create({
    data: { name, type, capacity, color, birdCount },
  });
}

// Insert a single LayerProduction row (idempotent on house+date). Computed
// columns mirror the service so seeded data matches what the API would
// produce for the same input.
async function ensurePig({
  tag,
  category,
  status,
  litterCount,
  lastFarrowed,
  dueDate,
  house,
  pen,
  serviceDate,
  expFarrow,
  breed,
  age,
  role,
  note,
}) {
  const isSow = category === "SOW";
  const data = {
    tag,
    category,
    status: status ?? null,
    litterCount: isSow ? litterCount ?? 0 : 0,
    lastFarrowed: isSow ? lastFarrowed ?? null : null,
    dueDate: isSow ? dueDate ?? null : null,
    house: house ?? null,
    pen: pen ?? null,
    serviceDate: serviceDate ?? null,
    expFarrow: expFarrow ?? null,
    breed: breed ?? null,
    age: age ?? null,
    role: role ?? null,
    note: note ?? null,
  };
  const found = await prisma.pig.findUnique({ where: { tag } });
  if (found) {
    return prisma.pig.update({ where: { tag }, data });
  }
  return prisma.pig.create({ data });
}

async function ensureBull({ tag, breed, entryDate, entryWeight, currentWeight }) {
  const found = await prisma.bull.findUnique({ where: { tag } });
  if (found) return found;
  return prisma.bull.create({
    data: { tag, breed, entryDate, entryWeight, currentWeight },
  });
}

// Crop has no unique name constraint, so we match on name + non-deleted to
// keep the seed idempotent across re-runs without colliding with crops the
// user has soft-deleted.
async function ensureCrop(input) {
  const found = await prisma.crop.findFirst({
    where: { name: input.name, deletedAt: null },
  });
  if (found) {
    return prisma.crop.update({
      where: { id: found.id },
      data: input,
    });
  }
  return prisma.crop.create({ data: input });
}

async function ensureFarrowing({
  sowId,
  date,
  pigletsBorn,
  pigletsAlive,
  pigletsDead,
  winners,
  fatteners,
  beaconners,
  remarks,
  service,
}) {
  const existing = await prisma.farrowingRecord.findFirst({
    where: { sowId, date },
  });
  if (existing) return existing;
  return prisma.farrowingRecord.create({
    data: {
      sowId,
      date,
      pigletsBorn,
      pigletsAlive,
      pigletsDead,
      winners: winners ?? null,
      fatteners: fatteners ?? null,
      beaconners: beaconners ?? null,
      remarks: remarks ?? null,
      service: service ?? null,
    },
  });
}

async function ensureLayerProduction({
  houseId,
  date,
  openingStock,
  eggsCollected,
  feedKg,
  deadRemoved,
  dayAge,
  remarks,
}) {
  const existing = await prisma.layerProduction.findUnique({
    where: { houseId_date: { houseId, date } },
  });
  if (existing) return existing;
  const trays = Number((eggsCollected / 30).toFixed(2));
  const percentLaying =
    openingStock > 0
      ? Number(((eggsCollected / openingStock) * 100).toFixed(2))
      : 0;
  const closingStock = Math.max(0, openingStock - deadRemoved);
  return prisma.layerProduction.create({
    data: {
      houseId,
      date,
      openingStock,
      eggsCollected,
      trays,
      percentLaying,
      feedKg,
      deadRemoved,
      closingStock,
      dayAge,
      remarks: remarks ?? null,
    },
  });
}

async function main() {
  // 1. Cow + reproduction seeding now lives entirely inside
  //    seedDairyOperations() — it owns the 56-cow herd from the v4.1
  //    HTML mockup and attaches AI/calving history to a few named
  //    cows. Legacy stand-alone Mw-012 / Mw-035 / Mw-082 stubs were
  //    removed in favour of the canonical 56-cow set.

  // 3. Poultry (layer) houses — A, B, C per the HTML mockup.
  //    Houses A & B are at end-of-lay (Day 360); they will be replaced by
  //    pullets from the brooder. House C is younger (Day 340) and continues.
  //    birdCount comes from the HTML "Layer houses (Day 360)" table.
  const houseA = await ensureHouse("House A", "Poultry", 3000, "#27500A", 2980);
  const houseB = await ensureHouse("House B", "Poultry", 3000, "#854F0B", 2980);
  const houseC = await ensureHouse("House C", "Poultry", 2700, "#185FA5", 2692);

  // 4. Daily LayerProduction — 7 days ending today.
  //    Today's per-house values (HTML): A=92 crates, B=83, C=64 ⇒ 239 total.
  //    Per-day eggs are explicit so the 7-day chart matches the mockup
  //    (203, 209, 215, 205, 220, 213, 239 crates total over Mon→Sun).
  //    Today's age (House A&B): Day 360. House C: Day 340 (so the dynamic
  //    phasing-out rule `ageDays >= 360` matches the HTML's "Continuing").
  //    Today's mortality across all houses: 4 (HTML KPI).
  //    Feed per house today: 350 kg (HTML table).
  const houseSeed = [
    {
      id: houseA.id,
      birdCount: 2980,
      ageOffsetToday: 360,
      todayDead: 1,
      // Eggs per day, oldest → newest (offset 6 → 0).
      eggs: [2370, 2440, 2510, 2400, 2570, 2490, 2760],
      feed: 350,
    },
    {
      id: houseB.id,
      birdCount: 2980,
      ageOffsetToday: 360,
      todayDead: 2,
      eggs: [2070, 2130, 2190, 2090, 2240, 2170, 2490],
      feed: 350,
    },
    {
      id: houseC.id,
      birdCount: 2692,
      ageOffsetToday: 340,
      todayDead: 1,
      eggs: [1640, 1690, 1740, 1660, 1780, 1720, 1920],
      feed: 350,
    },
  ];

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // Wipe existing poultry production so re-seeded rows reflect new bird
  // counts and ages. Cascades from House would also work, but we keep the
  // House rows so their IDs stay stable across re-runs.
  await prisma.layerProduction.deleteMany({
    where: { house: { type: "Poultry" } },
  });

  for (let offset = 6; offset >= 0; offset -= 1) {
    const d = new Date(today);
    d.setDate(today.getDate() - offset);
    const idx = 6 - offset; // 0..6 maps to oldest..newest

    for (const h of houseSeed) {
      // Stock decays slightly across the week (1 dead/day average for A&B,
      // less for C). dayAge counts back from today's ageOffsetToday.
      const dayAge = h.ageOffsetToday - offset;
      const opening = h.birdCount + offset; // older day = slightly higher stock
      const eggs = h.eggs[idx];
      const dead = offset === 0 ? h.todayDead : (idx % 3 === 0 ? 0 : 1);

      await ensureLayerProduction({
        houseId: h.id,
        date: d,
        openingStock: opening,
        eggsCollected: eggs,
        feedKg: h.feed,
        deadRemoved: dead,
        dayAge,
        remarks: null,
      });
    }
  }

  // 4b. Brooder unit + vaccination history + allocation plan.
  await seedBrooderUnit();

  // 5. Piggery — sample pigs + farrowing records.
  await seedPiggery();

  // 6. Feedlot & Doopers — bulls + sheep + lambing.
  await seedFeedlot();

  // 7. Staff & Labour — User rows matching the HTML mockup so the dashboard
  // overview's "manager" column and the staff page table both have data.
  await seedStaff();

  // 8. Health & Vaccines — cross-unit vaccination protocols + records,
  // active treatments, and vet protocol reference templates per HTML.
  await seedHealth();

  // 9. Ngushish — horticulture/irrigation/fodder crops + a today-dated
  // dispatch so the "Produce dispatched today" + "Revenue today" KPIs
  // match the HTML mockup (420 kg / KSh 8,400).
  await seedNgushish();

  // 10. Feeds — 18 raw materials with realistic stock vs daily-use figures,
  // 3 bulk forage rows (silage / Napier / maize for silage), and a
  // distribution row per livestock unit so the dashboard / inventory
  // table / status pills / bulk feed card / distribution card all
  // populate from real DB data.
  await seedFeeds();

  // 11. Dairy operations — houses, workers, cow assignments, and 7
  // days of milk records so the worker-centric milk-logging UI
  // (session tabs, worker bar, cow grid, below-avg flagging, manager
  // view) renders against real data.
  await seedDairyOperations();
  await seedDairyInventory();
  await seedLayersInventory();
  await seedFeedlotInventory();
  await seedFinance();

  console.info(
    "Seed complete. 3 cows + reproduction history + 3 layer houses (A/B/C) + 7 days of LayerProduction + brooder batch (10,000 chicks Day 60) with vaccination history & allocation plan + piggery (24 sows + boars + piglets + farrowing history) + feedlot (4 bulls + 84 sheep + lambing) + health module (6 vaccine protocols + 3 active treatments + 3 vet protocol templates).",
  );
}

// Seeds the Layers Unit's brooder batch with HTML-faithful values:
//   Population 10,000 day-1 chicks, received 7 Mar 2026 (Day 60 on 7 May).
//   Three completed vaccinations (Days 12, 15, 42) — the rest derive their
//   status (DUE_NOW / UPCOMING) from today vs receivedDate + dayOffset.
//   Allocation: 5,000 POL sale + 5,000 retained to replace Houses A & B (2,500 each).
async function seedBrooderUnit() {
  // Idempotent: re-seed on the latest brooder batch if one exists.
  const existing = await prisma.brooder.findFirst({
    orderBy: { receivedDate: "desc" },
  });

  // Anchor date: 7 Mar 2026 → today (7 May 2026) = Day 60.
  const receivedDate = new Date("2026-03-07T00:00:00.000Z");

  const brooder =
    existing ??
    (await prisma.brooder.create({
      data: {
        label: "Brooder 2026-Q1",
        population: 10000,
        receivedDate,
        targetDays: 90,
        mortality: 0,
        notes: "10,000 day-1 chicks. Target: cage transfer at 3 months.",
      },
    }));

  if (existing) {
    // Sync mutable fields so re-runs reflect any HTML-data tweaks.
    await prisma.brooder.update({
      where: { id: brooder.id },
      data: {
        population: 10000,
        receivedDate,
        targetDays: 90,
        actualTransferDate: null,
      },
    });
  }

  // Completed vaccinations only — Newcastle Day 12, Gumboro Day 15,
  // Newcastle repeat Day 42. Day 56 (Fowl typhoid) is "DUE NOW" per HTML
  // and intentionally has NO record so the service derives DUE_NOW.
  const completed = [
    { dayOffset: 12, vaccineName: "Newcastle (1st dose)" },
    { dayOffset: 15, vaccineName: "Gumboro (IBD)" },
    { dayOffset: 42, vaccineName: "Newcastle (repeat, Week 6)" },
  ];

  // Brooder vaccination administrations now live in the unified
  // VaccinationRecord table (Health module's source of truth) — the
  // legacy BrooderVaccination table is no longer read by services.
  // Backfill: also copy any pre-existing BrooderVaccination rows for
  // this brooder so a re-run after upgrade doesn't lose history.
  const legacyDoses = await prisma.brooderVaccination.findMany({
    where: { brooderId: brooder.id },
  });
  const seenOffsets = new Set();
  for (const d of legacyDoses) {
    seenOffsets.add(d.dayOffset);
    await prisma.vaccinationRecord.upsert({
      where: {
        brooderId_dayOffset: {
          brooderId: brooder.id,
          dayOffset: d.dayOffset,
        },
      },
      create: {
        brooderId: brooder.id,
        dayOffset: d.dayOffset,
        vaccineName: d.vaccineName,
        unit: "Layers",
        animalCount: brooder.population,
        administeredAt: d.administeredAt,
      },
      update: {
        vaccineName: d.vaccineName,
        administeredAt: d.administeredAt,
      },
    });
  }

  for (const v of completed) {
    const administeredAt = new Date(receivedDate);
    administeredAt.setDate(administeredAt.getDate() + v.dayOffset);
    await prisma.vaccinationRecord.upsert({
      where: {
        brooderId_dayOffset: {
          brooderId: brooder.id,
          dayOffset: v.dayOffset,
        },
      },
      create: {
        brooderId: brooder.id,
        dayOffset: v.dayOffset,
        vaccineName: v.vaccineName,
        unit: "Layers",
        animalCount: brooder.population,
        administeredAt,
      },
      update: {
        vaccineName: v.vaccineName,
        administeredAt,
        animalCount: brooder.population,
      },
    });
  }

  // Allocation plan — wipe and recreate so re-running reflects the HTML
  // numbers verbatim. Multiple revisions are supported by the schema; we
  // only seed the latest.
  await prisma.allocationPlan.deleteMany({ where: { brooderId: brooder.id } });
  await prisma.allocationPlan.createMany({
    data: [
      {
        brooderId: brooder.id,
        cycleId: brooder.id,
        type: "POL_SALE",
        birds: 5000,
        description: "Sale at point-of-lay (POL pullets)",
      },
      {
        brooderId: brooder.id,
        cycleId: brooder.id,
        type: "REPLACEMENT",
        birds: 5000,
        description:
          "Replace Houses A & B (2,500 each) — current adults phasing out",
      },
    ],
  });
}

async function seedFeedlot() {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const days = (n) => {
    const d = new Date(today);
    d.setDate(d.getDate() + n);
    return d;
  };

  // 12 bulls on feed — matches the v4.2 HTML's "BULLS ON FEED: 12"
  // KPI. Mix of breeds and varied entry dates so the register shows a
  // realistic distribution of days-on-feed (27–62) and ADGs near the
  // target 0.95–1.10 kg/day window.
  const bullSeed = [
    { tag: "BL-001", breed: "Boran",      entryOffset: -47, entryWeight: 280, currentWeight: 332 },
    { tag: "BL-002", breed: "Boran",      entryOffset: -47, entryWeight: 265, currentWeight: 310 },
    { tag: "BL-003", breed: "Sahiwal",    entryOffset: -52, entryWeight: 285, currentWeight: 338 },
    { tag: "BL-004", breed: "Boran",      entryOffset: -41, entryWeight: 272, currentWeight: 314 },
    { tag: "BL-005", breed: "Sahiwal",    entryOffset: -36, entryWeight: 290, currentWeight: 325 },
    { tag: "BL-006", breed: "Friesian X", entryOffset: -34, entryWeight: 275, currentWeight: 308 },
    { tag: "BL-007", breed: "Boran",      entryOffset: -31, entryWeight: 268, currentWeight: 298 },
    { tag: "BL-008", breed: "Sahiwal",    entryOffset: -29, entryWeight: 282, currentWeight: 310 },
    { tag: "BL-009", breed: "Friesian X", entryOffset: -27, entryWeight: 270, currentWeight: 298 },
    { tag: "BL-010", breed: "Boran",      entryOffset: -22, entryWeight: 278, currentWeight: 300 },
    { tag: "BL-011", breed: "Sahiwal",    entryOffset: -16, entryWeight: 285, currentWeight: 301 },
    { tag: "BL-012", breed: "Boran",      entryOffset: -10, entryWeight: 274, currentWeight: 284 },
  ];
  for (const b of bullSeed) {
    await ensureBull({
      tag: b.tag,
      breed: b.breed,
      entryDate: days(b.entryOffset),
      entryWeight: b.entryWeight,
      currentWeight: b.currentWeight,
    });
  }

  // Doopers flock target = 84 (HTML mockup). Build 60 ewes + 8 rams + 16 lambs.
  // Each sheep is tagged with a sequential `DR-XXX` ID so it can be edited
  // and deleted from the doopers register table.
  const sheepCounts = [
    { category: "EWE", count: 60 },
    { category: "RAM", count: 8 },
    { category: "LAMB", count: 16 },
  ];
  let sheepIdx = 0;
  for (const { category, count } of sheepCounts) {
    for (let i = 0; i < count; i += 1) {
      sheepIdx += 1;
      const tag = `DR-${String(sheepIdx).padStart(3, "0")}`;
      const existing = await prisma.sheep.findUnique({ where: { tag } });
      if (existing) continue;
      // Stagger entry dates over the last ~6 months for a realistic spread.
      const entryDate = new Date(today);
      entryDate.setDate(entryDate.getDate() - sheepIdx * 2);
      await prisma.sheep.create({
        data: {
          tag,
          category,
          entryDate,
          entryWeight:
            category === "LAMB" ? 4 + (sheepIdx % 3) : 45 + (sheepIdx % 20),
        },
      });
    }
  }

  // 11 lambs this month spread across a few entries.
  const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
  const lambingSpread = [
    { offset: 2, lambs: 3 },
    { offset: 6, lambs: 4 },
    { offset: 11, lambs: 4 },
  ];
  for (const ls of lambingSpread) {
    const date = new Date(monthStart);
    date.setDate(monthStart.getDate() + ls.offset);
    const existing = await prisma.lambingRecord.findFirst({
      where: { date },
    });
    if (!existing) {
      await prisma.lambingRecord.create({
        data: { date, lambsBorn: ls.lambs },
      });
    }
  }
}

async function seedPiggery() {
  // Master register Rev 2 · 8 May 2026 — verbatim from the v4.2 HTML
  // mockup. Houses A·B·C·EM run by Simiyu; D·E by David; F by Sam Bwira.
  // Status mapping (HTML → PigStatus enum):
  //   nursing   → LACTATING
  //   gestation → GESTATING
  //   dry       → DRY
  //   service   → SERVICE

  // Wipe existing piggery state so a re-run produces the HTML data verbatim
  // (the master register tags don't overlap with the legacy PIG-XXX seed).
  await prisma.litter.deleteMany({});
  await prisma.farrowingRecord.deleteMany({});
  await prisma.pig.deleteMany({});
  await prisma.nurseryGroup.deleteMany({});
  await prisma.fattenPen.deleteMany({});

  const D = (s) => (s ? new Date(`${s}T00:00:00Z`) : null);
  const mapStatus = (s) => {
    if (s === "nursing") return "LACTATING";
    if (s === "gestation") return "GESTATING";
    if (s === "dry") return "DRY";
    if (s === "service") return "SERVICE";
    return null;
  };

  // ---------------- SOWS (67 across A/B/C/D/EM) ----------------
  const sowRegister = [
    // House A (Simiyu) - 14 sows
    { tag: "101", pen: "A1", house: "A", status: "nursing", litterId: "L-101-2604", born: "2026-04-08", count: 10, note: "Wean ~8 Jun" },
    { tag: "102", pen: "A2", house: "A", status: "nursing", litterId: "L-102-2604", born: "2026-04-08", count: 11, note: "Wean ~8 Jun" },
    { tag: "103", pen: "A3", house: "A", status: "nursing", litterId: "L-103-2604", born: "2026-04-08", count: 9,  note: "Wean ~8 Jun" },
    { tag: "104", pen: "A4", house: "A", status: "gestation", served: "2026-03-24", expFarrow: "2026-07-16", note: "Mid-gestation. Move to farrow pen ~5 Jul" },
    { tag: "105", pen: "A5", house: "A", status: "nursing", litterId: "L-105-26??", count: 11, note: "BIRTH DATE UNCLEAR — confirm" },
    { tag: "106", pen: "A6", house: "A", status: "nursing", litterId: "L-106-2605", born: "2026-05-04", count: 16, note: "Largest litter — watch for crushing" },
    { tag: "107", pen: "A7", house: "A", status: "gestation", served: "2026-02-22", expFarrow: "2026-06-16", note: "Move to farrow pen ~6 Jun" },
    { tag: "108", pen: "A8", house: "A", status: "gestation", served: "2026-02-07", expFarrow: "2026-06-01", note: "DUE 24 days. Move to farrow pen now" },
    { tag: "109", pen: "A9", house: "A", status: "gestation", served: "2026-02-07", expFarrow: "2026-06-01", note: "DUE 24 days. Move to farrow pen now" },
    { tag: "110", pen: "A10", house: "A", status: "nursing", litterId: "L-110-2605", born: "2026-05-03", count: 13 },
    { tag: "111", pen: "A11", house: "A", status: "nursing", litterId: "L-111-2604", born: "2026-04-17", count: 12 },
    { tag: "112", pen: "A12", house: "A", status: "gestation", served: "2026-02-07", expFarrow: "2026-06-01", note: "DUE 24 days. Move to farrow pen now" },
    { tag: "113", pen: "A13", house: "A", status: "gestation", served: "2026-03-24", expFarrow: "2026-07-16" },
    { tag: "114", pen: "A14", house: "A", status: "gestation", served: "2026-04-08", expFarrow: "2026-07-31" },

    // House B (Simiyu) - 18 sows
    { tag: "115", pen: "B1",  house: "B", status: "gestation", served: "2026-04-17", expFarrow: "2026-08-09" },
    { tag: "116", pen: "B2",  house: "B", status: "dry", note: "Heat-check daily. Schedule for service" },
    { tag: "117", pen: "B3",  house: "B", status: "nursing", litterId: "L-117-2604", born: "2026-04-08", count: 7, note: "Small litter — review sow performance" },
    { tag: "118", pen: "B5",  house: "B", status: "dry", note: "Heat-check daily" },
    { tag: "119", pen: "B5",  house: "B", status: "dry", note: "Heat-check daily (sharing pen with 118)" },
    { tag: "120", pen: "B6",  house: "B", status: "dry", note: "Heat-check daily" },
    { tag: "121", pen: "B7",  house: "B", status: "gestation", served: "2026-03-09", expFarrow: "2026-07-01", note: "Confirm service status" },
    { tag: "122", pen: "B9",  house: "B", status: "gestation", served: "2026-04-24", expFarrow: "2026-08-16" },
    { tag: "123", pen: "B10", house: "B", status: "gestation", served: "2026-04-24", expFarrow: "2026-08-16" },
    { tag: "124", pen: "B11", house: "B", status: "gestation", served: "2026-02-07", expFarrow: "2026-06-01", note: "DUE 24 days. Move to farrow pen now" },
    { tag: "125", pen: "B12", house: "B", status: "service", note: "SERVICING NOW with BR04 — log service date when observed" },
    { tag: "126", pen: "B13", house: "B", status: "dry", note: "Heat-check daily" },
    { tag: "127", pen: "B13", house: "B", status: "dry", note: "Heat-check daily (sharing pen with 126)" },
    { tag: "128", pen: "B14", house: "B", status: "dry", note: "Heat-check daily" },
    { tag: "129", pen: "B14", house: "B", status: "dry", note: "Heat-check daily (sharing pen with 128)" },
    { tag: "130", pen: "B15", house: "B", status: "dry", note: "Heat-check daily" },
    { tag: "131", pen: "B15", house: "B", status: "dry", note: "Heat-check daily (sharing pen with 130)" },
    { tag: "132", pen: "B16", house: "B", status: "gestation", served: "2026-04-17", expFarrow: "2026-08-09" },

    // House C (Simiyu) - 13 sows
    { tag: "133", pen: "C1",  house: "C", status: "nursing", litterId: "L-133-2604", born: "2026-04-24", count: 10, note: "AI-bred" },
    { tag: "134", pen: "C2",  house: "C", status: "nursing", litterId: "L-134-2604", born: "2026-04-17", count: 6,  note: "AI-bred. Small litter" },
    { tag: "135", pen: "C3",  house: "C", status: "nursing", litterId: "L-135-2604", born: "2026-04-26", count: 8,  note: "AI-bred" },
    { tag: "136", pen: "C4",  house: "C", status: "nursing", litterId: "L-136-2604", born: "2026-04-18", count: 7,  note: "AI-bred" },
    { tag: "137", pen: "C6",  house: "C", status: "nursing", litterId: "L-137-2604", count: 6, note: "★ 1 RETAINER flagged — tag as 137-26A at 3-4mo" },
    { tag: "138", pen: "C7",  house: "C", status: "nursing", litterId: "L-138-2604", born: "2026-04-24", count: 9,  note: "AI-bred" },
    { tag: "139", pen: "C8",  house: "C", status: "nursing", litterId: "L-139-2604", born: "2026-04-01", count: 8,  note: "Wean ~30 May" },
    { tag: "140", pen: "C9",  house: "C", status: "gestation", served: "2026-03-09", expFarrow: "2026-07-01" },
    { tag: "141", pen: "C10", house: "C", status: "gestation", served: "2026-02-07", expFarrow: "2026-06-01", note: "DUE 24 days. Move to farrow pen now" },
    { tag: "142", pen: "C11", house: "C", status: "gestation", served: "2026-02-07", expFarrow: "2026-06-01", note: "DUE 24 days. Duroc-served (BR06) — Duroc cross litter" },
    { tag: "143", pen: "C14", house: "C", status: "nursing", litterId: "L-143-2604", born: "2026-04-17", count: 5,  note: "AI-bred. Small litter — review" },
    { tag: "144", pen: "C15", house: "C", status: "nursing", litterId: "L-144-2604", count: 1, note: "⚠ CATASTROPHIC: 16 of 17 piglets died. Investigate urgently — sow health, crushing, illness. Sow review for culling" },
    { tag: "145", pen: "C16", house: "C", status: "gestation", served: "2026-02-07", expFarrow: "2026-06-01", note: "DUE 24 days. Move to farrow pen now" },

    // House D (David) - 19 sows
    { tag: "089", pen: "D1",  house: "D", status: "gestation", served: "2026-02-07", expFarrow: "2026-06-01", note: "DUE 24 days. Move to farrow pen now. Separate from 029 first" },
    { tag: "029", pen: "D1",  house: "D", status: "gestation", served: "2026-03-09", expFarrow: "2026-07-01", note: "Shares pen with 089 — separate before 089 farrows" },
    { tag: "146", pen: "D2",  house: "D", status: "gestation", served: "2026-02-07", expFarrow: "2026-06-01", note: "DUE 24 days. Move to farrow pen now" },
    { tag: "094", pen: "D3",  house: "D", status: "gestation", served: "2026-02-22", expFarrow: "2026-06-16" },
    { tag: "097", pen: "D4",  house: "D", status: "gestation", served: "2026-03-09", expFarrow: "2026-07-01" },
    { tag: "147", pen: "D4",  house: "D", status: "dry", note: "Heat-check daily" },
    { tag: "148", pen: "D5",  house: "D", status: "dry", note: "Heat-check daily" },
    { tag: "149", pen: "D5",  house: "D", status: "dry", note: "Heat-check daily (sharing pen with 148)" },
    { tag: "086", pen: "D6",  house: "D", status: "gestation", served: "2026-03-09", expFarrow: "2026-07-01" },
    { tag: "150", pen: "D6",  house: "D", status: "gestation", served: "2026-04-08", expFarrow: "2026-07-31", note: "Confirm whether served" },
    { tag: "070", pen: "D7",  house: "D", status: "gestation", served: "2026-03-09", expFarrow: "2026-07-01" },
    { tag: "090", pen: "D7",  house: "D", status: "gestation", served: "2026-03-09", expFarrow: "2026-07-01" },
    { tag: "085", pen: "D8",  house: "D", status: "gestation", served: "2026-02-22", expFarrow: "2026-06-16" },
    { tag: "077", pen: "D8",  house: "D", status: "gestation", served: "2026-03-09", expFarrow: "2026-07-01" },
    { tag: "053", pen: "D9",  house: "D", status: "gestation", served: "2026-03-09", expFarrow: "2026-07-01" },
    { tag: "082", pen: "D9",  house: "D", status: "gestation", served: "2026-03-09", expFarrow: "2026-07-01" },
    { tag: "151", pen: "D9",  house: "D", status: "gestation", note: "Untagged — confirm service date" },
    { tag: "088", pen: "D10", house: "D", status: "gestation", served: "2026-02-07", expFarrow: "2026-06-01", note: "DUE 24 days. Move to farrow pen now" },
    { tag: "152", pen: "D19", house: "D", status: "dry", note: "Heat-check daily" },

    // Emergency House (Simiyu interim) - 3 sows in 4 pens
    { tag: "153", pen: "EM2", house: "EM", status: "gestation", served: "2026-04-08", expFarrow: "2026-07-31", note: "Sole occupant. Confirm reason for EM placement" },
    { tag: "154", pen: "EM4", house: "EM", status: "dry", note: "Heat-check daily. Confirm why in EM rather than B/D rotation" },
    { tag: "155", pen: "EM4", house: "EM", status: "dry", note: "Heat-check daily (sharing pen with 154)" },
  ];

  // Create sows and capture id-by-tag for litter/farrowing linkage.
  const sowByTag = new Map();
  for (const s of sowRegister) {
    const sow = await ensurePig({
      tag: s.tag,
      category: "SOW",
      status: mapStatus(s.status),
      house: s.house,
      pen: s.pen,
      serviceDate: D(s.served),
      expFarrow: D(s.expFarrow),
      dueDate: D(s.expFarrow),
      lastFarrowed: D(s.born),
      litterCount: s.count ?? 0,
      note: s.note,
    });
    sowByTag.set(s.tag, sow);
  }

  // ---------------- LITTERS (from nursing sows) ----------------
  for (const s of sowRegister) {
    if (s.status !== "nursing" || !s.litterId) continue;
    await prisma.litter.upsert({
      where: { litterId: s.litterId },
      update: {
        sowId: sowByTag.get(s.tag).id,
        born: D(s.born),
        count: s.count ?? 0,
        note: s.note ?? null,
      },
      create: {
        litterId: s.litterId,
        sowId: sowByTag.get(s.tag).id,
        born: D(s.born),
        count: s.count ?? 0,
        note: s.note ?? null,
      },
    });
  }

  // ---------------- BOARS (7) ----------------
  const boars = [
    { tag: "BR01", pen: "B4",  house: "B", breed: "TBC",   age: "~5mo",  role: "Young — coming into service in 1-2 mo" },
    { tag: "BR02", pen: "B4",  house: "B", breed: "TBC",   age: "~5mo",  role: "Young — coming into service in 1-2 mo" },
    { tag: "BR03", pen: "B8",  house: "B", breed: "TBC",   age: "Mature", role: "Active service boar" },
    { tag: "BR04", pen: "B12", house: "B", breed: "TBC",   age: "Mature", role: "Currently servicing — sow 125 in pen" },
    { tag: "BR05", pen: "C17", house: "C", breed: "Duroc", age: "Mature", role: "Active service boar (Duroc)" },
    { tag: "BR06", pen: "D11", house: "D", breed: "Duroc", age: "Mature", role: "Active service boar (Duroc)" },
    { tag: "BR07", pen: "D12", house: "D", breed: "TBC",   age: "Mature", role: "CASTRATED — for sale, not for breeding" },
  ];
  for (const b of boars) {
    await ensurePig({ tag: b.tag, category: "BOAR", house: b.house, pen: b.pen, breed: b.breed, age: b.age, role: b.role });
  }

  // ---------------- NURSERY GROUPS (House C - weaned) ----------------
  const nursery = [
    { pen: "C5",  count: 9, age: "~1.5mo", born: "2026-03-24", breed: "Large White", note: "Source litter ID needs linking" },
    { pen: "C12", count: 8, age: "~1.5mo", born: "2026-03-24", breed: "",            note: "Source litter unknown — record before move" },
    { pen: "C13", count: 8, age: "~1.5mo", born: "2026-03-24", breed: "",            note: "Source litter unknown — record before move" },
  ];
  for (const n of nursery) {
    await prisma.nurseryGroup.create({
      data: {
        pen: n.pen,
        count: n.count,
        age: n.age,
        born: D(n.born),
        breed: n.breed || null,
        note: n.note,
      },
    });
  }

  // ---------------- HOUSE E (Fattening) - 137 head across 20 pens ----------------
  const houseE = [
    { pen: "E1",  count: 7 }, { pen: "E2",  count: 7 }, { pen: "E3",  count: 6 }, { pen: "E4",  count: 7 }, { pen: "E5",  count: 4 },
    { pen: "E6",  count: 8 }, { pen: "E7",  count: 5 }, { pen: "E8",  count: 6 }, { pen: "E9",  count: 7 }, { pen: "E10", count: 6 },
    { pen: "E11", count: 6 }, { pen: "E12", count: 7 }, { pen: "E13", count: 6 }, { pen: "E14", count: 8 }, { pen: "E15", count: 7 },
    { pen: "E16", count: 8 }, { pen: "E17", count: 8 }, { pen: "E18", count: 8 }, { pen: "E19", count: 8 }, { pen: "E20", count: 8 },
  ];
  for (const p of houseE) {
    await prisma.fattenPen.create({ data: { pen: p.pen, house: "E", count: p.count } });
  }

  // ---------------- HOUSE F (Finishing) - 120 head, 51 sale-ready ----------------
  const houseF = [
    { pen: "F1",  count: 6, age: "5-6mo", saleReady: true  }, { pen: "F2",  count: 5, age: "5-6mo", saleReady: true },
    { pen: "F3",  count: 5, age: "5-6mo", saleReady: true  }, { pen: "F4",  count: 5, age: "5-6mo", saleReady: true },
    { pen: "F5",  count: 5, age: "5-6mo", saleReady: true  }, { pen: "F6",  count: 5, age: "5-6mo", saleReady: true },
    { pen: "F7",  count: 5, age: "5-6mo", saleReady: true  }, { pen: "F8",  count: 5, age: "5-6mo", saleReady: true },
    { pen: "F9",  count: 5, age: "5-6mo", saleReady: true  }, { pen: "F10", count: 5, age: "5-6mo", saleReady: true },
    { pen: "F11", count: 8, age: "2-3mo", saleReady: false, saleWindow: "Aug-Sep 2026" },
    { pen: "F12", count: 7, age: "2-3mo", saleReady: false, saleWindow: "Aug-Sep 2026" },
    { pen: "F13", count: 6, age: "3mo",   saleReady: false, saleWindow: "Aug 2026" },
    { pen: "F14", count: 6, age: "3mo",   saleReady: false, saleWindow: "Aug 2026" },
    { pen: "F15", count: 8, age: "3mo",   saleReady: false, saleWindow: "Aug 2026" },
    { pen: "F16", count: 7, age: "3mo",   saleReady: false, saleWindow: "Aug 2026" },
    { pen: "F17", count: 9, age: "2mo",   saleReady: false, saleWindow: "Sep 2026" },
    { pen: "F18", count: 9, age: "2mo",   saleReady: false, saleWindow: "Sep 2026" },
    { pen: "F19", count: 5, age: "5-6mo", saleReady: true  },
    { pen: "F20", count: 4, age: "5-6mo", saleReady: true  },
  ];
  for (const p of houseF) {
    await prisma.fattenPen.create({
      data: {
        pen: p.pen,
        house: "F",
        count: p.count,
        age: p.age,
        saleReady: p.saleReady,
        saleWindow: p.saleWindow ?? null,
      },
    });
  }

  // ---------------- FARROWING RECORDS (6 samples from HTML) ----------------
  // Round-robin against the sow list so each sample is linked to a real sow.
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const daysAgo = (n) => {
    const d = new Date(today);
    d.setDate(d.getDate() - n);
    return d;
  };
  const samples = [
    { ago: 48, win: 2, fat: 7, bea: 3, dead: 1, remarks: "Sow PIG-022 — calm farrowing" },
    { ago: 35, win: 3, fat: 6, bea: 4, dead: 0, remarks: "Sow PIG-007" },
    { ago: 28, win: 1, fat: 5, bea: 5, dead: 2, remarks: "Sow PIG-031 — one weak piglet" },
    { ago: 20, win: 4, fat: 8, bea: 2, dead: 1, remarks: "Sow PIG-014" },
    { ago: 12, win: 2, fat: 6, bea: 5, dead: 0, remarks: "Sow PIG-019" },
    { ago: 5,  win: 3, fat: 7, bea: 4, dead: 1, remarks: "Sow PIG-025" },
  ];
  const sowList = [...sowByTag.values()];
  for (let i = 0; i < samples.length; i += 1) {
    const s = samples[i];
    const sow = sowList[i % sowList.length];
    const date = daysAgo(s.ago);
    const service = new Date(date);
    service.setDate(service.getDate() - 114); // gestation
    const alive = s.win + s.fat + s.bea;
    await ensureFarrowing({
      sowId: sow.id,
      date,
      pigletsBorn: alive + s.dead,
      pigletsAlive: alive,
      pigletsDead: s.dead,
      winners: s.win,
      fatteners: s.fat,
      beaconners: s.bea,
      remarks: s.remarks,
      service,
    });
  }

  // ---------------- INVENTORY (Piggery slice from HTML) ----------------
  await seedPiggeryInventory();
}

async function seedPiggeryInventory() {
  // From the HTML inventory data — piggery-specific items only.
  const items = [
    { name: "Heat lamps (250W)",          category: "Equipment",  quantity: 8,  unit: "lamps",  location: "Houses A·C farrowing", condition: "good" },
    { name: "Farrowing crates",           category: "Equipment",  quantity: 14, unit: "crates", location: "Houses A·C",           condition: "good" },
    { name: "Feed troughs (large)",       category: "Equipment",  quantity: 32, unit: "units",  location: "All houses",           condition: "good" },
    { name: "Water nipples",              category: "Equipment",  quantity: 48, unit: "units",  location: "All houses",           condition: "good" },
    { name: "Iron injection",             category: "Veterinary", quantity: 60, unit: "doses",  location: "Vet store",            condition: "good" },
    { name: "Tooth clippers",             category: "Veterinary", quantity: 2,  unit: "units",  location: "Vet store",            condition: "good" },
    { name: "Castration scalpels",        category: "Veterinary", quantity: 4,  unit: "units",  location: "Vet store",            condition: "good" },
    { name: "Sow ear tags (numbered)",    category: "Tags",       quantity: 60, unit: "tags",   location: "Office",               condition: "good" },
    { name: "Boar ear tags (BR-prefix)",  category: "Tags",       quantity: 15, unit: "tags",   location: "Office",               condition: "good" },
    { name: "Sawdust bags (50kg)",        category: "Bedding",    quantity: 24, unit: "bags",   location: "Houses A·C",           condition: "good" },
  ];
  let created = 0;
  for (const item of items) {
    const existing = await prisma.piggeryInventoryItem.findFirst({
      where: { name: item.name, deletedAt: null },
    });
    if (existing) {
      await prisma.piggeryInventoryItem.update({
        where: { id: existing.id },
        data: item,
      });
    } else {
      await prisma.piggeryInventoryItem.create({ data: item });
      created += 1;
    }
  }
  console.log(`[piggery seed] inventory: ${items.length} items (${created} new, ${items.length - created} updated).`);
}

async function seedStaff() {
  // Roster matches the v4.2 HTML's `staffData` array verbatim — 21
  // entries — plus a CEO and an Admin so the rest of the app has real
  // creator/approver users. Two people named "Bosco" appear (Vet on
  // all units + Layers Manager) — they're seeded as distinct users
  // with different emails so the payroll table renders both rows.
  //
  // Common temp password — same hash for everyone in seed since this
  // is a dev fixture; production-style staff creation generates random
  // passwords.
  const tempPasswordHash = await bcrypt.hash("Pass-1234", 10);

  // Drop legacy placeholder emails from earlier seed iterations so the
  // payroll table doesn't show stale "J. Kamau" / "S. Wanjiku" rows
  // alongside the new HTML-named roster.
  const legacyEmails = [
    "j.kamau@mwirigi.farm",
    "dr.omondi@mwirigi.farm",
    "s.wanjiku@mwirigi.farm",
    "p.njoroge@mwirigi.farm",
    "m.githinji@mwirigi.farm",
    "m.ochieng@mwirigi.farm",
  ];
  await prisma.user.deleteMany({ where: { email: { in: legacyEmails } } });

  const staff = [
    // ---- System users (not in HTML staffData but needed by the app) ----
    { fullName: "Dr. Mwirigi", email: "ceo@mwirigi.farm",   role: "CEO",   department: "Management", salaryType: "MONTHLY", monthlySalary: 200000, attendanceToday: "PRESENT" },
    { fullName: "ICT Admin",   email: "admin@mwirigi.farm", role: "ADMIN", department: "ICT",        salaryType: "MONTHLY", monthlySalary: 90000,  attendanceToday: "PRESENT" },

    // ---- Managers + supervisors (HTML rows 1-9) ----
    { fullName: "Sam",         email: "sam@mwirigi.farm",          role: "DAIRY_MANAGER",   department: "Dairy",     salaryType: "DAILY", dailyRate: 2000, attendanceToday: "PRESENT", roleLabel: "Dairy Manager + Worker" },
    { fullName: "Bosco",       email: "bosco.vet@mwirigi.farm",    role: "VET",             department: "All units", salaryType: "DAILY", dailyRate: 3500, attendanceToday: "PRESENT", roleLabel: "Farm Vet" },
    { fullName: "Bosco",       email: "bosco.layers@mwirigi.farm", role: "LAYERS_MANAGER",  department: "Layers",    salaryType: "DAILY", dailyRate: 1800, attendanceToday: "PRESENT", roleLabel: "Layers Manager" },
    { fullName: "Simiyu",      email: "simiyu@mwirigi.farm",       role: "PIGGERY_MANAGER", department: "Piggery",   salaryType: "DAILY", dailyRate: 1800, attendanceToday: "PRESENT", roleLabel: "Piggery Manager (A·B·C·EM)" },
    { fullName: "David",       email: "david@mwirigi.farm",        role: "WORKER",          department: "Piggery",   salaryType: "DAILY", dailyRate: 1500, attendanceToday: "PRESENT", roleLabel: "Piggery — Houses D + E" },
    { fullName: "Sam Bwira",   email: "sam.bwira@mwirigi.farm",    role: "WORKER",          department: "Piggery",   salaryType: "DAILY", dailyRate: 1500, attendanceToday: "PRESENT", roleLabel: "Piggery — House F (Finishing)" },
    { fullName: "Mang'ati",    email: "mangati@mwirigi.farm",      role: "FEEDS_MANAGER",   department: "Feeds",     salaryType: "DAILY", dailyRate: 1800, attendanceToday: "PRESENT", roleLabel: "Feed Manager" },
    { fullName: "A. Wangari",  email: "a.wangari@mwirigi.farm",    role: "WORKER",          department: "Ngushish",  salaryType: "DAILY", dailyRate: 1800, attendanceToday: "PRESENT", roleLabel: "Horticulture Mgr" },
    { fullName: "T. Mwaura",   email: "t.mwaura@mwirigi.farm",     role: "FEEDLOT_MANAGER", department: "Feedlot",   salaryType: "DAILY", dailyRate: 1500, attendanceToday: "ABSENT",  roleLabel: "Feedlot Supervisor" },

    // ---- Dairy workers (HTML rows 10-19) ----
    { fullName: "Ronald",      email: "ronald@mwirigi.farm",   role: "WORKER", department: "Dairy",  salaryType: "DAILY", dailyRate: 900, attendanceToday: "PRESENT",  roleLabel: "Dairy Worker" },
    { fullName: "Musyoka",     email: "musyoka@mwirigi.farm",  role: "WORKER", department: "Dairy",  salaryType: "DAILY", dailyRate: 900, attendanceToday: "PRESENT",  roleLabel: "Dairy Worker" },
    { fullName: "Joshua",      email: "joshua@mwirigi.farm",   role: "WORKER", department: "Dairy",  salaryType: "DAILY", dailyRate: 900, attendanceToday: "PRESENT",  roleLabel: "Dairy Worker" },
    { fullName: "Ivan",        email: "ivan@mwirigi.farm",     role: "WORKER", department: "Dairy",  salaryType: "DAILY", dailyRate: 900, attendanceToday: "HALF_DAY", roleLabel: "Dairy Worker" }, // HTML "late" → half day
    { fullName: "Jacob",       email: "jacob@mwirigi.farm",    role: "WORKER", department: "Dairy",  salaryType: "DAILY", dailyRate: 900, attendanceToday: "PRESENT",  roleLabel: "Dairy Worker" },
    { fullName: "Mukisa",      email: "mukisa@mwirigi.farm",   role: "WORKER", department: "Dairy",  salaryType: "DAILY", dailyRate: 900, attendanceToday: "PRESENT",  roleLabel: "Dairy Worker" },
    { fullName: "Toby",        email: "toby@mwirigi.farm",     role: "WORKER", department: "Dairy",  salaryType: "DAILY", dailyRate: 900, attendanceToday: "ABSENT",   roleLabel: "Dairy Worker" },
    { fullName: "Karis",       email: "karis@mwirigi.farm",    role: "WORKER", department: "Dairy",  salaryType: "DAILY", dailyRate: 900, attendanceToday: "PRESENT",  roleLabel: "Dairy Worker" },
    { fullName: "John",        email: "john@mwirigi.farm",     role: "WORKER", department: "Dairy",  salaryType: "DAILY", dailyRate: 900, attendanceToday: "PRESENT",  roleLabel: "Dairy Worker" },
    { fullName: "Nick",        email: "nick@mwirigi.farm",     role: "WORKER", department: "Dairy",  salaryType: "DAILY", dailyRate: 900, attendanceToday: "PRESENT",  roleLabel: "Dairy Worker" },

    // ---- Other unit workers (HTML rows 20-21) ----
    { fullName: "B. Otieno",   email: "b.otieno@mwirigi.farm", role: "WORKER", department: "Layers",  salaryType: "DAILY", dailyRate: 900, attendanceToday: "PRESENT", roleLabel: "Layer House Worker" },
    { fullName: "F. Njuki",    email: "f.njuki@mwirigi.farm",  role: "WORKER", department: "Piggery", salaryType: "DAILY", dailyRate: 900, attendanceToday: "ABSENT",  roleLabel: "Piggery Worker" },
  ];

  const created = [];
  for (const s of staff) {
    // Upsert by email so re-running the seed brings existing rows back
    // in sync with the master roster — department, dailyRate, jobTitle,
    // etc. all reflect the source-of-truth here.
    const u = await prisma.user.upsert({
      where: { email: s.email.toLowerCase() },
      create: {
        userName: s.fullName,
        email: s.email.toLowerCase(),
        password: tempPasswordHash,
        role: s.role,
        department: s.department,
        jobTitle: s.roleLabel ?? null,
        salaryType: s.salaryType,
        dailyRate: s.dailyRate ?? null,
        monthlySalary: s.monthlySalary ?? null,
        mustChangePassword: true,
        emailVerified: true,
        isActive: true,
      },
      update: {
        userName: s.fullName,
        role: s.role,
        department: s.department,
        jobTitle: s.roleLabel ?? null,
        salaryType: s.salaryType,
        dailyRate: s.dailyRate ?? null,
        monthlySalary: s.monthlySalary ?? null,
      },
    });
    created.push({ row: s, user: u });
  }

  // Seed today's attendance from each row's `attendanceToday` field.
  // Mirrors the HTML mockup: 18 present, 1 half-day (Ivan late), 3
  // absent (Toby, T. Mwaura, F. Njuki).
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  for (const { row, user } of created) {
    const status = row.attendanceToday ?? "PRESENT";
    await prisma.attendance.upsert({
      where: { userId_date: { userId: user.id, date: today } },
      create: { userId: user.id, date: today, status },
      update: { status },
    });
  }

  // Seed today's tasks — 6 rows matching the HTML mockup's task table.
  // Each task is created by the CEO (req.user.id surrogate in the seed).
  const ceoEntry = created.find(({ user }) => user.role === "CEO");
  const ceo = ceoEntry?.user;
  // Match by full name + email to disambiguate the two "Bosco"s.
  const findByName = (name, email) => {
    const exact = created.find(
      ({ user }) => user.userName === name && user.email === email,
    );
    if (exact) return exact.user;
    return created.find(({ user }) => user.userName === name)?.user;
  };
  const tasks = [
    { to: "Sam",        toEmail: "sam@mwirigi.farm",          unit: "Dairy",    title: "Supervise AM milking — Houses A & B", priority: "HIGH",   status: "DONE" },
    { to: "Joshua",     toEmail: "joshua@mwirigi.farm",       unit: "Dairy",    title: "PM milking — House C cows",            priority: "HIGH",   status: "PENDING" },
    { to: "Simiyu",     toEmail: "simiyu@mwirigi.farm",       unit: "Piggery",  title: "Check PIG-012 farrowing pen",          priority: "HIGH",   status: "IN_PROGRESS" },
    { to: "Bosco",      toEmail: "bosco.layers@mwirigi.farm", unit: "Layers",   title: "Egg collection — all houses",          priority: "MEDIUM", status: "DONE" },
    { to: "A. Wangari", toEmail: "a.wangari@mwirigi.farm",    unit: "Ngushish", title: "Irrigation — maize field",             priority: "MEDIUM", status: "DONE" },
    { to: "Mang'ati",   toEmail: "mangati@mwirigi.farm",      unit: "Feeds",    title: "Order mineral premix",                 priority: "HIGH",   status: "PENDING" },
  ];

  if (ceo) {
    for (const t of tasks) {
      const assignee = findByName(t.to, t.toEmail);
      if (!assignee) continue;
      const existing = await prisma.task.findFirst({
        where: {
          assignedToId: assignee.id,
          title: t.title,
          createdAt: { gte: today },
        },
      });
      if (existing) continue;
      await prisma.task.create({
        data: {
          assignedToId: assignee.id,
          assignedById: ceo.id,
          unit: t.unit,
          title: t.title,
          priority: t.priority,
          status: t.status,
        },
      });
    }
  }

  // ---- Sample salary advances for the current month ----
  // Three rows with different statuses so the Advance pill UI has
  // every state to render. Idempotent on (userId, type, amount, month).
  const m = today.getMonth() + 1;
  const y = today.getFullYear();
  const advanceSeeds = [
    { name: "Sam",     email: "sam@mwirigi.farm",     amount: 5000, status: "APPROVED", reason: "School fees — Q2 instalment" },
    { name: "Ronald",  email: "ronald@mwirigi.farm",  amount: 3000, status: "PENDING",  reason: "Medical — clinic visit" },
    { name: "Musyoka", email: "musyoka@mwirigi.farm", amount: 2000, status: "APPROVED", reason: "Family emergency" },
  ];
  for (const a of advanceSeeds) {
    const target = findByName(a.name, a.email);
    if (!target) continue;
    const existing = await prisma.payrollAdjustment.findFirst({
      where: {
        userId: target.id,
        type: "ADVANCE",
        amount: a.amount,
        month: m,
        year: y,
      },
    });
    if (existing) continue;
    await prisma.payrollAdjustment.create({
      data: {
        userId: target.id,
        type: "ADVANCE",
        status: a.status,
        amount: a.amount,
        month: m,
        year: y,
        reason: a.reason,
        approvedAt: a.status === "APPROVED" ? new Date() : null,
        approvedById: a.status === "APPROVED" && ceo ? ceo.id : null,
      },
    });
  }
}

// =====================================================================
// HEALTH & VACCINES MODULE
// =====================================================================
// Seeds the rows needed for UI parity with the HTML mockup:
//   * 6 VaccineProtocol rows (FMD, LSD, Anthrax, Brucellosis, ASFV, PPR)
//     plus their last administered records. Brooder vaccines (Newcastle,
//     Gumboro, Fowl typhoid) are NOT seeded here — they're composed at
//     read time from the existing brooder protocol + BrooderVaccination
//     records seeded by seedBrooderUnit().
//   * 3 active Treatments (DAISY/MW-133/PIG-031).
//   * 3 VetProtocolTemplate rows (Chicks/Calves/Piglets) with steps.
//
// Today's reference date for KPI math: 2026-05-07.
async function seedHealth() {
  // --------------------------------------------------------------
  // VaccineProtocols + last-administered VaccinationRecord per row
  // --------------------------------------------------------------
  // Each entry pairs a protocol definition with the most recent
  // administration record so the schedule view reflects the HTML's
  // "Last done" column verbatim.
  const protocolSeed = [
    {
      name: "FMD",
      unit: "Dairy",
      species: "Cow",
      type: "ANNUAL",
      allowedMonths: [2, 3],
      notes: "Foot-and-mouth disease — calendar-locked Feb/Mar.",
      lastAdministered: new Date("2025-03-15T00:00:00.000Z"),
      animalCount: 56,
    },
    {
      name: "Lumpy Skin Disease",
      unit: "Dairy",
      species: "Cow",
      type: "ANNUAL",
      allowedMonths: [8],
      notes: "Whole-herd LSD vaccination, Aug each year.",
      lastAdministered: new Date("2025-08-15T00:00:00.000Z"),
      animalCount: 56,
    },
    {
      name: "Anthrax",
      unit: "Dairy",
      species: "Cow",
      type: "ANNUAL",
      allowedMonths: [10, 11],
      notes: "Whole-herd anthrax vaccination, Oct/Nov each year.",
      lastAdministered: new Date("2025-10-15T00:00:00.000Z"),
      animalCount: 56,
    },
    {
      name: "Brucellosis",
      unit: "Dairy",
      species: "Cow",
      type: "RECURRING",
      recurrenceMonths: 6,
      notes: "Brucellosis screening + vaccination every 6 months.",
      lastAdministered: new Date("2026-03-15T00:00:00.000Z"),
      // Backfill prior cycle so compliance reflects an operationally
      // well-managed herd.
      historical: [new Date("2025-09-15T00:00:00.000Z")],
      animalCount: 56,
    },
    {
      name: "ASFV monitoring",
      unit: "Piggery",
      species: "Pig",
      type: "RECURRING",
      recurrenceMonths: 3,
      notes: "African swine fever surveillance — every 3 months.",
      lastAdministered: new Date("2026-02-15T00:00:00.000Z"),
      // 3-month interval needs more history for compliance to make sense.
      historical: [
        new Date("2025-08-15T00:00:00.000Z"),
        new Date("2025-11-15T00:00:00.000Z"),
      ],
      animalCount: 148,
    },
    {
      name: "PPR",
      unit: "Doopers",
      species: "Sheep",
      type: "RECURRING",
      recurrenceMonths: 6,
      // Anchored at Nov 11 so today (May 7) sits inside the 7-day KPI
      // window (PPR next due May 11 → 4 days away → counted in
      // "Vaccines due (7d)").
      lastAdministered: new Date("2025-11-11T00:00:00.000Z"),
      historical: [new Date("2025-05-11T00:00:00.000Z")],
      animalCount: 84,
    },
  ];

  for (const p of protocolSeed) {
    const existing = await prisma.vaccineProtocol.findFirst({
      where: { name: p.name, unit: p.unit },
    });
    const protocol =
      existing ??
      (await prisma.vaccineProtocol.create({
        data: {
          name: p.name,
          unit: p.unit,
          species: p.species,
          type: p.type,
          allowedMonths: p.allowedMonths ?? [],
          recurrenceMonths: p.recurrenceMonths ?? null,
          dayOffsetStart: null,
          dayOffsetEnd: null,
          notes: p.notes ?? null,
        },
      }));

    if (existing) {
      await prisma.vaccineProtocol.update({
        where: { id: existing.id },
        data: {
          species: p.species,
          type: p.type,
          allowedMonths: p.allowedMonths ?? [],
          recurrenceMonths: p.recurrenceMonths ?? null,
          notes: p.notes ?? null,
        },
      });
    }

    // Record the last administration + any historical cycles, idempotent
    // on (protocolId, administeredAt).
    const allRecords = [p.lastAdministered, ...(p.historical ?? [])];
    for (const at of allRecords) {
      const recordExisting = await prisma.vaccinationRecord.findFirst({
        where: { protocolId: protocol.id, administeredAt: at },
      });
      if (!recordExisting) {
        await prisma.vaccinationRecord.create({
          data: {
            protocolId: protocol.id,
            unit: p.unit,
            animalCount: p.animalCount,
            administeredAt: at,
            notes: null,
          },
        });
      }
    }
  }

  // --------------------------------------------------------------
  // Active treatments — 3 rows from the HTML mockup
  // --------------------------------------------------------------
  // Day-count for the status pill is derived at read time
  // (today - startDate); the explicit `status` captures vet judgement
  // (ACTIVE vs IMPROVING).
  const treatmentSeed = [
    {
      tag: "DAISY",
      unit: "Dairy",
      diagnosis: "Mastitis (suspected)",
      medication: "Amoxicillin intramammary",
      startDate: new Date("2026-05-05T00:00:00.000Z"),
      status: "ACTIVE",
      attendingVet: "Bosco",
    },
    {
      tag: "MW-133",
      unit: "Dairy",
      diagnosis: "Foot rot",
      medication: "Oxytetracycline + hoof trim",
      startDate: new Date("2026-05-03T00:00:00.000Z"),
      status: "IMPROVING",
      attendingVet: "Bosco",
    },
    {
      tag: "PIG-031",
      unit: "Piggery",
      diagnosis: "Respiratory",
      medication: "Tylosin in feed",
      startDate: new Date("2026-05-04T00:00:00.000Z"),
      status: "ACTIVE",
      attendingVet: "Bosco",
    },
  ];

  for (const t of treatmentSeed) {
    const existing = await prisma.treatment.findFirst({
      where: {
        tag: t.tag,
        unit: t.unit,
        startDate: t.startDate,
      },
    });
    if (existing) {
      await prisma.treatment.update({
        where: { id: existing.id },
        data: {
          diagnosis: t.diagnosis,
          medication: t.medication,
          status: t.status,
          attendingVet: t.attendingVet,
        },
      });
    } else {
      await prisma.treatment.create({ data: t });
    }
  }

  // --------------------------------------------------------------
  // Vet protocol reference templates — 3 tabs (Chicks/Calves/Piglets)
  // --------------------------------------------------------------
  // Each template's steps are rewritten on every seed run so HTML edits
  // flow through without leaving stale rows behind.
  const templateSeed = [
    {
      group: "CHICKS",
      title: "Chicks (Day 1 → Cage)",
      steps: [
        {
          dayLabel: "Day 1",
          procedure: "Receive day-old chicks.",
          notes: "Place in brooder, ensure heat, water and starter feed.",
        },
        {
          dayLabel: "Day 12",
          procedure: "Newcastle vaccine",
          notes: "first dose.",
        },
        { dayLabel: "Day 15", procedure: "Gumboro (IBD) vaccine.", notes: null },
        {
          dayLabel: "Week 6 (Day 42)",
          procedure: "Newcastle vaccine",
          notes: "repeat.",
        },
        {
          dayLabel: "Week 8-9",
          procedure: "Fowl typhoid + Fowl pox vaccines.",
          notes: null,
        },
        { dayLabel: "Week 11", procedure: "Coryza vaccine.", notes: null },
        {
          dayLabel: "Week 12",
          procedure: "Move from brooder to cage.",
          notes:
            "5,000 sold as POL pullets, 5,000 retained for Houses A & B replacement (2,500 each).",
        },
        {
          dayLabel: "Week 14",
          procedure: "Egg drop syndrome vaccine.",
          notes: null,
        },
        {
          dayLabel: "Monthly Days 1-3",
          procedure: "Vitamins",
          notes: "administered to manage stress.",
        },
        {
          dayLabel: "Days 15-17",
          procedure: "Vitamins",
          notes: "mid-month dose.",
        },
        { dayLabel: "Every 3 months", procedure: "Deworming.", notes: null },
      ],
    },
    {
      group: "CALVES",
      title: "Calves (Birth → Service)",
      steps: [
        {
          dayLabel: "At birth",
          procedure: "Weigh the calf",
          notes: "immediately after birth and record.",
        },
        {
          dayLabel: "Within 4h",
          procedure: "Bottle-feed mother's colostrum.",
          notes: null,
        },
        {
          dayLabel: "Day 3",
          procedure: "Introduce dry matter",
          notes: "hay and calf pellets.",
        },
        {
          dayLabel: "Day 1-150",
          procedure: "6 L milk daily",
          notes:
            "2 L morning, 2 L afternoon, 2 L evening, until 5 months.",
        },
        {
          dayLabel: "2 months",
          procedure: "First deworming.",
          notes: "Then monthly until 6 months.",
        },
        {
          dayLabel: "3 months",
          procedure: "Wean",
          notes:
            "when weight has doubled. Switch to dairy meal + dry matter + small ratio of napier. First vaccines: FMD, Lumpy Skin, Anthrax.",
        },
        {
          dayLabel: "6 months+",
          procedure: "Deworming every 3 months",
          notes: 'no longer "calf".',
        },
        { dayLabel: "Monthly", procedure: "Vitamins.", notes: null },
        {
          dayLabel: "14-15 months",
          procedure: "Ready to serve",
          notes: "when on heat cycle.",
        },
      ],
    },
    {
      group: "PIGLETS",
      title: "Piglets (Farrow → Market)",
      steps: [
        {
          dayLabel: "Gestation",
          procedure: "3 weeks 3 days",
          notes: "gestation period (≈ 24 days).",
        },
        {
          dayLabel: "At farrowing",
          procedure: "Suckle immediately.",
          notes: "Use sawdust as bedding.",
        },
        {
          dayLabel: "Day 3",
          procedure: "Administer iron, do tooth clipping",
          notes: "and docking.",
        },
        {
          dayLabel: "Day 21",
          procedure: "Iron (2nd dose), castrate males.",
          notes: null,
        },
        {
          dayLabel: "2 months",
          procedure: "Wean from sow.",
          notes:
            "No vaccines needed (natural insemination). Introduce growers feed.",
        },
        {
          dayLabel: "4 months",
          procedure: "Add protein",
          notes: "to help with fattening.",
        },
        { dayLabel: "6 months", procedure: "Ready for market.", notes: null },
        {
          dayLabel: "7 months",
          procedure: "Mature boar",
          notes: "ready to serve females.",
        },
      ],
    },
  ];

  for (const t of templateSeed) {
    const existing = await prisma.vetProtocolTemplate.findUnique({
      where: { group: t.group },
    });
    const tpl =
      existing ??
      (await prisma.vetProtocolTemplate.create({
        data: { group: t.group, title: t.title },
      }));
    if (existing && existing.title !== t.title) {
      await prisma.vetProtocolTemplate.update({
        where: { id: tpl.id },
        data: { title: t.title },
      });
    }
    // Replace step rows so HTML edits flow through cleanly.
    await prisma.vetProtocolStep.deleteMany({ where: { templateId: tpl.id } });
    await prisma.vetProtocolStep.createMany({
      data: t.steps.map((s, i) => ({
        templateId: tpl.id,
        order: i,
        dayLabel: s.dayLabel,
        procedure: s.procedure,
        notes: s.notes ?? null,
      })),
    });
  }
}

// =====================================================================
// NGUSHISH (horticulture / irrigation / fodder)
// =====================================================================
//
// Mirrors the HTML mockup's crop register exactly (5 rows). All crops are
// flagged irrigated since the unit subtitle is "Horticulture · Irrigation
// · Fodder supply". A single today-dated dispatch (420 kg / KSh 8,400)
// keeps the "Today" KPIs in sync with the mockup numbers.
async function seedNgushish() {
  // Master block register — Ngusishi Farm Template (10 May 2026).
  // 21 blocks · 17.95 acres · Season 2025/26 · Manager: A. Wangari.
  // Status mapping (HTML → CropStatus enum):
  //   ready          → READY
  //   growing        → GROWING
  //   awaiting       → AWAITING
  //   infrastructure → INFRASTRUCTURE
  const blocks = [
    // Block A — 9 plots
    { block: "A1i",   area: 0.5, name: "Homestead / Dam",   status: "INFRASTRUCTURE", age: "—",            dueDate: null,         action: "Permanent structure — no harvest",              season: "Perennial"   },
    { block: "A1ii",  area: 0.5, name: "Cabbage / Avocado", status: "GROWING",        age: "2½ months",    dueDate: "2026-05-24", action: "Dual crop. Monitor avocado spacing.",           season: "Short Rain"  },
    { block: "A2i",   area: 0.5, name: "Cabbage",           status: "GROWING",        age: "1½ months",    dueDate: "2026-06-15", action: "Irrigate weekly. Top-dress now.",               season: "Short Rain"  },
    { block: "A2ii",  area: 0.5, name: "Maize",             status: "GROWING",        age: "3 weeks",      dueDate: "2026-10-01", action: "Early stage — weed control critical.",          season: "Long Rain"   },
    { block: "A3i,ii",area: 1.4, name: "Cabbage",           status: "GROWING",        age: "2 months",     dueDate: "2026-06-10", action: "Largest block. Check for caterpillars.",        season: "Short Rain"  },
    { block: "A4i",   area: 1.2, name: "Potatoes",          status: "GROWING",        age: "2 weeks",      dueDate: "2026-08-01", action: "Early growth — hill up at 4 weeks.",            season: "Long Rain"   },
    { block: "A4ii",  area: 1.2, name: "Potatoes",          status: "AWAITING",       age: "Not planted",  dueDate: "2026-05-18", action: "Prepare beds. Source certified seed.",          season: "Long Rain"   },
    { block: "A5i",   area: 0.5, name: "Cabbage",           status: "READY",          age: "3 months",     dueDate: "2026-05-10", action: "HARVEST NOW — peak maturity.",                  season: "Short Rain"  },
    { block: "A5ii",  area: 1.2, name: "Cabbage",           status: "GROWING",        age: "2½ months",    dueDate: "2026-06-01", action: "Approaching harvest. Arrange market.",          season: "Short Rain"  },
    // Block B — 5 plots
    { block: "B1",    area: 0.75,name: "Maize",             status: "AWAITING",       age: "Not planted",  dueDate: "2026-05-25", action: "Prepare land. Apply basal fertiliser.",         season: "Long Rain"   },
    { block: "B2",    area: 0.5, name: "Maize",             status: "GROWING",        age: "3 weeks",      dueDate: "2026-08-30", action: "Early stage — weed urgently.",                  season: "Long Rain"   },
    { block: "B3",    area: 0.5, name: "Maize",             status: "AWAITING",       age: "Not planted",  dueDate: "2026-05-25", action: "Plough and harrow. Lime if needed.",            season: "Long Rain"   },
    { block: "B4",    area: 1.2, name: "Maize",             status: "GROWING",        age: "1½ months",    dueDate: "2026-08-15", action: "Side-dress urea at tasselling stage.",          season: "Long Rain"   },
    { block: "B5",    area: 1.5, name: "Potatoes",          status: "READY",          age: "4 months",     dueDate: "2026-05-10", action: "HARVEST NOW — dry before sacking.",             season: "Short Rain"  },
    // Block C — 4 plots
    { block: "C1i",   area: 1.0, name: "Maize",             status: "GROWING",        age: "4 months",     dueDate: "2026-07-05", action: "Nearing maturity. Field-dry before harvest.",   season: "Long Rain"   },
    { block: "C1ii",  area: 1.0, name: "Maize",             status: "READY",          age: "5 months",     dueDate: "2026-05-10", action: "HARVEST NOW — store immediately.",              season: "Short Rain"  },
    { block: "C2",    area: 1.25,name: "Potatoes",          status: "AWAITING",       age: "Not planted",  dueDate: "2026-05-30", action: "Source seed potatoes now.",                     season: "Long Rain"   },
    { block: "C3",    area: 0.75,name: "Cabbage",           status: "AWAITING",       age: "Not planted",  dueDate: "2026-05-15", action: "URGENT — plant in 5 days!",                     season: "Short Rain"  },
    // Block D — 2 plots
    { block: "D1",    area: 1.0, name: "Maize",             status: "GROWING",        age: "2 weeks",      dueDate: "2026-09-10", action: "Very early — protect from birds.",              season: "Long Rain"   },
    { block: "D2",    area: 1.0, name: "Maize",             status: "READY",          age: "5 months",     dueDate: "2026-05-10", action: "HARVEST NOW — organise labour.",                season: "Short Rain"  },
  ];

  // Wipe + reseed. Harvest/Dispatch/IrrigationLog cascade-delete via FK
  // when their parent Crop row is removed.
  await prisma.crop.deleteMany({});
  await prisma.ngushishInventoryItem.deleteMany({});

  const D = (s) => (s ? new Date(`${s}T00:00:00Z`) : null);

  const cropByBlock = new Map();
  for (const b of blocks) {
    const isInfra = b.status === "INFRASTRUCTURE";
    const isAwaiting = b.status === "AWAITING";
    const crop = await prisma.crop.create({
      data: {
        name: b.name,
        acreage: b.area,
        block: b.block,
        age: b.age,
        dueDate: D(b.dueDate),
        season: b.season,
        actionNote: b.action,
        status: b.status,
        isPerennial: b.season === "Perennial",
        irrigated: !isInfra && !isAwaiting,
        // expectedHarvest tracks the next milestone for non-awaiting,
        // non-infrastructure rows so reports/queries that key off it
        // keep working.
        expectedHarvest: !isInfra && !isAwaiting ? D(b.dueDate) : null,
      },
    });
    cropByBlock.set(b.block, crop);
  }

  // Today's dispatch — A5i cabbage (HARVEST NOW). Mirrors the HTML
  // "Produce dispatched today: 420 kg / Revenue today: KSh 8,400" KPIs.
  const a5i = cropByBlock.get("A5i");
  if (a5i) {
    await prisma.produceDispatch.create({
      data: {
        cropId: a5i.id,
        quantityKg: 420,
        destination: "Stopover shop",
        revenue: 8400,
        dispatchDate: new Date(),
        buyerName: "Stopover walk-ins",
        notes: "A5i cabbage harvest — peak maturity.",
      },
    });
  }

  // Irrigation logs for the actively-growing cabbage and potato blocks.
  const daysBack = (n) => {
    const d = new Date();
    d.setDate(d.getDate() - n);
    return d;
  };
  const irrigationSeeds = [
    { block: "A1ii", daysAgo: 0, minutes: 45, source: "Borehole" },
    { block: "A2i",  daysAgo: 1, minutes: 40, source: "Borehole" },
    { block: "A4i",  daysAgo: 2, minutes: 60, source: "Borehole" },
    { block: "A5ii", daysAgo: 1, minutes: 50, source: "Borehole" },
  ];
  for (const s of irrigationSeeds) {
    const crop = cropByBlock.get(s.block);
    if (!crop) continue;
    await prisma.irrigationLog.create({
      data: {
        cropId: crop.id,
        irrigationDate: daysBack(s.daysAgo),
        durationMinutes: s.minutes,
        waterSource: s.source,
      },
    });
  }

  // -------- Inventory — 16 items verbatim from HTML --------
  const inventory = [
    { name: "Cabbage seedlings",              category: "Inputs",        quantity: 200,  unit: "units",   location: "Nursery",      condition: "good" },
    { name: "Certified maize seed (DK 8033)", category: "Inputs",        quantity: 8,    unit: "kg",      location: "Store",        condition: "good" },
    { name: "Certified seed potatoes",        category: "Inputs",        quantity: 0,    unit: "kg",      location: "Store",        condition: "out"  },
    { name: "Basal fertiliser (DAP)",         category: "Inputs",        quantity: 6,    unit: "bags",    location: "Store",        condition: "good" },
    { name: "Top-dress fertiliser (CAN)",     category: "Inputs",        quantity: 4,    unit: "bags",    location: "Store",        condition: "good" },
    { name: "Urea (maize side-dress)",        category: "Inputs",        quantity: 2,    unit: "bags",    location: "Store",        condition: "good" },
    { name: "Lime",                           category: "Inputs",        quantity: 3,    unit: "bags",    location: "Store",        condition: "good" },
    { name: "Hoes (jembes)",                  category: "Equipment",     quantity: 8,    unit: "units",   location: "Tool shed",    condition: "good" },
    { name: "Pangas",                         category: "Equipment",     quantity: 6,    unit: "units",   location: "Tool shed",    condition: "good" },
    { name: "Knapsack sprayers (16L)",        category: "Equipment",     quantity: 3,    unit: "units",   location: "Tool shed",    condition: "good" },
    { name: "Wheelbarrows",                   category: "Equipment",     quantity: 2,    unit: "units",   location: "Tool shed",    condition: "good" },
    { name: "Drip irrigation lines",          category: "Equipment",     quantity: 1500, unit: "m",       location: "Field A-B",    condition: "good" },
    { name: "Cabbage crates (empty)",         category: "Equipment",     quantity: 120,  unit: "crates",  location: "Pack-house",   condition: "good" },
    { name: "Potato/maize sacks (empty)",     category: "Equipment",     quantity: 80,   unit: "sacks",   location: "Pack-house",   condition: "good" },
    { name: "Pyrethrin (caterpillar control)",category: "Agrochemicals", quantity: 2,    unit: "L",       location: "Store",        condition: "good" },
    { name: "Fungicide (potato blight)",      category: "Agrochemicals", quantity: 1,    unit: "L",       location: "Store",        condition: "low"  },
  ];
  for (const item of inventory) {
    await prisma.ngushishInventoryItem.create({ data: item });
  }
  console.log(`[ngushish seed] 21 blocks · ${inventory.length} inventory items.`);
}

// =====================================================================
// FEEDS MANAGEMENT
// =====================================================================
//
// Mirrors the HTML mockup's raw material inventory exactly: 18 materials,
// 3 bulk feed entries, and 7 daily-distribution rows (one per livestock
// unit). Stock-vs-daily-use figures are tuned so the computed status
// distribution lands close to the spec's "2 critical / 4 low / 12
// adequate" example.
//
// Idempotent: re-runs upsert by name (materials), enum type (bulk feed),
// and livestockUnit (distribution).
async function seedFeeds() {
  const materials = [
    { name: "Maize Germ",        category: "MAIZE_GERM",  packSize: "50 kg bag",      stockOnHandKg: 540,  dailyUseKg: 120, supplier: "Pembe Flour Mills",   costPerKg: 38 },
    { name: "Soya Meal",         category: "SOYA",        packSize: "50 kg bag",      stockOnHandKg: 300,  dailyUseKg: 65,  supplier: "Bidco Africa",         costPerKg: 75 },
    { name: "Wheat Bran",        category: "WHEAT_BRAN",  packSize: "50 kg bag",      stockOnHandKg: 820,  dailyUseKg: 90,  supplier: "Unga Group",           costPerKg: 22 },
    { name: "Cotton Seed Cake",  category: "COTTON_SEED", packSize: "50 kg bag",      stockOnHandKg: 410,  dailyUseKg: 50,  supplier: "Kitui Cotton Mills",   costPerKg: 48 },
    { name: "Fish Meal",         category: "FISH_MEAL",   packSize: "50 kg bag",      stockOnHandKg: 120,  dailyUseKg: 18,  supplier: "Lake Victoria Fishers",costPerKg: 180 },
    { name: "Lime",              category: "LIME",        packSize: "50 kg bag",      stockOnHandKg: 200,  dailyUseKg: 12,  supplier: "Athi River Mining",    costPerKg: 14 },
    { name: "Layers Premix",     category: "PREMIX",      packSize: "25 kg bag",      stockOnHandKg: 75,   dailyUseKg: 6,   supplier: "Coopers K-Brands",     costPerKg: 320 },
    { name: "Broiler Premix",    category: "PREMIX",      packSize: "25 kg bag",      stockOnHandKg: 60,   dailyUseKg: 5,   supplier: "Coopers K-Brands",     costPerKg: 340 },
    { name: "Sunflower Cake",    category: "SUNFLOWER",   packSize: "50 kg bag",      stockOnHandKg: 380,  dailyUseKg: 45,  supplier: "Kapa Oil Refineries",  costPerKg: 52 },
    { name: "Molasses",          category: "OTHER",       packSize: "200 L drum",     stockOnHandKg: 500,  dailyUseKg: 30,  supplier: "Mumias Sugar",         costPerKg: 18 },
    { name: "Salt",              category: "OTHER",       packSize: "50 kg bag",      stockOnHandKg: 90,   dailyUseKg: 3,   supplier: "Magadi Salt",          costPerKg: 16 },
    { name: "DCP",               category: "OTHER",       packSize: "50 kg bag",      stockOnHandKg: 130,  dailyUseKg: 7,   supplier: "Polychem East Africa", costPerKg: 95 },
    { name: "Lysine",            category: "OTHER",       packSize: "25 kg bag",      stockOnHandKg: 25,   dailyUseKg: 1,   supplier: "Adisseo",              costPerKg: 410 },
    { name: "Methionine",        category: "OTHER",       packSize: "25 kg bag",      stockOnHandKg: 18,   dailyUseKg: 1,   supplier: "Evonik",               costPerKg: 480 },
    { name: "Toxin Binder",      category: "OTHER",       packSize: "25 kg bag",      stockOnHandKg: 22,   dailyUseKg: 1,   supplier: "Trouw Nutrition",      costPerKg: 230 },
    { name: "Pig Concentrate",   category: "OTHER",       packSize: "50 kg bag",      stockOnHandKg: 160,  dailyUseKg: 15,  supplier: "Sigma Feeds",          costPerKg: 88 },
    { name: "Dairy Meal",        category: "OTHER",       packSize: "70 kg bag",      stockOnHandKg: 700,  dailyUseKg: 95,  supplier: "Unga Farm Care",       costPerKg: 62 },
    { name: "Calf Starter",      category: "OTHER",       packSize: "50 kg bag",      stockOnHandKg: 240,  dailyUseKg: 20,  supplier: "Unga Farm Care",       costPerKg: 78 },
  ];

  // Idempotent upsert — name is @unique on FeedMaterial, so we can use
  // upsert directly. Re-runs sync stock & daily use so updated values in
  // this seed propagate without resetting the DB.
  for (const m of materials) {
    await prisma.feedMaterial.upsert({
      where: { name: m.name },
      update: {
        category: m.category,
        packSize: m.packSize,
        stockOnHandKg: m.stockOnHandKg,
        dailyUseKg: m.dailyUseKg,
        supplier: m.supplier,
        costPerKg: m.costPerKg,
      },
      create: m,
    });
  }

  // Bulk feed: silage pit + standing forage. `type` is @unique so upsert
  // by enum value.
  const bulkFeed = [
    { type: "SILAGE",       quantity: 18, unit: "PERCENT", status: "REPLENISH_SOON", notes: "Pit at 18% — replenish before next ration cycle." },
    { type: "NAPIER",       quantity: 4,  unit: "ACRES",   status: "ACTIVE",          notes: "Standing crop, monthly cuts." },
    { type: "MAIZE_SILAGE", quantity: 3,  unit: "ACRES",   status: "MATURING",        notes: "Tasseling — harvest in ~6 weeks." },
  ];
  for (const b of bulkFeed) {
    await prisma.bulkFeedStock.upsert({
      where: { type: b.type },
      update: {
        quantity: b.quantity,
        unit: b.unit,
        status: b.status,
        notes: b.notes,
      },
      create: b,
    });
  }

  // Daily distribution per livestock unit. Idempotent: each unit gets a
  // single row that gets updated in place on re-runs (matches the
  // service's upsertDistribution behavior).
  const distribution = [
    { livestockUnit: "DAIRY",    animalCount: 42,    concentrateKg: 378, silageKg: 1260, napierKg: 630 },
    { livestockUnit: "CALVES",   animalCount: 30,    concentrateKg: 45,  silageKg: 0,    napierKg: 0   },
    { livestockUnit: "DOOPERS",  animalCount: 84,    concentrateKg: 0,   silageKg: 0,    napierKg: 420 },
    { livestockUnit: "FEEDLOT",  animalCount: 12,    concentrateKg: 96,  silageKg: 240,  napierKg: 0   },
    { livestockUnit: "PIGGERY",  animalCount: 148,   concentrateKg: 150, silageKg: 0,    napierKg: 0   },
    { livestockUnit: "LAYERS",   animalCount: 6130,  concentrateKg: 613, silageKg: 0,    napierKg: 0   },
    { livestockUnit: "BROODER",  animalCount: 10000, concentrateKg: 600, silageKg: 0,    napierKg: 0   },
  ];
  for (const d of distribution) {
    const existing = await prisma.feedDistribution.findFirst({
      where: { livestockUnit: d.livestockUnit },
      orderBy: { recordedAt: "desc" },
    });
    if (existing) {
      await prisma.feedDistribution.update({
        where: { id: existing.id },
        data: { ...d, recordedAt: new Date() },
      });
    } else {
      await prisma.feedDistribution.create({ data: d });
    }
  }
}

// =====================================================================
// DAIRY OPERATIONS
// =====================================================================
//
// Mirrors the HTML's filter-by-worker pill counts (56 cows total)
// and the houses A/B/C/E/F + Maternity layout. Cow names come from
// the "below-average readings" panel where the HTML names them; the
// rest are filled with deterministic Mw-XXX tags so re-runs are stable.
//
// Distinct from layers Houses A/B/C (House.name is @unique across the
// whole table) — dairy houses are seeded as "Dairy A" / etc. The
// frontend can strip the prefix when displaying.
//
// Idempotent: re-runs upsert houses + workers + cow assignments. Milk
// records are bulk-inserted via createMany after deleting the prior
// seed window's rows for the same cows, which is much faster than the
// per-row findFirst+create dance.
async function seedDairyOperations() {
  // 0. Cleanup: drop any cow whose tag isn't in the canonical 56-cow
  // set defined below. This catches legacy seeds (e.g. Mw-082 from
  // earlier versions) so the herd count stays at 56 / maternity at
  // ~12 per the v4.1 HTML mockup. Only runs against cows in the
  // tag-namespace this seed owns (Mw-### or named) — we don't touch
  // user-created cows with unrelated tags.
  const canonicalTags = new Set();
  for (let i = 1; i <= 42; i += 1) {
    canonicalTags.add(`Mw-${String(i).padStart(3, "0")}`);
  }
  for (const t of [
    "Topten", "Makena", "Orion", "Kirote",
    "Mrefu", "Reloy", "Meni", "Kachumi", "Cicilia",
    "Karendi", "Angela", "Tesn-J",
    "Nyambura", "Rose",
  ]) {
    canonicalTags.add(t);
  }
  // Find seed-namespace cows that aren't canonical and delete them
  // (cascades to their MilkRecord + ReproductionRecord rows).
  const stragglers = await prisma.cow.findMany({
    where: {
      OR: [
        { tag: { startsWith: "Mw-" } },
        // Capture legacy single-letter "MW-" forms too.
        { tag: { startsWith: "MW-" } },
      ],
      NOT: { tag: { in: Array.from(canonicalTags) } },
    },
    select: { id: true, tag: true },
  });
  for (const s of stragglers) {
    // MilkRecord doesn't cascade-delete on Cow.delete (no onDelete:
    // Cascade), so wipe its dependents manually first.
    await prisma.milkRecord.deleteMany({ where: { cowId: s.id } });
    await prisma.reproductionRecord.deleteMany({ where: { cowId: s.id } });
    await prisma.cow.delete({ where: { id: s.id } });
  }
  if (stragglers.length > 0) {
    console.info(
      `[dairy seed] dropped ${stragglers.length} legacy cow(s): ${stragglers.map((s) => s.tag).join(", ")}`,
    );
  }

  // 1. Houses — letters match the HTML pill labels. House.name keeps
  // the "Dairy " prefix for uniqueness across the table.
  const houseDefs = [
    { letter: "A", color: "#27500A" },
    { letter: "B", color: "#854F0B" },
    { letter: "C", color: "#185FA5" },
    { letter: "E", color: "#0E5E50" },
    { letter: "F", color: "#5E4B0E" },
  ];
  const houses = {};
  for (const h of houseDefs) {
    const created = await ensureHouse(
      `Dairy ${h.letter}`,
      "Dairy",
      14,
      h.color,
      0,
    );
    houses[h.letter] = created;
  }

  // 2. Workers — exact 11-worker roster from the HTML's "filter by
  // worker" pills. cowCount per pill: 7+6+5+5+5+5+5+3+5+5+5 = 56.
  // The first two are anchored to a default house (Worker.houseId is
  // unique), the rest float (no default house) — they pick up cows
  // across multiple houses, which is the whole point of the workerId
  // refactor.
  const workerDefs = [
    { name: "Ronald",  defaultHouse: houses.A, cowCount: 7 },
    { name: "Musyoka", defaultHouse: houses.B, cowCount: 6 },
    { name: "Joshua",  defaultHouse: houses.C, cowCount: 5 },
    { name: "Ivan",    defaultHouse: houses.E, cowCount: 5 },
    { name: "Jacob",   defaultHouse: houses.F, cowCount: 5 },
    { name: "Mukisa",  defaultHouse: null,     cowCount: 5 },
    { name: "Toby",    defaultHouse: null,     cowCount: 5 },
    { name: "Karis",   defaultHouse: null,     cowCount: 3 },
    { name: "John",    defaultHouse: null,     cowCount: 5 },
    { name: "Sam",     defaultHouse: null,     cowCount: 5 },
    { name: "Nick",    defaultHouse: null,     cowCount: 5 },
  ];

  const workers = {};
  for (const w of workerDefs) {
    let row;
    if (w.defaultHouse) {
      row = await prisma.worker.upsert({
        where: { houseId: w.defaultHouse.id },
        update: {
          name: w.name,
          role: "Milker",
          unit: "Dairy",
          payType: "MONTHLY",
          payRate: 18000,
        },
        create: {
          name: w.name,
          role: "Milker",
          unit: "Dairy",
          payType: "MONTHLY",
          payRate: 18000,
          houseId: w.defaultHouse.id,
        },
      });
    } else {
      // No default house — match by name + unit so re-runs are stable.
      const existing = await prisma.worker.findFirst({
        where: { name: w.name, unit: "Dairy" },
      });
      row = existing
        ? await prisma.worker.update({
            where: { id: existing.id },
            data: { role: "Milker" },
          })
        : await prisma.worker.create({
            data: {
              name: w.name,
              role: "Milker",
              unit: "Dairy",
              payType: "MONTHLY",
              payRate: 18000,
            },
          });
    }
    workers[w.name] = { ...row, cowCount: w.cowCount };
  }

  // 3. Cows. Named cows from the HTML's below-avg-readings panel are
  // placed exactly where the HTML shows them; the rest are padded
  // with sequential Mw-### tags so each worker hits their pill count.
  // ~12 cows are flipped to PREGNANT to populate the Maternity card.
  const namedCows = [
    { tag: "Topten",   worker: "Ronald",  house: "A" },
    { tag: "Makena",   worker: "Ronald",  house: "A" },
    { tag: "Orion",    worker: "Ronald",  house: "A" },
    { tag: "Kirote",   worker: "Ronald",  house: "E" },
    { tag: "Mrefu",    worker: "Musyoka", house: "A" },
    { tag: "Reloy",    worker: "Musyoka", house: "B" },
    { tag: "Meni",     worker: "Musyoka", house: "C" },
    { tag: "Kachumi",  worker: "Musyoka", house: "E" },
    { tag: "Cicilia",  worker: "Musyoka", house: "E" },
    { tag: "Karendi",  worker: "Joshua",  house: "C" },
    { tag: "Angela",   worker: "Joshua",  house: "C" },
    { tag: "Tesn-J",   worker: "Joshua",  house: "C" },
    { tag: "Nyambura", worker: "Ivan",    house: "A" },
    { tag: "Rose",     worker: "Ivan",    house: "C" },
  ];

  const breeds = ["FRIESIAN", "AYRSHIRE", "JERSEY", "SAHIWAL", "CROSSBREED"];
  const houseLetters = ["A", "B", "C", "E", "F"];

  // Local cow names used as nicknames for the 42 pad cows so the
  // milk-logging grid shows recognisable names instead of Mw-###
  // tags. Mix of Swahili and common dairy names found in the
  // Kenyan/East-African context. Order is fixed so re-runs hit the
  // same cow with the same nickname.
  const padNicknames = [
    "Daisy", "Bella", "Tamara", "Pendo", "Faith", "Mercy",
    "Imani", "Neema", "Furaha", "Asali", "Maua", "Tumaini",
    "Tunza", "Zawadi", "Lulu", "Almasi", "Salama", "Baraka",
    "Stella", "Pearl", "Ruby", "Honey", "Esther", "Fortune",
    "Marcos", "Tasha", "Hope", "Lily", "Coffee", "Joy",
    "Grace", "Heshima", "Pamoja", "Subira", "Rehema", "Upendo",
    "Penda", "Sasha", "Nala", "Kiwi", "Mwanga", "Faraja",
  ];

  // Build the full 56-cow list — named ones first, then padded.
  const cowSeeds = [];
  // Spread maternity (12 PREGNANT cows) across workers — every 5th
  // cow becomes PREGNANT once we hit a deterministic counter.
  let cowCounter = 0;
  let maternitySeeded = 0;
  const MATERNITY_TARGET = 12;

  for (const w of workerDefs) {
    const taken = namedCows.filter((c) => c.worker === w.name);
    const padCount = w.cowCount - taken.length;
    const list = [...taken];
    for (let i = 0; i < padCount; i += 1) {
      cowCounter += 1;
      const tag = `Mw-${String(cowCounter).padStart(3, "0")}`;
      // Pull the next pad nickname so the milk-logging grid shows a
      // recognizable name instead of "Mw-019". Indexed by cowCounter
      // (1-based) so re-runs are stable.
      const padNickname = padNicknames[(cowCounter - 1) % padNicknames.length];
      // Distribute across houses by name for variety.
      const house =
        houseLetters[(cowCounter + w.name.length) % houseLetters.length];
      list.push({ tag, worker: w.name, house, nickname: padNickname });
    }
    for (let idx = 0; idx < list.length; idx += 1) {
      const c = list[idx];
      const normalizedTag =
        c.tag.trim().charAt(0).toUpperCase() +
        c.tag.trim().slice(1).toLowerCase();
      // Maternity assignment: every cow with idx === w.cowCount-1
      // (i.e. the last one per worker) goes PREGNANT until we hit 12.
      let status = "MILKING";
      if (
        maternitySeeded < MATERNITY_TARGET &&
        idx === list.length - 1
      ) {
        status = "PREGNANT";
        maternitySeeded += 1;
      }
      cowSeeds.push({
        tag: normalizedTag,
        // Named cows already use their name as the tag (Topten,
        // Makena, etc.); pad cows pull from padNicknames above.
        nickname: c.nickname ?? c.tag,
        breed: breeds[(c.tag.charCodeAt(0) + c.tag.length) % breeds.length],
        dob: `2021-${String((cowCounter % 12) + 1).padStart(2, "0")}-15`,
        status,
        worker: workers[c.worker],
        house: houses[c.house],
      });
    }
  }

  // Top up to 12 maternity cows in case some workers had only 1 cow
  // already converted — pick the next MILKING cow until we reach 12.
  if (maternitySeeded < MATERNITY_TARGET) {
    for (const cs of cowSeeds) {
      if (maternitySeeded >= MATERNITY_TARGET) break;
      if (cs.status === "MILKING") {
        cs.status = "PREGNANT";
        maternitySeeded += 1;
      }
    }
  }

  // Placeholder cow photos. We rotate through the public dicebear
  // animal-avatar service so every cow gets a unique-looking image
  // without us hosting any binaries. The frontend treats
  // imageUrl == null as "show the 🐄 emoji thumbnail" so this is
  // additive — existing rows without images still render fine.
  const photoFor = (tag) =>
    `https://api.dicebear.com/9.x/big-smile/png?seed=${encodeURIComponent(tag)}&backgroundColor=eaf3de`;

  const acquisitionTypes = ["Born on farm", "Purchased", "Gift", "Born on farm"];

  // Upsert every cow.
  const cows = [];
  for (const c of cowSeeds) {
    // Deterministic extras so re-runs don't cause churn.
    const seedNum = c.tag.charCodeAt(0) + c.tag.length;
    const lactationNumber = c.status === "PREGNANT"
      ? (seedNum % 4) + 1                // 1–4
      : (seedNum % 5) + 1;               // 1–5
    const weightKg = 380 + ((seedNum * 7) % 180); // 380–559 kg
    const acquisitionType = acquisitionTypes[seedNum % acquisitionTypes.length];
    const acquisitionDate = new Date(c.dob);
    acquisitionDate.setMonth(acquisitionDate.getMonth() + 6);
    // Local name for the milk-logging grid + cow records. For named
    // cows this is the same as the tag (Topten → "Topten"); for pad
    // cows it's a real local name (Mw-005 → "Faith").
    const nickname = c.nickname ?? c.tag;

    const cow = await prisma.cow.upsert({
      where: { tag: c.tag },
      update: {
        breed: c.breed,
        status: c.status,
        houseId: c.house.id,
        workerId: c.worker.id,
        nickname,
        imageUrl: photoFor(c.tag),
        lactationNumber,
        weightKg,
        acquisitionDate,
        acquisitionType,
      },
      create: {
        tag: c.tag,
        breed: c.breed,
        dateOfBirth: new Date(c.dob),
        status: c.status,
        houseId: c.house.id,
        workerId: c.worker.id,
        nickname,
        imageUrl: photoFor(c.tag),
        lactationNumber,
        weightKg,
        acquisitionDate,
        acquisitionType,
      },
    });
    // PREGNANT cows shouldn't have milk readings — exclude them from
    // the milk-record bulk insert below.
    cows.push({
      ...cow,
      expectedAvg: 11 + ((c.tag.charCodeAt(2) ?? 0) % 5), // 11–15 L/day
      isMaternity: cow.status === "PREGNANT",
    });
  }

  // 4. Milk records: 6 days × 3 sessions for every MILKING cow.
  // Bulk delete the seed window first, then createMany — much faster
  // than the per-row findFirst+create loop.
  const recorder = await prisma.user.findFirst({ select: { id: true } });
  if (!recorder) {
    console.warn(
      "[dairy seed] No User exists yet — skipping milk records. Run staff seed first.",
    );
    return;
  }

  const milkingCows = cows.filter((c) => !c.isMaternity);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const seedWindowStart = new Date(today);
  seedWindowStart.setDate(seedWindowStart.getDate() - 6);

  // Wipe just the seed window for these cows. Manual user entries
  // outside this window or for other cows are untouched.
  await prisma.milkRecord.deleteMany({
    where: {
      cowId: { in: milkingCows.map((c) => c.id) },
      date: { gte: seedWindowStart, lt: today },
    },
  });

  const sessions = ["AM", "MID", "PM"];
  const rows = [];
  for (const cow of milkingCows) {
    for (let dayBack = 1; dayBack <= 6; dayBack += 1) {
      const date = new Date(today);
      date.setDate(date.getDate() - dayBack);
      for (const session of sessions) {
        // AM ~40%, MID ~30%, PM ~30% of cow's daily total.
        const sessShare =
          session === "AM" ? 0.4 : session === "MID" ? 0.3 : 0.3;
        const jitter = ((dayBack + cow.tag.charCodeAt(0)) % 5) * 0.2 - 0.4;
        const litres = Math.max(
          1,
          Number(((cow.expectedAvg + jitter) * sessShare).toFixed(1)),
        );
        rows.push({
          cowId: cow.id,
          userId: recorder.id,
          litres,
          session,
          date,
        });
      }
    }
  }

  if (rows.length > 0) {
    // createMany is much faster than per-row create; allowed because
    // it doesn't require nested relations (we pass raw FK cols).
    await prisma.milkRecord.createMany({ data: rows });
  }

  // 5. FarmConfig — calf + household deductions used by the day-net
  // summary endpoint. Idempotent.
  const cfg = await prisma.farmConfig.findFirst();
  if (!cfg) {
    await prisma.farmConfig.create({
      data: {
        farmName: "Mwirigi Farm",
        version: "v4.1",
        location: "Kenya",
        year: "2026",
        milkTarget: 2000,
        eggsTarget: 700,
        householdDeduct: 35,
        calfDeduction: 5,
        sowCount: 24,
        gestationDays: 114,
        weaningDays: 28,
        saleAgeDays: 180,
        beaconnersTarget: 50,
      },
    });
  }

  // 6. Reproduction history — attach AI + calving records to a few
  // named cows so the Reproduction tracker tab has data to show. We
  // pick three of the named cows (Topten, Reloy, Cicilia) and flip
  // their status to PREGNANT so the AI/expected-calving fields make
  // sense alongside the maternity KPI.
  // Each priorCalvings entry: { date, calfTag, sex, wt, sire, ease, fate }.
  // Mirrors the Calves register columns shown in the HTML mockup.
  const reproSeeds = [
    {
      tag: "Topten",
      aiDate: "2025-01-12",
      sireCode: "SIRE-417",
      pregnancyStatus: "CONFIRMED",
      pregnancyCheckOffset: 35,
      expectedCalvingOffset: 283,
      priorCalvings: [
        { date: "2021-09-01", calfTag: "TOPTEN-1", sex: "F", wt: 36.5, sire: "SIRE-201", ease: 1, fate: "Heifer to herd" },
        { date: "2022-11-12", calfTag: "TOPTEN-2", sex: "F", wt: 38.0, sire: "SIRE-208", ease: 2, fate: "Heifer to herd" },
        { date: "2024-01-30", calfTag: "B-001",     sex: "M", wt: 41.2, sire: "SIRE-417", ease: 3, fate: "Bull → feedlot" },
      ],
    },
    {
      tag: "Reloy",
      aiDate: "2025-02-05",
      sireCode: "SIRE-208",
      pregnancyStatus: "PENDING",
      priorCalvings: [
        { date: "2022-12-04", calfTag: "RELOY-1", sex: "F", wt: 35.5, sire: "SIRE-115", ease: 1, fate: "Heifer to herd" },
        { date: "2024-03-19", calfTag: "1024",     sex: "M", wt: 39.8, sire: "SIRE-208", ease: 2, fate: "Bull → feedlot" },
      ],
    },
    {
      tag: "Cicilia",
      aiDate: "2024-11-28",
      sireCode: "SIRE-301",
      pregnancyStatus: "CONFIRMED",
      pregnancyCheckOffset: 30,
      expectedCalvingOffset: 283,
      priorCalvings: [
        { date: "2020-08-14", calfTag: "CICILIA-1", sex: "F", wt: 34.0, sire: "SIRE-098", ease: 2, fate: "Heifer to herd" },
        { date: "2021-10-01", calfTag: "CICILIA-2", sex: "F", wt: 37.1, sire: "SIRE-115", ease: 1, fate: "Heifer to herd" },
        { date: "2023-02-25", calfTag: "1025",      sex: "M", wt: 42.0, sire: "SIRE-301", ease: 3, fate: "Bull → feedlot" },
        { date: "2024-04-08", calfTag: "CICILIA-3", sex: "F", wt: 36.8, sire: "SIRE-301", ease: 4, fate: "Heifer to herd" },
      ],
    },
  ];

  for (const r of reproSeeds) {
    const cow = await prisma.cow.findUnique({ where: { tag: r.tag } });
    if (!cow) continue;
    // Mark CONFIRMED-pregnancy cows as PREGNANT so the maternity card
    // and the repro tracker stay consistent. PENDING stays MILKING.
    if (r.pregnancyStatus === "CONFIRMED" && cow.status !== "PREGNANT") {
      await prisma.cow.update({
        where: { id: cow.id },
        data: { status: "PREGNANT" },
      });
    }
    const aiDate = new Date(r.aiDate);
    await ensureRepro(cow.id, aiDate, {
      eventType: "AI",
      sireCode: r.sireCode,
      pregnancyStatus: r.pregnancyStatus,
      pregnancyCheckDate:
        r.pregnancyCheckOffset != null
          ? addDays(aiDate, r.pregnancyCheckOffset)
          : null,
      expectedCalvingDate:
        r.expectedCalvingOffset != null
          ? addDays(aiDate, r.expectedCalvingOffset)
          : null,
    });
    for (const c of r.priorCalvings) {
      await ensureRepro(cow.id, new Date(c.date), {
        eventType: "CALVING",
        calfTag: c.calfTag,
        calfSex: c.sex,
        calfBirthWeightKg: c.wt,
        sireCode: c.sire,
        calvingEase: c.ease,
        calvingFate: c.fate,
      });
    }
  }

  console.info(
    `[dairy seed] ${cows.length} cows (${milkingCows.length} milking · ${maternitySeeded} maternity) across ${Object.keys(workers).length} workers · ${rows.length} milk rows · ${reproSeeds.length} repro histories.`,
  );
}

// Dairy inventory rows mirror the HTML mockup's "Inventory — Dairy unit"
// card: bedding (sawdust), equipment (buckets / cans / lick blocks),
// veterinary (iodine teat dip, calving ropes).
async function seedDairyInventory() {
  const items = [
    { name: "Sawdust bags",       category: "Bedding",    quantity: 18, unit: "bags", location: "Houses A·B·C·D·E·F", condition: "Good" },
    { name: "Milking buckets",    category: "Equipment",  quantity: 14, unit: "pcs",  location: "Parlour",              condition: "Good" },
    { name: "Milk cans (50 L)",   category: "Equipment",  quantity: 8,  unit: "pcs",  location: "Cold room",            condition: "Good" },
    { name: "Mineral lick blocks",category: "Equipment",  quantity: 24, unit: "pcs",  location: "Houses A·B·C",         condition: "Good" },
    { name: "Iodine teat dip",    category: "Veterinary", quantity: 12, unit: "L",    location: "Vet store",            condition: "Good" },
    { name: "Calving ropes",      category: "Veterinary", quantity: 3,  unit: "pcs",  location: "Maternity",            condition: "Good" },
  ];

  let added = 0;
  for (const it of items) {
    const existing = await prisma.dairyInventoryItem.findFirst({
      where: { name: it.name, deletedAt: null },
    });
    if (existing) {
      await prisma.dairyInventoryItem.update({
        where: { id: existing.id },
        data: it,
      });
    } else {
      await prisma.dairyInventoryItem.create({ data: it });
      added += 1;
    }
  }
  console.info(
    `[dairy seed] inventory: ${items.length} items (${added} new, ${items.length - added} updated).`,
  );
}

// Feedlot inventory — bedding, equipment, vet supplies. Realistic
// counts for a 12-bull feedlot building toward 100-bull capacity.
async function seedFeedlotInventory() {
  const items = [
    // Bedding
    { name: "Sawdust bags",       category: "Bedding",    quantity: 22, unit: "bags", location: "Feedlot pens",       condition: "Good" },
    { name: "Wood shavings",      category: "Bedding",    quantity: 8,  unit: "bags", location: "Pen rotation store", condition: "Good" },

    // Equipment
    { name: "Feeding troughs",    category: "Equipment",  quantity: 14, unit: "pcs",  location: "Pens A–D",           condition: "Good" },
    { name: "Water troughs",      category: "Equipment",  quantity: 8,  unit: "pcs",  location: "Pens A–D",           condition: "Good" },
    { name: "Cattle crush",       category: "Equipment",  quantity: 1,  unit: "pcs",  location: "Loading bay",        condition: "Good" },
    { name: "Weigh scale (cattle)", category: "Equipment", quantity: 1, unit: "pcs",  location: "Crush area",         condition: "Good" },
    { name: "Ear-tag applicator", category: "Equipment",  quantity: 2,  unit: "pcs",  location: "Vet store",          condition: "Good" },

    // Veterinary
    { name: "Iodine teat dip",    category: "Veterinary", quantity: 6,  unit: "L",    location: "Vet store",          condition: "Good" },
    { name: "Dewormer (oral)",    category: "Veterinary", quantity: 4,  unit: "L",    location: "Vet store",          condition: "Good" },
    { name: "Multivitamin (injectable)", category: "Veterinary", quantity: 200, unit: "doses", location: "Vet fridge", condition: "Good" },
    { name: "Antibiotic (oxytet)", category: "Veterinary", quantity: 50, unit: "doses", location: "Vet fridge",        condition: "Good" },

    // Feed (feedlot-specific concentrate; rations live in the Feeds module)
    { name: "Feedlot finisher concentrate", category: "Feed", quantity: 850, unit: "kg", location: "Feed shed",      condition: "Good" },
    { name: "Mineral lick blocks",          category: "Feed", quantity: 18,  unit: "pcs", location: "Pens A–D",      condition: "Good" },
  ];

  let added = 0;
  for (const it of items) {
    const existing = await prisma.feedlotInventoryItem.findFirst({
      where: { name: it.name, deletedAt: null },
    });
    if (existing) {
      await prisma.feedlotInventoryItem.update({
        where: { id: existing.id },
        data: it,
      });
    } else {
      await prisma.feedlotInventoryItem.create({ data: it });
      added += 1;
    }
  }
  console.info(
    `[feedlot seed] inventory: ${items.length} items (${added} new, ${items.length - added} updated).`,
  );
}

// Layers unit inventory — feed (layer/grower/starter mash + supplements),
// vaccines (with realistic expiry dates), consumables (trays/crates,
// disinfectant, bulbs, water additives). lowThreshold powers the
// "⚠ low stock" badge in the inventory pill.
async function seedLayersInventory() {
  const now = new Date();
  const monthsFromNow = (n) => {
    const d = new Date(now);
    d.setMonth(d.getMonth() + n);
    return d;
  };

  const items = [
    // ===== Feed =====
    { name: "Layer mash",       category: "Feed", subCategory: "Layer mash",   quantity: 1850, unit: "kg",   lowThreshold: 500,  location: "Feed store",        condition: "Good" },
    { name: "Grower mash",      category: "Feed", subCategory: "Grower mash",  quantity: 600,  unit: "kg",   lowThreshold: 200,  location: "Feed store",        condition: "Good" },
    { name: "Starter mash",     category: "Feed", subCategory: "Starter mash", quantity: 320,  unit: "kg",   lowThreshold: 200,  location: "Brooder feed bay",  condition: "Good" },
    { name: "Limestone (calcium)", category: "Feed", subCategory: "Supplements", quantity: 80, unit: "kg",   lowThreshold: 25,   location: "Feed store",        condition: "Good" },
    { name: "Vitamin premix",   category: "Feed", subCategory: "Supplements",  quantity: 12,   unit: "kg",   lowThreshold: 5,    location: "Feed store",        condition: "Good" },

    // ===== Vaccines / Medication =====
    { name: "Newcastle (LaSota)",  category: "Vaccines", subCategory: "Vaccine",     quantity: 4500, unit: "doses", lowThreshold: 1000, location: "Vet store",  condition: "Good", expiresAt: monthsFromNow(8) },
    { name: "Gumboro (IBD)",       category: "Vaccines", subCategory: "Vaccine",     quantity: 3200, unit: "doses", lowThreshold: 1000, location: "Vet store",  condition: "Good", expiresAt: monthsFromNow(6) },
    { name: "Fowl pox",            category: "Vaccines", subCategory: "Vaccine",     quantity: 2200, unit: "doses", lowThreshold: 800,  location: "Vet store",  condition: "Good", expiresAt: monthsFromNow(1) }, // expiring soon → triggers alert
    { name: "Marek's",             category: "Vaccines", subCategory: "Vaccine",     quantity: 1500, unit: "doses", lowThreshold: 500,  location: "Vet store",  condition: "Good", expiresAt: monthsFromNow(11) },
    { name: "Tylosin (antibiotic)",category: "Vaccines", subCategory: "Medication",  quantity: 6,    unit: "L",     lowThreshold: 2,    location: "Vet store",  condition: "Good", expiresAt: monthsFromNow(14) },
    { name: "Coccidiostat",        category: "Vaccines", subCategory: "Medication",  quantity: 9,    unit: "kg",    lowThreshold: 3,    location: "Vet store",  condition: "Good", expiresAt: monthsFromNow(10) },

    // ===== Consumables =====
    { name: "Egg crates / trays",  category: "Consumables", subCategory: "Trays",          quantity: 480, unit: "pcs", lowThreshold: 100, location: "Egg store",  condition: "Good" },
    { name: "Disinfectant (Virkon)", category: "Consumables", subCategory: "Disinfectant",  quantity: 14,  unit: "L",   lowThreshold: 5,   location: "Vet store",  condition: "Good" },
    { name: "Heat bulbs",          category: "Consumables", subCategory: "Bulbs/Heaters",  quantity: 18,  unit: "pcs", lowThreshold: 6,   location: "Brooder",    condition: "Good" },
    { name: "Lighting bulbs (LED)",category: "Consumables", subCategory: "Bulbs/Heaters",  quantity: 26,  unit: "pcs", lowThreshold: 8,   location: "Houses A·B·C", condition: "Good" },
    { name: "Water additive (electrolytes)", category: "Consumables", subCategory: "Water additives", quantity: 22, unit: "kg", lowThreshold: 8, location: "Vet store",  condition: "Good" },
    { name: "Footbath solution",   category: "Consumables", subCategory: "Disinfectant",   quantity: 8,   unit: "L",   lowThreshold: 3,   location: "Entrance",   condition: "Good" },
  ];

  let added = 0;
  for (const it of items) {
    const existing = await prisma.layersInventoryItem.findFirst({
      where: { name: it.name, deletedAt: null },
    });
    if (existing) {
      await prisma.layersInventoryItem.update({
        where: { id: existing.id },
        data: it,
      });
    } else {
      await prisma.layersInventoryItem.create({ data: it });
      added += 1;
    }
  }
  console.info(
    `[layers seed] inventory: ${items.length} items (${added} new, ${items.length - added} updated).`,
  );
}

// Finance seed — month-to-date revenue + expense rows per unit. The
// totals match the CEO-dashboard mockup exactly so the chart and
// P&L table have realistic data without auto-pulling from other
// modules (that hook-up is a follow-up). Idempotent: re-running
// rebuilds the current month's rows in a single sweep.
async function seedFinance() {
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 12, 0, 0);

  // Drop any rows from this month so re-running gives a clean slate.
  await prisma.revenue.deleteMany({
    where: { date: { gte: monthStart } },
  });
  await prisma.expense.deleteMany({
    where: { date: { gte: monthStart } },
  });

  const revenuePerUnit = [
    { unit: "Dairy",    amount: 595_000, category: "MILK_SALES",       qty: 21_500, qLabel: "L" },
    { unit: "Layers",   amount: 298_000, category: "EGG_SALES",        qty: 7_200,  qLabel: "crates" },
    { unit: "Piggery",  amount: 195_000, category: "PIG_SALES",        qty: 38,     qLabel: "pigs" },
    { unit: "Ngushish", amount: 92_000,  category: "CROP_SALES",       qty: 1_840,  qLabel: "kg" },
    { unit: "Feedlot",  amount: 42_000,  category: "ANIMAL_SALES",     qty: 4,      qLabel: "bulls" },
    { unit: "Doopers",  amount: 18_000,  category: "ANIMAL_SALES",     qty: 6,      qLabel: "sheep" },
  ];

  // Each unit's expense breakdown roughly matches the unit's nature:
  // Dairy → feeds + labour; Piggery → feeds + vaccines; etc.
  const expenseBreakdown = {
    Dairy:    [{ cat: "FEEDS", amount: 180_000 }, { cat: "LABOUR", amount: 90_000 }, { cat: "VACCINES", amount: 24_000 }, { cat: "UTILITIES", amount: 16_000 }],
    Layers:   [{ cat: "FEEDS", amount: 110_000 }, { cat: "LABOUR", amount: 40_000 }, { cat: "VACCINES", amount: 18_000 }, { cat: "UTILITIES", amount: 12_000 }],
    Piggery:  [{ cat: "FEEDS", amount: 80_000 },  { cat: "LABOUR", amount: 30_000 }, { cat: "VACCINES", amount: 12_000 }, { cat: "FARM_INPUTS", amount: 8_000 }],
    Ngushish: [{ cat: "FARM_INPUTS", amount: 32_000 }, { cat: "LABOUR", amount: 22_000 }, { cat: "FUEL", amount: 8_000 }, { cat: "MAINTENANCE", amount: 6_000 }],
    Feedlot:  [{ cat: "FEEDS", amount: 38_000 }, { cat: "LABOUR", amount: 14_000 }, { cat: "TRANSPORT", amount: 6_000 }, { cat: "MAINTENANCE", amount: 4_000 }],
    Doopers:  [{ cat: "FEEDS", amount: 14_000 }, { cat: "LABOUR", amount: 6_000 },  { cat: "VACCINES", amount: 2_500 },  { cat: "MAINTENANCE", amount: 1_500 }],
  };

  let revenueCount = 0;
  let expenseCount = 0;

  for (const r of revenuePerUnit) {
    await prisma.revenue.create({
      data: {
        unit: r.unit,
        category: r.category,
        amount: r.amount,
        quantity: r.qty,
        unitLabel: r.qLabel,
        date: today,
        notes: `Month-to-date ${r.unit} sales`,
      },
    });
    revenueCount += 1;
  }

  for (const [unit, items] of Object.entries(expenseBreakdown)) {
    for (const e of items) {
      await prisma.expense.create({
        data: {
          unit,
          category: e.cat,
          amount: e.amount,
          paymentMethod: "BANK_TRANSFER",
          approved: true,
          date: today,
          notes: `MTD ${unit} ${e.cat.toLowerCase()}`,
        },
      });
      expenseCount += 1;
    }
  }

  console.info(
    `[finance seed] ${revenueCount} revenue rows · ${expenseCount} expense rows for ${monthStart.toISOString().slice(0, 7)}.`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
