import { z } from "zod";

// ----- shared enum schemas -----
const HealthUnit = z.enum([
  "Dairy",
  "Piggery",
  "Layers",
  "Doopers",
  "Feedlot",
]);

const TreatmentStatus = z.enum([
  "ACTIVE",
  "IMPROVING",
  "RECOVERED",
  "CANCELLED",
]);

// Coerce ISO strings → Date so controllers can stay thin.
const dateSchema = z.coerce.date();

// ----- POST /api/health/vaccinations -----
//
// Logs a completed vaccination. Polymorphic — exactly one of two shapes:
//
//   1. Cross-unit / annual / recurring → set `protocolId`. The record
//      is filed against a stored VaccineProtocol.
//
//   2. Brooder / chick batch → set `brooderId` + `vaccineName` +
//      `dayOffset`. The protocol itself lives in code
//      (BROODER_VACCINE_PROTOCOL); the record is the single source of
//      truth that the Layers dashboard reads to mark a step DONE.
//
// `superRefine` enforces "exactly one shape, not both, not neither."
export const createVaccinationSchema = z
  .object({
    protocolId: z.string().uuid().optional(),
    brooderId: z.string().uuid().optional(),
    vaccineName: z.string().min(1).max(120).optional(),
    dayOffset: z.number().int().min(0).max(365).optional(),

    unit: HealthUnit.optional(),
    animalCount: z.number().int().positive(),
    administeredAt: dateSchema,
    nextDueOverride: dateSchema.nullable().optional(),
    notes: z.string().max(500).optional().nullable(),
    administeredBy: z.string().max(80).optional().nullable(),
  })
  .superRefine((d, ctx) => {
    const isProtocol = !!d.protocolId;
    const isBrooder =
      !!d.brooderId || !!d.vaccineName || d.dayOffset !== undefined;

    if (isProtocol && isBrooder) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["protocolId"],
        message:
          "Provide either protocolId OR (brooderId + vaccineName + dayOffset), not both",
      });
      return;
    }
    if (!isProtocol && !isBrooder) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["protocolId"],
        message:
          "Provide protocolId, or (brooderId + vaccineName + dayOffset)",
      });
      return;
    }
    if (isBrooder) {
      // All three brooder fields must be present together.
      if (!d.brooderId) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["brooderId"],
          message: "brooderId is required for brooder vaccinations",
        });
      }
      if (!d.vaccineName) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["vaccineName"],
          message: "vaccineName is required for brooder vaccinations",
        });
      }
      if (d.dayOffset === undefined) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ["dayOffset"],
          message: "dayOffset is required for brooder vaccinations",
        });
      }
    }
  });

// ----- POST /api/health/treatments -----
export const createTreatmentSchema = z.object({
  tag: z.string().min(1).max(40),
  unit: HealthUnit,
  diagnosis: z.string().min(2).max(160),
  medication: z.string().min(2).max(160),
  startDate: dateSchema,
  attendingVet: z.string().max(80).optional().nullable(),
  notes: z.string().max(500).optional().nullable(),
});

// ----- PATCH /api/health/vaccinations/records/:id -----
// All fields optional — caller only sends what changed.
export const updateVaccinationRecordSchema = z.object({
  animalCount: z.number().int().positive().optional(),
  administeredAt: dateSchema.optional(),
  nextDueOverride: dateSchema.nullable().optional(),
  notes: z.string().max(500).optional().nullable(),
  administeredBy: z.string().max(80).optional().nullable(),
});

// ----- PATCH /api/health/treatments/:id -----
export const updateTreatmentSchema = z.object({
  diagnosis: z.string().min(2).max(160).optional(),
  medication: z.string().min(2).max(160).optional(),
  status: TreatmentStatus.optional(),
  endDate: dateSchema.nullable().optional(),
  notes: z.string().max(500).optional().nullable(),
});
