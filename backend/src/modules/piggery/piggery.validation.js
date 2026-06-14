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
    servicedSowId: z.string().uuid().nullable().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: "At least one field must be provided",
  });

// PATCH /api/piggery/farrowing/:id — edit an existing farrowing record.
export const updateFarrowingSchema = z
  .object({
    date:        z.coerce.date().optional(),
    service:     z.coerce.date().nullable().optional(),
    winners:     z.number().int().min(0).max(30).nullable().optional(),
    fatteners:   z.number().int().min(0).max(30).nullable().optional(),
    beaconners:  z.number().int().min(0).max(30).nullable().optional(),
    pigletsDead: z.number().int().min(0).max(30).optional(),
    remarks:     z.string().max(500).nullable().optional(),
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

// FC dispatch log. `amount` is optional — most deliveries log a price
// the moment they leave so the finance ledger updates atomically, but
// deliveries where payment is still being negotiated can save with
// amount omitted and reconcile later.
const FC_CATEGORIES = ["Beaconners", "Fatteners", "Winners", "Mixed"];

// POST /api/piggery/pens/:id/release
// finalWeight is computed server-side: totalWeight - (30kg × count)
const RELEASE_DESTINATIONS = ["FARMERS_CHOICE", "LOCAL_SALE", "OTHER"];

const PIG_RELEASE_REASONS = ["SOLD", "CULLED", "DIED", "OLD_AGE", "INJURED", "OTHER"];

// POST /api/piggery/pigs/:id/release
export const releasePigSchema = z.object({
  releaseReason:  z.enum(PIG_RELEASE_REASONS).default("OTHER"),
  releaseAmount:  z.number().nonnegative().optional(),
  releaseNotes:   z.string().trim().max(500).optional(),
  releaseDate:    z.coerce.date().optional(),
});

export const releasePenSchema = z.object({
  totalWeight: z.number().positive("Total live weight must be > 0"),
  destination: z.enum(RELEASE_DESTINATIONS),
  // Farmers Choice fields (required when destination === FARMERS_CHOICE)
  ref: z.string().trim().max(80).optional(),
  category: z.enum(FC_CATEGORIES).optional(),
  ageRange: z.string().trim().max(40).optional(),
  driver: z.string().trim().max(80).optional(),
  // Financial — optional for both FC and LOCAL_SALE
  amount: z.number().nonnegative().optional(),
  // Free-text note shown for OTHER / LOCAL_SALE destinations
  destinationNote: z.string().trim().max(200).optional(),
  notes: z.string().trim().max(500).optional(),
});

// POST /api/piggery/pens/:id/request-release
// Farmers Choice approval-flow: worker locks the pen and creates a request.
export const requestReleaseSchema = z.object({
  category: z.enum(FC_CATEGORIES).default("Beaconners"),
  ageRange: z.string().trim().max(40).optional(),
});

// PATCH /api/piggery/release-requests/:id/approve (no body needed)
export const approveRequestSchema = z.object({}).passthrough();

// PATCH /api/piggery/release-requests/:id/reject
export const rejectRequestSchema = z.object({
  notes: z.string().trim().max(500).optional(),
});

// POST /api/piggery/dispatch/confirm
export const confirmDispatchSchema = z.object({
  pendingDispatchId: z.string().uuid("Invalid batch ID"),
  date:     z.coerce.date().optional(),
  ref:      z.string().trim().max(80).optional(),
  driver:   z.string().trim().max(80).optional(),
  ageRange: z.string().trim().max(40).optional(),
  amount:   z.number().nonnegative().optional(),
  notes:    z.string().trim().max(500).optional(),
});

export const farmersChoiceDeliverySchema = z.object({
  date: z.coerce.date().optional(),
  ref: z.string().trim().min(1, "Reference is required").max(80),
  pens: z.string().trim().min(1, "Pens label is required").max(120),
  count: z.coerce.number().int().positive().max(10000),
  category: z.enum(FC_CATEGORIES),
  ageRange: z.string().trim().max(40).nullable().optional(),
  driver: z.string().trim().min(1, "Driver is required").max(80),
  notes: z.string().trim().max(500).nullable().optional(),
  amount: z.coerce.number().nonnegative().optional(),
});
