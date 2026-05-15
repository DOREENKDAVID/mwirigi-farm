import { z } from "zod";

const PIG_CATEGORIES = ["SOW", "BOAR", "PIGLET"];
const PIG_STATUSES = [
  "LACTATING",
  "GESTATING",
  "FARROWING_SOON",
  "WEANED",
  "DRY",
  "SERVICE",
];

// POST /api/piggery/pigs — register a single pig.
export const createPigSchema = z.object({
  tag: z.string().min(1, "Tag is required").max(20, "Tag too long"),
  category: z.enum(PIG_CATEGORIES),
  status: z.enum(PIG_STATUSES).optional(),
  litterCount: z.number().int().min(0).optional(),
  lastFarrowed: z.coerce.date().optional(),
  dueDate: z.coerce.date().optional(),
  house: z.string().max(8).optional(),
  pen: z.string().max(12).optional(),
  serviceDate: z.coerce.date().optional(),
  expFarrow: z.coerce.date().optional(),
  breed: z.string().max(40).optional(),
  age: z.string().max(40).optional(),
  role: z.string().max(120).optional(),
  note: z.string().max(500).optional(),
});

// POST /api/piggery/farrowing — log a farrowing event.
export const farrowingSchema = z
  .object({
    sowId: z.string().uuid("Invalid sow ID"),
    pigletsBorn: z.number().int().min(0, "Cannot be negative").max(30),
    pigletsAlive: z.number().int().min(0).max(30),
    pigletsDead: z.number().int().min(0).max(30),
    winners: z.number().int().min(0).max(30).optional(),
    fatteners: z.number().int().min(0).max(30).optional(),
    beaconners: z.number().int().min(0).max(30).optional(),
    remarks: z.string().max(500).optional(),
    service: z.coerce.date().optional(),
    date: z.coerce.date().optional(),
  })
  .refine((d) => d.pigletsAlive + d.pigletsDead === d.pigletsBorn, {
    message: "pigletsAlive + pigletsDead must equal pigletsBorn",
    path: ["pigletsBorn"],
  })
  .refine(
    (d) => {
      if (!d.date) return true;
      const endOfToday = new Date();
      endOfToday.setHours(23, 59, 59, 999);
      return d.date.getTime() <= endOfToday.getTime();
    },
    { message: "date cannot be in the future", path: ["date"] },
  );

// PATCH /api/piggery/pigs/:id — partial update.
export const updatePigSchema = z
  .object({
    status: z.enum(PIG_STATUSES).nullable().optional(),
    dueDate: z.coerce.date().nullable().optional(),
    litterCount: z.number().int().min(0).max(50).optional(),
    house: z.string().max(8).nullable().optional(),
    pen: z.string().max(12).nullable().optional(),
    serviceDate: z.coerce.date().nullable().optional(),
    expFarrow: z.coerce.date().nullable().optional(),
    breed: z.string().max(40).nullable().optional(),
    age: z.string().max(40).nullable().optional(),
    role: z.string().max(120).nullable().optional(),
    note: z.string().max(500).nullable().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: "At least one field must be provided",
  });

export const trendQuerySchema = z.object({
  months: z.coerce.number().int().positive().max(36).optional().default(6),
});

export const sowSearchSchema = z.object({
  search: z.string().optional(),
  house: z.string().max(8).optional(),
  status: z.enum(PIG_STATUSES).optional(),
});

export const farrowingQuerySchema = z.object({
  limit: z.coerce.number().int().positive().max(200).optional().default(50),
});
