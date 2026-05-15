import { z } from "zod";

// POST /api/feedlot/bulls — register a new bull entering the feedlot.
// `currentWeight` defaults to entryWeight on the server side.
export const createBullSchema = z.object({
  tag: z.string().min(1, "Tag is required").max(20, "Tag too long"),
  breed: z.string().min(1, "Breed is required").max(50),
  entryDate: z.coerce.date(),
  entryWeight: z
    .number({ invalid_type_error: "entryWeight must be a number" })
    .positive("entryWeight must be > 0")
    .max(2000),
});

// POST /api/feedlot/weights — log a new weight reading and update the
// bull's currentWeight.
export const createWeightSchema = z.object({
  bullId: z.string().uuid("Invalid bull ID"),
  weight: z.number().positive().max(2000),
  date: z.coerce.date().optional(),
});

// PATCH /api/feedlot/bulls/:id — partial update.
// When `currentWeight` is included AND differs from the stored value, the
// service also creates a WeightRecord for audit history.
export const updateBullSchema = z
  .object({
    breed: z.string().min(1).max(50).optional(),
    currentWeight: z.number().positive().max(2000).optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: "At least one field must be provided",
  });

// POST /api/feedlot/sheep — register one tagged sheep.
export const createSheepSchema = z.object({
  tag: z.string().min(1, "Tag is required").max(20, "Tag too long"),
  category: z.enum(["EWE", "RAM", "LAMB"]),
  entryDate: z.coerce.date(),
  entryWeight: z.number().positive().max(500).optional(),
});

// PATCH /api/feedlot/sheep/:id — partial update (category + currentWeight).
export const updateSheepSchema = z
  .object({
    category: z.enum(["EWE", "RAM", "LAMB"]).optional(),
    currentWeight: z.number().positive().max(500).optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: "At least one field must be provided",
  });

// POST /api/feedlot/lambing — log a lambing event.
export const lambingSchema = z.object({
  date: z.coerce.date().optional(),
  lambsBorn: z.number().int().positive().max(20),
});

// GET /api/feedlot/lambing?month=YYYY-MM | current
export const lambingQuerySchema = z.object({
  month: z
    .string()
    .regex(/^(\d{4}-\d{2}|current)$/, "month must be YYYY-MM or 'current'")
    .optional()
    .default("current"),
});
