import { z } from "zod";

const CATEGORIES = ["Feed", "Vaccines", "Consumables"];
const CONDITIONS = ["Good", "Fair", "Poor"];

export const itemSchema = z.object({
  name: z.string().trim().min(1, "Name is required").max(120),
  category: z.enum(CATEGORIES, {
    errorMap: () => ({
      message: `Category must be one of: ${CATEGORIES.join(", ")}`,
    }),
  }),
  subCategory: z.string().trim().max(120).nullable().optional(),
  quantity: z
    .number({ invalid_type_error: "Quantity must be a number" })
    .min(0, "Quantity cannot be negative"),
  unit: z.string().trim().max(40).nullable().optional(),
  lowThreshold: z.number().min(0).nullable().optional(),
  location: z.string().trim().max(120).nullable().optional(),
  condition: z.enum(CONDITIONS).nullable().optional(),
  expiresAt: z.coerce.date().nullable().optional(),
  notes: z.string().trim().max(2000).nullable().optional(),
});

export const itemPatchSchema = itemSchema.partial();
