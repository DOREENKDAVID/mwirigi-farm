import { z } from "zod";

// Discriminated union: the same endpoint accepts AI or CALVING events with
// different required fields. The shared base resolves cows by tag (since the
// modal asks for a tag, not a UUID).

const baseEvent = {
  // Caller may pass either a tag (preferred — matches the form) or a cowId.
  tag: z.string().min(1).optional(),
  cowId: z.string().uuid().optional(),
  eventDate: z.coerce.date(),
  notes: z.string().max(2000).optional(),
};

const aiEvent = z.object({
  ...baseEvent,
  eventType: z.literal("AI"),
  sireCode: z.string().min(1).max(50).optional(),
});

const calvingEvent = z.object({
  ...baseEvent,
  eventType: z.literal("CALVING"),
  calfTag: z.string().min(1).max(20).optional(),
  // Extended calving detail fields (Calves register).
  calfSex: z.enum(["M", "F"]).optional(),
  calfBirthWeightKg: z.coerce.number().min(0).max(200).optional(),
  sireCode: z.string().min(1).max(50).optional(),
  calvingEase: z.coerce.number().int().min(1).max(5).optional(),
  calvingFate: z.string().max(120).optional(),
});

export const createReproductionSchema = z
  .discriminatedUnion("eventType", [aiEvent, calvingEvent])
  .refine((data) => data.tag || data.cowId, {
    message: "Either tag or cowId is required",
    path: ["tag"],
  });

export const updateReproductionSchema = z.object({
  pregnancyStatus: z.enum(["PENDING", "CONFIRMED", "OPEN", "ABORTED"]).optional(),
  pregnancyCheckDate: z.coerce.date().optional(),
  notes: z.string().max(2000).optional(),
}).refine((d) => Object.keys(d).length > 0, {
  message: "At least one field must be provided",
});

// "Pregnancy confirmed" UI option — patches the cow's most recent AI.
// Either tag or cowId must be provided. checkDate defaults to today server-side.
export const confirmPregnancySchema = z.object({
  tag: z.string().min(1).optional(),
  cowId: z.string().uuid().optional(),
  checkDate: z.coerce.date().optional(),
}).refine((d) => d.tag || d.cowId, {
  message: "Either tag or cowId is required",
  path: ["tag"],
});

export const listQuerySchema = z.object({
  search: z.string().optional(),
  status: z.enum(["PENDING", "CONFIRMED", "OPEN", "ABORTED"]).optional(),
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(200).optional().default(50),
});
