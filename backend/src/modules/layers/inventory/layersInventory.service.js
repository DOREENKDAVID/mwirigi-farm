// Layers unit inventory — feed, vaccines, consumables.
//
// Mirrors the Dairy inventory service but adds two layers-specific
// concepts:
//   • `lowThreshold` per item → drives the LOW stock alert
//   • `expiresAt`             → drives the EXPIRING SOON alert (vaccines)
//
// The `decrementCrateStockBy()` helper is called from
// layers.service.upsertDailyEntry so that logging eggs auto-decrements
// the crate inventory in one DB round-trip.
import prisma from "../../../prisma/client.js";

const trimOrNull = (v) => {
  if (v === undefined || v === null) return null;
  if (typeof v !== "string") return v;
  const t = v.trim();
  return t.length === 0 ? null : t;
};

// ---------------------------------------------------------------
// CRUD
// ---------------------------------------------------------------

export const listInventory = async () => {
  return prisma.layersInventoryItem.findMany({
    where: { deletedAt: null },
    orderBy: [{ category: "asc" }, { name: "asc" }],
  });
};

export const createItem = async (input) => {
  return prisma.layersInventoryItem.create({
    data: {
      name: input.name.trim(),
      category: input.category,
      subCategory: trimOrNull(input.subCategory),
      quantity: input.quantity,
      unit: trimOrNull(input.unit),
      lowThreshold: input.lowThreshold ?? null,
      location: trimOrNull(input.location),
      condition: trimOrNull(input.condition),
      expiresAt: input.expiresAt ?? null,
      notes: trimOrNull(input.notes),
    },
  });
};

export const updateItem = async (id, patch) => {
  const data = {};
  if (patch.name         !== undefined) data.name         = patch.name.trim();
  if (patch.category     !== undefined) data.category     = patch.category;
  if (patch.subCategory  !== undefined) data.subCategory  = trimOrNull(patch.subCategory);
  if (patch.quantity     !== undefined) data.quantity     = patch.quantity;
  if (patch.unit         !== undefined) data.unit         = trimOrNull(patch.unit);
  if (patch.lowThreshold !== undefined) data.lowThreshold = patch.lowThreshold;
  if (patch.location     !== undefined) data.location     = trimOrNull(patch.location);
  if (patch.condition    !== undefined) data.condition    = trimOrNull(patch.condition);
  if (patch.expiresAt    !== undefined) data.expiresAt    = patch.expiresAt;
  if (patch.notes        !== undefined) data.notes        = trimOrNull(patch.notes);
  return prisma.layersInventoryItem.update({ where: { id }, data });
};

export const softDeleteItem = async (id) => {
  return prisma.layersInventoryItem.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
};

// ---------------------------------------------------------------
// Summary — KPIs + alerts + items, in one round-trip
// ---------------------------------------------------------------
//
// Used by GET /api/layers/inventory/summary which the inventory pill
// consumes. Returns:
//   {
//     items: LayersInventoryItem[] (with derived `alert` per row),
//     kpis: { totalBirds, eggsToday, feedRemainingKg,
//             vaccineAlerts, mortalityToday, mortalityAlert },
//     alerts: { lowFeed: int, expiringVaccines: int,
//               overcrowdedHouses: int, mortalityAboveExpected: bool }
//   }

const VACCINE_EXPIRY_WARN_DAYS = 30;
// "Above expected" mortality threshold — 0.1% of total birds in a day,
// matching the Layers KPI label rules.
const MORTALITY_PCT_THRESHOLD = 0.1;
// "Overcrowded" — birdCount above this fraction of capacity flips the
// alert. Matches the LayerHouseCard color rule.
const OVERCAPACITY_FRAC = 1.0;

const startOfDay = (d) => {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
};

export const getSummary = async () => {
  const today = startOfDay(new Date());
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);

  const [items, layerHouses, todayProduction] = await Promise.all([
    prisma.layersInventoryItem.findMany({
      where: { deletedAt: null },
      orderBy: [{ category: "asc" }, { name: "asc" }],
    }),
    prisma.house.findMany({
      where: { type: "Poultry" },
      select: { id: true, name: true, birdCount: true, capacity: true },
    }),
    prisma.layerProduction.findMany({
      where: { date: { gte: today, lt: tomorrow } },
      select: { eggsCollected: true, deadRemoved: true },
    }),
  ]);

  // Per-row alert tag — UI can colour each row from this.
  const decorated = items.map((it) => {
    let alert = null;
    if (it.quantity <= 0) {
      alert = "OUT";
    } else if (it.lowThreshold != null && it.quantity <= it.lowThreshold) {
      alert = "LOW";
    } else if (it.expiresAt) {
      const days = Math.floor(
        (new Date(it.expiresAt).getTime() - today.getTime()) / 86_400_000,
      );
      if (days < 0) alert = "EXPIRED";
      else if (days <= VACCINE_EXPIRY_WARN_DAYS) alert = "EXPIRING";
    }
    return { ...it, alert };
  });

  // KPI rollups.
  const totalBirds = layerHouses.reduce((s, h) => s + (h.birdCount ?? 0), 0);
  const totalCapacity = layerHouses.reduce((s, h) => s + (h.capacity ?? 0), 0);
  const eggsToday = todayProduction.reduce(
    (s, r) => s + (r.eggsCollected ?? 0),
    0,
  );
  const mortalityToday = todayProduction.reduce(
    (s, r) => s + (r.deadRemoved ?? 0),
    0,
  );

  const feedRemainingKg = decorated
    .filter((i) => i.category === "Feed" && (i.unit ?? "").toLowerCase() === "kg")
    .reduce((s, i) => s + (i.quantity ?? 0), 0);

  const lowFeed = decorated.filter(
    (i) => i.category === "Feed" && (i.alert === "LOW" || i.alert === "OUT"),
  ).length;
  const expiringVaccines = decorated.filter(
    (i) =>
      i.category === "Vaccines" &&
      (i.alert === "EXPIRING" || i.alert === "EXPIRED"),
  ).length;

  const overcrowdedHouses = layerHouses.filter(
    (h) =>
      h.capacity > 0 && h.birdCount / h.capacity > OVERCAPACITY_FRAC,
  ).length;

  const mortalityPct = totalBirds > 0
    ? (mortalityToday / totalBirds) * 100
    : 0;
  const mortalityAboveExpected = mortalityPct > MORTALITY_PCT_THRESHOLD;

  return {
    items: decorated,
    kpis: {
      totalBirds,
      totalCapacity,
      eggsToday,
      feedRemainingKg,
      mortalityToday,
      mortalityPct: Number(mortalityPct.toFixed(3)),
    },
    alerts: {
      lowFeed,
      expiringVaccines,
      overcrowdedHouses,
      mortalityAboveExpected,
    },
  };
};

// ---------------------------------------------------------------
// Auto-update hooks
// ---------------------------------------------------------------

// Decrement the most-stocked "crate" consumable by `crates`. Looked up
// case-insensitively on the name so both "Trays / crates" and
// "Egg crates" rows work. No-op if no matching row is found — we never
// want a missing inventory row to fail an egg-log POST.
export const decrementCrateStockBy = async (crates) => {
  if (!crates || crates <= 0) return;
  const row = await prisma.layersInventoryItem.findFirst({
    where: {
      deletedAt: null,
      category: "Consumables",
      name: { contains: "crate", mode: "insensitive" },
    },
    orderBy: { quantity: "desc" },
  });
  if (!row) return;
  const next = Math.max(0, (row.quantity ?? 0) - crates);
  await prisma.layersInventoryItem.update({
    where: { id: row.id },
    data: { quantity: next },
  });
};
