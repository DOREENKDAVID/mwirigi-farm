import { z } from "zod";

const ROLES = [
  "ADMIN",
  "CEO",
  "DAIRY_MANAGER",
  "LAYERS_MANAGER",
  "PIGGERY_MANAGER",
  "FEEDLOT_MANAGER",
  "VET",
  "STORE_MANAGER",
  "WORKER",
  "ICT",
];
const SALARY_TYPES = ["DAILY", "MONTHLY"];
const ATTENDANCE_STATUSES = ["PRESENT", "ABSENT", "HALF_DAY", "OFF"];
const TASK_PRIORITIES = ["LOW", "MEDIUM", "HIGH"];
const TASK_STATUSES = ["PENDING", "IN_PROGRESS", "DONE"];

// POST /api/staff — admin creates a staff member.
// Email is auto-derived if not provided (slug of fullName).
export const createStaffSchema = z.object({
  fullName: z
    .string()
    .min(2, "Full name is required")
    .max(80, "Full name too long"),
  email: z.string().email("Invalid email").optional(),
  role: z.enum(ROLES, {
    errorMap: () => ({ message: `Role must be one of: ${ROLES.join(", ")}` }),
  }),
  department: z.string().max(50).optional(),
  phoneNumber: z.string().max(20).optional(),
  nationalId: z.string().max(20).optional(),

  salaryType: z.enum(SALARY_TYPES).optional().default("DAILY"),
  dailyRate: z.number().positive().max(100000).optional(),
  monthlySalary: z.number().positive().max(10000000).optional(),
});

export const updateStaffSchema = z
  .object({
    role: z.enum(ROLES).optional(),
    department: z.string().max(50).nullable().optional(),
    jobTitle: z.string().max(80).nullable().optional(),
    phoneNumber: z.string().max(20).nullable().optional(),
    nationalId: z.string().max(20).nullable().optional(),
    salaryType: z.enum(SALARY_TYPES).nullable().optional(),
    dailyRate: z.number().positive().max(100000).nullable().optional(),
    monthlySalary: z.number().positive().max(10000000).nullable().optional(),
    isActive: z.boolean().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: "At least one field must be provided",
  });

// POST /api/staff/:id/release — structured termination workflow
export const RELEASE_REASONS = [
  "CONTRACT_ENDED",
  "RESIGNED",
  "DISMISSED",
  "RETIRED",
  "SEASONAL_ENDED",
  "OTHER",
];

export const releaseStaffSchema = z.object({
  releaseDate: z.coerce.date(),
  releaseReason: z.enum(RELEASE_REASONS),
  releaseNotes: z.string().max(500).optional().nullable(),
});

// POST /api/staff/attendance — admin sets attendance for a user
export const markAttendanceSchema = z.object({
  userId: z.string().uuid("Invalid user ID"),
  status: z.enum(ATTENDANCE_STATUSES),
  date: z.coerce.date().optional(),
});

// POST /api/staff/tasks
export const createTaskSchema = z.object({
  assignedToId: z.string().uuid("Invalid assignee ID"),
  unit: z.string().min(1).max(40),
  title: z.string().min(1).max(200),
  description: z.string().max(2000).optional(),
  priority: z.enum(TASK_PRIORITIES).optional().default("MEDIUM"),
  dueDate: z.coerce.date().optional(),
});

export const updateTaskSchema = z
  .object({
    unit: z.string().min(1).max(40).optional(),
    title: z.string().min(1).max(200).optional(),
    description: z.string().max(2000).nullable().optional(),
    priority: z.enum(TASK_PRIORITIES).optional(),
    status: z.enum(TASK_STATUSES).optional(),
    dueDate: z.coerce.date().nullable().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: "At least one field must be provided",
  });

export const payrollQuerySchema = z.object({
  month: z.coerce.number().int().min(1).max(12).optional(),
  year: z.coerce.number().int().min(2000).max(2100).optional(),
});

// POST /api/staff/tasks/:id/reassign
const REASSIGN_REASONS = [
  "SICK_LEAVE",
  "OFF_DAY",
  "VACATION",
  "EMERGENCY",
  "SHIFT_BALANCING",
  "OTHER",
];
const REASSIGN_DURATIONS = ["TODAY", "THIS_SHIFT", "PERMANENT", "OTHER"];

export const reassignTaskSchema = z.object({
  toUserId: z.string().uuid("Invalid replacement staff ID"),
  reason: z.enum(REASSIGN_REASONS),
  duration: z.enum(REASSIGN_DURATIONS).optional(),
  effectiveDate: z.coerce.date().optional(),
  notes: z.string().trim().max(2000).nullable().optional(),
  approvalRequired: z.boolean().optional(),
});

// PATCH /api/staff/workers/:id/availability
const WORKER_AVAILABILITY = [
  "AVAILABLE",
  "SICK_LEAVE",
  "OFF_DAY",
  "VACATION",
  "EMERGENCY",
  "OTHER_UNAVAILABLE",
];

export const workerAvailabilitySchema = z.object({
  availabilityStatus: z.enum(WORKER_AVAILABILITY),
  availabilityNote: z.string().trim().max(200).nullable().optional(),
});
