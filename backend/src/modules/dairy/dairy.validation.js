import { z } from "zod";

//////////////////////////////////////////////////////
// COW SCHEMA
//////////////////////////////////////////////////////

// Mirrors the Register Cow form in the HTML mockup. Fields:
// tag (text), breed (dropdown), dateOfBirth (date), status (dropdown).
// houseId is optional since there is no Houses endpoint yet.

const BREEDS = [
  "FRIESIAN",
  "AYRSHIRE",
  "JERSEY",
  "BROWN_SWISS",
  "SAHIWAL",
  "BORAN",
  "ZEBU",
  "CROSSBREED",
];
const COW_STATUSES = [
  "MILKING",
  "DRY_OFF",
  "PREGNANT",
  "SICK",
  "HEIFER",
  "OPEN",
];
const BREED_ORIGINS = ["F", "L", "X"]; // Exotic / Local / Crossbreed

export const cowSchema = z.object({
  tag: z
    .string()
    .min(1, "Tag is required")
    .max(20, "Tag too long")
    .transform((val) =>
      val.trim().charAt(0).toUpperCase() +
      val.trim().slice(1).toLowerCase()
    ),

  breed: z.enum(BREEDS, {
    errorMap: () => ({ message: `Breed must be one of: ${BREEDS.join(", ")}` }),
  }),

  dateOfBirth: z.coerce.date({
    errorMap: () => ({ message: "dateOfBirth is required (ISO date)" }),
  }),

  status: z.enum(COW_STATUSES, {
    errorMap: () => ({ message: `Status must be one of: ${COW_STATUSES.join(", ")}` }),
  }),

  // Free-text. Required at the service layer when status is SICK or
  // DRY_OFF (assertStatusReasonIfRequired in dairy.service.js).
  statusReason: z.string().trim().max(2000).nullable().optional(),

  houseId: z
    .string()
    .uuid("Invalid house ID")
    .nullable()
    .optional(),

  // Direct worker assignment. Operational milk-logging filters by this.
  // Independent of houseId so a worker can supervise cows across houses.
  workerId: z
    .string()
    .uuid("Invalid worker ID")
    .nullable()
    .optional(),

  // ----- Extended cow record (Register Cow dialog v4.1) -----
  nickname: z.string().trim().max(60).nullable().optional(),
  imageUrl: z.string().trim().max(400).nullable().optional(),
  breedOrigin: z.enum(BREED_ORIGINS).nullable().optional(),
  lactationNumber: z.number().int().min(0).max(20).nullable().optional(),
  weightKg: z.number().min(0).max(2000).nullable().optional(),
  colorMarkings: z.string().trim().max(120).nullable().optional(),
  acquisitionDate: z.coerce.date().nullable().optional(),
  acquisitionType: z.string().trim().max(40).nullable().optional(),
  motherTag: z.string().trim().max(20).nullable().optional(),
  fatherTag: z.string().trim().max(20).nullable().optional(),
  healthNotes: z.string().trim().max(2000).nullable().optional(),
});

// POST /api/dairy/cows/tag/:tag/release — remove cow from active herd.
// authorizedById is taken from req.user, not the request body.
const RELEASE_TYPES = [
  "SOLD",
  "TRANSFERRED",
  "SLAUGHTERED",
  "DIED",
  "DONATED",
  "OTHER",
];

export const releaseCowSchema = z.object({
  releaseType: z.enum(RELEASE_TYPES, {
    errorMap: () => ({
      message: `releaseType must be one of: ${RELEASE_TYPES.join(", ")}`,
    }),
  }),
  releaseDate: z.coerce.date().optional(),
  destination: z.string().trim().max(200).nullable().optional(),
  reason: z.string().trim().max(2000).nullable().optional(),
  documentUrl: z.string().trim().max(500).nullable().optional(),
});

//////////////////////////////////////////////////////
// MILK RECORD SCHEMA
//////////////////////////////////////////////////////

export const milkRecordSchema = z.object({
  cowId: z
    .string()
    .uuid("Invalid cow ID")
    .optional(),

  tag: z
    .string()
    .min(1)
    .optional(),

  litres: z
    .number({
      invalid_type_error: "Litres must be a number",
    })
    .positive("Litres must be greater than 0")
    .max(100, "Unrealistic milk value"),

  // Must match Prisma SessionType enum exactly (AM | MID | PM).
  session: z.enum(["AM", "MID", "PM"]),

  date: z.coerce.date(),

}).refine((data) => data.cowId || data.tag, {
  message: "Either cowId or tag is required",
  path: ["cowId"],
});

//////////////////////////////////////////////////////
// DAIRY INVENTORY SCHEMA
//////////////////////////////////////////////////////

const INVENTORY_CATEGORIES = ["Bedding", "Equipment", "Veterinary"];
const INVENTORY_CONDITIONS = ["Good", "Fair", "Poor"];

export const dairyInventorySchema = z.object({
  name: z.string().trim().min(1, "Name is required").max(120),
  category: z.enum(INVENTORY_CATEGORIES, {
    errorMap: () => ({
      message: `Category must be one of: ${INVENTORY_CATEGORIES.join(", ")}`,
    }),
  }),
  quantity: z
    .number({ invalid_type_error: "Quantity must be a number" })
    .min(0, "Quantity cannot be negative"),
  unit: z.string().trim().max(40).nullable().optional(),
  location: z.string().trim().max(120).nullable().optional(),
  condition: z.enum(INVENTORY_CONDITIONS).nullable().optional(),
  notes: z.string().trim().max(2000).nullable().optional(),
});

export const dairyInventoryPatchSchema = dairyInventorySchema.partial();
