import { z } from "zod";

// POST /api/layers/production body. The HTML form requires opening stock
// and eggs collected; everything else is optional.
//   Computed server-side (NOT accepted from caller):
//     trays         = eggsCollected / 30
//     percentLaying = (eggsCollected / openingStock) * 100
//     closingStock  = openingStock - deadRemoved
//     dayAge        = previous record's dayAge + days elapsed
export const dailyEntrySchema = z.object({
  houseId: z.string().uuid("Invalid house ID"),

  openingStock: z
    .number({ invalid_type_error: "openingStock must be a number" })
    .int("openingStock must be an integer")
    .nonnegative("openingStock cannot be negative"),

  eggsCollected: z
    .number({ invalid_type_error: "eggsCollected must be a number" })
    .int("eggsCollected must be an integer")
    .nonnegative("eggsCollected cannot be negative"),

  feedKg: z.number().nonnegative().optional().default(0),
  deadRemoved: z.number().int().nonnegative().optional().default(0),
  householdUsed: z.number().int().nonnegative().optional().default(0),
  remarks: z.string().max(2000).optional(),

  // Optional explicit date — defaults to today server-side. Useful for
  // back-filling missed days.
  date: z.coerce.date().optional(),
});

export const daysQuerySchema = z.object({
  days: z.coerce.number().int().positive().max(90).optional().default(7),
  // When supplied, the production history endpoint returns only records for
  // that exact calendar day instead of the last `days` days from today.
  date: z.coerce.date().optional(),
});
