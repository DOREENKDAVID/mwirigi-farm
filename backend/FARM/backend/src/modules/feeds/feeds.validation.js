import { z } from "zod";

// Mirrors the Prisma enums. Listed here (instead of importing from
// @prisma/client) so this validator stays decoupled from generated types
// and runs in test/script contexts without a Prisma client.
export const FEED_CATEGORIES = [
  "MAIZE_GERM",
  "SOYA",
  "SUNFLOWER",
  "LIME",
  "PREMIX",
  "WHEAT_BRAN",
  "COTTON_SEED",
  "FISH_MEAL",
  "OTHER",
];
export const BULK_FEED_TYPES = ["SILAGE", "NAPIER", "MAIZE_SILAGE"];
export const BULK_FEED_UNITS = ["PERCENT", "ACRES", "TONNES"];
export const BULK_FEED_STATUSES = [
  "ACTIVE",
  "REPLENISH_SOON",
  "MATURING",
  "DEPLETED",
];
export const LIVESTOCK_UNITS = [
  "DAIRY",
  "CALVES",
  "HEIFERS",
  "DOOPERS",
  "FEEDLOT",
  "PIGGERY",
  "LAYERS",
  "BROODER",
];
export const FEED_STATUS_FILTERS = ["CRITICAL", "LOW", "ADEQUATE"];

// POST /feeds/materials
export const createMaterialSchema = z.object({
  name: z.string().min(1, "name is required").max(80),
  category: z.enum(FEED_CATEGORIES),
  packSize: z
    .string()
    .min(1, "packSize is required")
    .max(40, "packSize too long"),
  stockOnHandKg: z.number().min(0).max(1_000_000).optional().default(0),
  dailyUseKg: z.number().min(0).max(100_000).optional().default(0),
  reorderLevelDays: z.number().int().positive().max(365).optional().default(5),
  supplier: z.string().max(120).optional(),
  costPerKg: z.number().min(0).max(1_000_000).optional(),
});

// PATCH /feeds/materials/:id
//
// stockOnHandKg / dailyUseKg are intentionally NOT patchable here — they
// have dedicated endpoints (POST /deliveries, POST /consumption) so the
// audit trail stays coherent. PATCH only touches metadata + reorder lead
// time.
export const updateMaterialSchema = z
  .object({
    name: z.string().min(1).max(80).optional(),
    category: z.enum(FEED_CATEGORIES).optional(),
    packSize: z.string().min(1).max(40).optional(),
    reorderLevelDays: z.number().int().positive().max(365).optional(),
    supplier: z.string().max(120).nullable().optional(),
    costPerKg: z.number().min(0).max(1_000_000).nullable().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: "At least one field must be provided",
  });

// GET /feeds/materials?...
export const listMaterialsQuerySchema = z.object({
  search: z.string().trim().min(1).optional(),
  status: z.enum(FEED_STATUS_FILTERS).optional(),
  category: z.enum(FEED_CATEGORIES).optional(),
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(200).optional().default(50),
});

// POST /feeds/deliveries
export const createDeliverySchema = z.object({
  materialId: z.string().uuid("materialId must be a UUID"),
  quantityKg: z.number().positive("quantityKg must be > 0").max(1_000_000),
  unitCost: z.number().min(0).max(1_000_000).optional(),
  supplier: z.string().max(120).optional(),
  invoiceNumber: z.string().max(80).optional(),
  deliveredAt: z.coerce.date(),
  notes: z.string().max(2000).optional(),
});

// GET /feeds/deliveries
export const listDeliveriesQuerySchema = z.object({
  materialId: z.string().uuid().optional(),
  from: z.coerce.date().optional(),
  to: z.coerce.date().optional(),
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(200).optional().default(50),
});

// POST /feeds/consumption
//
// Mirrors the "Edit consumption rates" modal in the HTML — a user enters
// quantityUsed + duration and the service computes daily use.
export const createConsumptionSchema = z.object({
  materialId: z.string().uuid("materialId must be a UUID"),
  quantityUsedKg: z
    .number()
    .positive("quantityUsedKg must be > 0")
    .max(1_000_000),
  durationDays: z
    .number()
    .int()
    .positive("durationDays must be > 0")
    .max(3650),
  notes: z.string().max(2000).optional(),
});

// POST /feeds/consumption/bulk
//
// Updates consumption rates for many materials in one transaction. The
// header-level "Edit consumption rates" UI submits an array; we validate
// each entry the same way the single-row schema does.
export const createBulkConsumptionSchema = z.object({
  entries: z
    .array(
      z.object({
        materialId: z.string().uuid("materialId must be a UUID"),
        quantityUsedKg: z.number().positive().max(1_000_000),
        durationDays: z.number().int().positive().max(3650),
        notes: z.string().max(2000).optional(),
      }),
    )
    .min(1, "Provide at least one entry")
    .max(200, "Too many entries in one request"),
});

// PATCH /feeds/bulk-feed/:id
export const updateBulkFeedSchema = z
  .object({
    quantity: z.number().min(0).max(1_000_000).optional(),
    unit: z.enum(BULK_FEED_UNITS).optional(),
    status: z.enum(BULK_FEED_STATUSES).optional(),
    notes: z.string().max(2000).nullable().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: "At least one field must be provided",
  });

// POST /feeds/distribution
//
// Upserts on `livestockUnit` — sending the same unit twice replaces the
// existing row instead of appending. Use the GET history if you ever
// need to audit prior allocations.
export const createDistributionSchema = z.object({
  livestockUnit: z.enum(LIVESTOCK_UNITS),
  concentrateKg: z.number().min(0).max(1_000_000).optional().default(0),
  silageKg: z.number().min(0).max(1_000_000).optional().default(0),
  napierKg: z.number().min(0).max(1_000_000).optional().default(0),
  animalCount: z.number().int().min(0).max(1_000_000).optional().default(0),
  recordedAt: z.coerce.date().optional(),
});

// Path :id used by PATCH /materials, PATCH /bulk-feed, etc.
export const idParamSchema = z.object({
  id: z.string().uuid("id must be a UUID"),
});
