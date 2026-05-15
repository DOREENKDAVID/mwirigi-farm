import { z } from "zod";

// Mirrors the Prisma CropStatus enum. Listed here (instead of importing
// from @prisma/client) so the validator stays decoupled from Prisma's
// generated types and works in non-prisma contexts (tests, scripts).
export const CROP_STATUS = [
  "PLANTED",
  "ACTIVE",
  "GROWING",
  "MATURING",
  "TASSELING",
  "READY_SOON",
  "READY",
  "AWAITING",
  "INFRASTRUCTURE",
  "HARVESTED",
  "FAILED",
];

const cropStatusEnum = z.enum(CROP_STATUS);

// Perennials skip a single calendar harvest (Napier is cut monthly, etc.)
// and instead specify a frequency string. We enforce that cross-field
// rule here so the controller doesn't have to.
const perennialRefinement = (data, ctx) => {
  if (data.isPerennial) {
    if (!data.harvestFrequency || data.harvestFrequency.trim() === "") {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["harvestFrequency"],
        message: "harvestFrequency is required for perennial crops",
      });
    }
  }
};

// POST /api/ngushish/crops
export const createCropSchema = z
  .object({
    name: z.string().min(1, "name is required").max(80),
    acreage: z
      .number({ invalid_type_error: "acreage must be a number" })
      .positive("acreage must be > 0")
      .max(10_000),
    plantedDate: z.coerce.date().optional(),
    expectedHarvest: z.coerce.date().optional(),
    harvestFrequency: z.string().max(80).optional(),
    status: cropStatusEnum.default("ACTIVE"),
    destination: z.string().max(120).optional(),
    notes: z.string().max(2000).optional(),
    isPerennial: z.boolean().optional().default(false),
    irrigationType: z.string().max(80).optional(),
    irrigated: z.boolean().optional().default(false),
    // Block-register fields.
    block: z.string().max(20).optional(),
    age: z.string().max(40).optional(),
    dueDate: z.coerce.date().optional(),
    season: z.string().max(40).optional(),
    actionNote: z.string().max(500).optional(),
  })
  .superRefine(perennialRefinement);

// PATCH /api/ngushish/crops/:id
//
// Every field optional, but at least one must be present. The perennial
// rule is re-applied so a caller flipping isPerennial=true without
// harvestFrequency gets rejected.
export const updateCropSchema = z
  .object({
    name: z.string().min(1).max(80).optional(),
    acreage: z.number().positive().max(10_000).optional(),
    plantedDate: z.coerce.date().nullable().optional(),
    expectedHarvest: z.coerce.date().nullable().optional(),
    harvestFrequency: z.string().max(80).nullable().optional(),
    status: cropStatusEnum.optional(),
    destination: z.string().max(120).nullable().optional(),
    notes: z.string().max(2000).nullable().optional(),
    isPerennial: z.boolean().optional(),
    irrigationType: z.string().max(80).nullable().optional(),
    irrigated: z.boolean().optional(),
    block: z.string().max(20).nullable().optional(),
    age: z.string().max(40).nullable().optional(),
    dueDate: z.coerce.date().nullable().optional(),
    season: z.string().max(40).nullable().optional(),
    actionNote: z.string().max(500).nullable().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: "At least one field must be provided",
  })
  .superRefine(perennialRefinement);

// GET /api/ngushish/crops?...
export const listCropsQuerySchema = z.object({
  search: z.string().trim().min(1).optional(),
  status: cropStatusEnum.optional(),
  irrigated: z
    .union([z.literal("true"), z.literal("false"), z.boolean()])
    .transform((v) => (typeof v === "boolean" ? v : v === "true"))
    .optional(),
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(200).optional().default(20),
});

// POST /api/ngushish/harvests
export const createHarvestSchema = z.object({
  cropId: z.string().uuid("cropId must be a UUID"),
  quantityKg: z.number().positive("quantityKg must be > 0").max(1_000_000),
  harvestDate: z.coerce.date(),
  qualityGrade: z.string().max(40).optional(),
  notes: z.string().max(2000).optional(),
});

// GET /api/ngushish/harvests?cropId=&from=&to=
export const listHarvestsQuerySchema = z.object({
  cropId: z.string().uuid().optional(),
  from: z.coerce.date().optional(),
  to: z.coerce.date().optional(),
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(200).optional().default(50),
});

// POST /api/ngushish/dispatches
export const createDispatchSchema = z.object({
  cropId: z.string().uuid("cropId must be a UUID"),
  quantityKg: z.number().positive().max(1_000_000),
  destination: z.string().min(1).max(120),
  revenue: z.number().min(0, "revenue must be >= 0").max(1_000_000_000),
  dispatchDate: z.coerce.date(),
  buyerName: z.string().max(120).optional(),
  transportCost: z.number().min(0).max(1_000_000).optional(),
  notes: z.string().max(2000).optional(),
});

// GET /api/ngushish/dispatches?cropId=&from=&to=
export const listDispatchesQuerySchema = z.object({
  cropId: z.string().uuid().optional(),
  from: z.coerce.date().optional(),
  to: z.coerce.date().optional(),
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(200).optional().default(50),
});

// POST /api/ngushish/irrigation
export const createIrrigationSchema = z.object({
  cropId: z.string().uuid("cropId must be a UUID"),
  irrigationDate: z.coerce.date(),
  durationMinutes: z.number().int().positive().max(10_000).optional(),
  waterSource: z.string().max(80).optional(),
  notes: z.string().max(2000).optional(),
});

// GET /api/ngushish/irrigation?cropId=&from=&to=
export const listIrrigationQuerySchema = z.object({
  cropId: z.string().uuid().optional(),
  from: z.coerce.date().optional(),
  to: z.coerce.date().optional(),
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(200).optional().default(50),
});

// Path param :id used by detail / update / delete endpoints.
export const idParamSchema = z.object({
  id: z.string().uuid("id must be a UUID"),
});
