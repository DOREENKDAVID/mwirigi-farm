import prisma from "../../prisma/client.js";
import { hashPassword } from "../../utils/password.js";

const startOfDay = (d) => {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
};
const endOfDay = (d) => {
  const x = new Date(d);
  x.setHours(23, 59, 59, 999);
  return x;
};
const startOfMonth = (y, m) => new Date(y, m - 1, 1);
const startOfNextMonth = (y, m) => new Date(y, m, 1);

// Generates a memorable temp password the admin can read off the screen.
// Format: Farm-XXXX1!  (4-char hex). All staff start with mustChangePassword=true.
const generateTempPassword = () => {
  const hex = Math.random().toString(16).slice(2, 6).toUpperCase();
  return `Farm-${hex}1!`;
};

// Slugify a full name into a usable email if none was provided.
const emailFromName = (fullName) => {
  const slug = fullName
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ".")
    .replace(/^\.|\.$/g, "");
  return `${slug}@mwirigi.farm`;
};

// User → API shape used by both list and per-id reads.
const projectUser = (u) => ({
  id: u.id,
  fullName: u.userName,
  email: u.email,
  role: u.role,
  department: u.department,
  phoneNumber: u.phoneNumber,
  nationalId: u.nationalId,
  salaryType: u.salaryType,
  dailyRate: u.dailyRate,
  monthlySalary: u.monthlySalary,
  isActive: u.isActive,
  mustChangePassword: u.mustChangePassword,
  createdAt: u.createdAt,
});

//////////////////////////////////////////////////////
// STAFF CRUD
//////////////////////////////////////////////////////

// POST /api/staff
// Creates a User + sets a temporary password the admin hands out once.
// Returns { staff, tempPassword } so the UI can surface the password.
export const createStaff = async (input) => {
  const email = (input.email ?? emailFromName(input.fullName)).toLowerCase();

  const existing = await prisma.user.findFirst({
    where: { OR: [{ email }, { userName: input.fullName.trim() }] },
  });
  if (existing)
    throw new Error("A user with this name or email already exists");

  const tempPassword = generateTempPassword();
  const hashed = await hashPassword(tempPassword);

  const user = await prisma.user.create({
    data: {
      userName: input.fullName.trim(),
      email,
      password: hashed,
      role: input.role,
      department: input.department ?? null,
      phoneNumber: input.phoneNumber ?? null,
      nationalId: input.nationalId ?? null,
      salaryType: input.salaryType ?? "DAILY",
      dailyRate: input.dailyRate ?? null,
      monthlySalary: input.monthlySalary ?? null,
      mustChangePassword: true,
      // Pre-verified — admin-created staff can log in straight away with
      // the temp password, no email-OTP gate.
      emailVerified: true,
    },
  });

  return { staff: projectUser(user), tempPassword };
};

// GET /api/staff
export const listStaff = async ({ includeInactive = false } = {}) => {
  const users = await prisma.user.findMany({
    where: includeInactive ? {} : { isActive: true },
    orderBy: { userName: "asc" },
  });
  return users.map(projectUser);
};

export const getStaffById = async (id) => {
  const user = await prisma.user.findUnique({ where: { id } });
  if (!user) throw new Error("Staff not found");
  return projectUser(user);
};

export const updateStaff = async (id, patch) => {
  const existing = await prisma.user.findUnique({ where: { id } });
  if (!existing) throw new Error("Staff not found");
  const data = {};
  for (const k of [
    "role",
    "department",
    "phoneNumber",
    "nationalId",
    "salaryType",
    "dailyRate",
    "monthlySalary",
    "isActive",
  ]) {
    if (k in patch) data[k] = patch[k];
  }
  const updated = await prisma.user.update({ where: { id }, data });
  return projectUser(updated);
};

// DELETE /api/staff/:id  (soft — flips isActive=false)
export const deactivateStaff = async (id) => {
  const existing = await prisma.user.findUnique({ where: { id } });
  if (!existing) throw new Error("Staff not found");
  return prisma.user.update({
    where: { id },
    data: { isActive: false },
  });
};

//////////////////////////////////////////////////////
// ATTENDANCE
//////////////////////////////////////////////////////

// POST /api/staff/attendance — admin sets/changes attendance for a user.
// Idempotent on (userId, date): re-marking the same day overwrites status.
export const markAttendance = async ({ userId, status, date }) => {
  const day = startOfDay(date ?? new Date());
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new Error("User not found");

  return prisma.attendance.upsert({
    where: { userId_date: { userId, date: day } },
    create: { userId, status, date: day },
    update: { status },
  });
};

// POST /api/staff/attendance/check-in — self-check-in for the logged-in user.
export const checkIn = async ({ userId }) => {
  const day = startOfDay(new Date());
  return prisma.attendance.upsert({
    where: { userId_date: { userId, date: day } },
    create: {
      userId,
      status: "PRESENT",
      date: day,
      checkIn: new Date(),
    },
    update: { status: "PRESENT", checkIn: new Date() },
  });
};

export const checkOut = async ({ userId }) => {
  const day = startOfDay(new Date());
  const existing = await prisma.attendance.findUnique({
    where: { userId_date: { userId, date: day } },
  });
  if (!existing)
    throw new Error("Cannot check out without checking in first");
  return prisma.attendance.update({
    where: { userId_date: { userId, date: day } },
    data: { checkOut: new Date() },
  });
};

// GET /api/staff/attendance/today — one row per active staff member, with
// the day's status. Users with no row yet are reported as ABSENT.
export const getTodayAttendance = async () => {
  const today = startOfDay(new Date());
  const [users, records] = await Promise.all([
    prisma.user.findMany({
      where: { isActive: true },
      orderBy: { userName: "asc" },
    }),
    prisma.attendance.findMany({
      where: { date: today },
    }),
  ]);
  const byUser = new Map(records.map((r) => [r.userId, r]));
  return users.map((u) => {
    const r = byUser.get(u.id);
    return {
      userId: u.id,
      fullName: u.userName,
      role: u.role,
      department: u.department,
      status: r?.status ?? "ABSENT",
      checkIn: r?.checkIn ?? null,
      checkOut: r?.checkOut ?? null,
    };
  });
};

//////////////////////////////////////////////////////
// TASKS
//////////////////////////////////////////////////////

// POST /api/staff/tasks
export const createTask = async (input, createdById) => {
  const assignee = await prisma.user.findUnique({
    where: { id: input.assignedToId },
  });
  if (!assignee) throw new Error("Assignee not found");
  return prisma.task.create({
    data: {
      assignedToId: input.assignedToId,
      assignedById: createdById,
      unit: input.unit.trim(),
      title: input.title.trim(),
      description: input.description ?? null,
      priority: input.priority ?? "MEDIUM",
      dueDate: input.dueDate ?? null,
    },
    include: {
      assignedTo: { select: { userName: true } },
    },
  });
};

// GET /api/staff/tasks — today's tasks, newest first.
export const listTasksToday = async () => {
  const start = startOfDay(new Date());
  const end = endOfDay(new Date());
  const tasks = await prisma.task.findMany({
    where: { createdAt: { gte: start, lte: end } },
    orderBy: { createdAt: "desc" },
    include: {
      assignedTo: { select: { id: true, userName: true } },
    },
  });
  return tasks.map((t) => ({
    id: t.id,
    assignedToId: t.assignedToId,
    assignedToName: t.assignedTo.userName,
    unit: t.unit,
    title: t.title,
    description: t.description,
    priority: t.priority,
    status: t.status,
    dueDate: t.dueDate,
  }));
};

export const updateTask = async (id, patch) => {
  const existing = await prisma.task.findUnique({ where: { id } });
  if (!existing) throw new Error("Task not found");
  return prisma.task.update({
    where: { id },
    data: patch,
    include: {
      assignedTo: { select: { id: true, userName: true } },
    },
  });
};

// Reassign a task to a different user, creating a TaskReassignment
// audit row alongside the assignedToId mutation. Both writes go in
// a single transaction so the audit trail can't fall out of sync
// with the actual assignment.
export const reassignTask = async (taskId, input, byUserId) => {
  const task = await prisma.task.findUnique({ where: { id: taskId } });
  if (!task) throw new Error("Task not found");

  const newAssignee = await prisma.user.findUnique({
    where: { id: input.toUserId },
  });
  if (!newAssignee) throw new Error("Replacement staff not found");

  if (task.assignedToId === input.toUserId) {
    throw new Error("Task is already assigned to this user");
  }

  return prisma.$transaction(async (tx) => {
    await tx.taskReassignment.create({
      data: {
        taskId,
        fromUserId: task.assignedToId,
        toUserId: input.toUserId,
        byUserId,
        reason: input.reason,
        duration: input.duration ?? "TODAY",
        effectiveDate: input.effectiveDate ?? new Date(),
        notes: input.notes ?? null,
        approvalRequired: input.approvalRequired ?? false,
      },
    });
    return tx.task.update({
      where: { id: taskId },
      data: { assignedToId: input.toUserId },
      include: {
        assignedTo: { select: { id: true, userName: true } },
      },
    });
  });
};

// Update a worker's availability flag and optional note. Drives the
// task / shift picker UI — workers in non-AVAILABLE states are greyed
// out so dispatchers don't accidentally assign to someone off-duty.
export const setWorkerAvailability = async (workerId, input) => {
  const worker = await prisma.worker.findUnique({ where: { id: workerId } });
  if (!worker) throw new Error("Worker not found");
  return prisma.worker.update({
    where: { id: workerId },
    data: {
      availabilityStatus: input.availabilityStatus,
      availabilityNote: input.availabilityNote ?? null,
      availabilityChangedAt: new Date(),
    },
  });
};

export const deleteTask = async (id) => {
  const existing = await prisma.task.findUnique({ where: { id } });
  if (!existing) throw new Error("Task not found");
  return prisma.task.delete({ where: { id } });
};

//////////////////////////////////////////////////////
// PAYROLL
//////////////////////////////////////////////////////

const computeGross = (user, daysWorked) => {
  if (user.salaryType === "MONTHLY") return user.monthlySalary ?? 0;
  return Math.round((daysWorked ?? 0) * (user.dailyRate ?? 0));
};

// Resolve the display "unit" for the roster / payroll table. The seed
// sets `department` per the master roster (Dairy / Piggery / Layers /
// Feedlot / Feeds / Ngushish / All units / Management / ICT) so when
// it's present, trust it. Only fall back to the role-based mapping
// when department is missing (legacy rows).
const unitLabelFor = (role, department) => {
  if (department && department.trim()) return department;
  switch (role) {
    case "DAIRY_MANAGER":
      return "Dairy";
    case "LAYERS_MANAGER":
      return "Layers";
    case "PIGGERY_MANAGER":
      return "Piggery";
    case "FEEDLOT_MANAGER":
      return "Feedlot";
    case "FEEDS_MANAGER":
      return "Feeds";
    case "STORE_MANAGER":
      return "Store";
    case "VET":
      return "All units";
    case "ADMIN":
    case "CEO":
      return "Management";
    case "WORKER":
      return "—";
    case "ICT":
      return "ICT";
    default:
      return "—";
  }
};

// GET /api/staff/payroll?month=&year= — payroll summary for the given period
// (defaults to current month). Days-worked = count of PRESENT attendance.
// Status comes from a Payroll row if one exists, else PENDING.
export const getPayrollSummary = async ({ month, year } = {}) => {
  const now = new Date();
  const m = month ?? now.getMonth() + 1;
  const y = year ?? now.getFullYear();
  const periodStart = startOfMonth(y, m);
  const periodEnd = startOfNextMonth(y, m);

  const [users, attendance, payrolls, adjustments] = await Promise.all([
    prisma.user.findMany({
      where: { isActive: true },
      orderBy: { userName: "asc" },
    }),
    prisma.attendance.findMany({
      where: {
        date: { gte: periodStart, lt: periodEnd },
        status: "PRESENT",
      },
      select: { userId: true },
    }),
    prisma.payroll.findMany({ where: { month: m, year: y } }),
    prisma.payrollAdjustment.findMany({
      where: { month: m, year: y },
      orderBy: { requestedAt: "desc" },
    }),
  ]);

  const daysByUser = new Map();
  for (const a of attendance) {
    daysByUser.set(a.userId, (daysByUser.get(a.userId) ?? 0) + 1);
  }
  const payrollByUser = new Map(payrolls.map((p) => [p.userId, p]));

  // Group adjustments by user so each row knows its own pills.
  const adjByUser = new Map();
  for (const a of adjustments) {
    if (!adjByUser.has(a.userId)) adjByUser.set(a.userId, []);
    adjByUser.get(a.userId).push(a);
  }

  const rows = users.map((u) => {
    const daysWorked = daysByUser.get(u.id) ?? 0;
    const gross = computeGross(u, daysWorked);
    const stored = payrollByUser.get(u.id);
    const userAdjustments = adjByUser.get(u.id) ?? [];

    // Net = gross + bonuses + overtime − advances − penalties.
    // Only APPROVED / DEDUCTED adjustments affect net pay; PENDING and
    // DECLINED don't.
    const counted = userAdjustments.filter((a) =>
      a.status === "APPROVED" || a.status === "DEDUCTED",
    );
    const advances = counted
      .filter((a) => a.type === "ADVANCE")
      .reduce((s, a) => s + a.amount, 0);
    const bonuses = counted
      .filter((a) => a.type === "BONUS")
      .reduce((s, a) => s + a.amount, 0);
    const penalties = counted
      .filter((a) => a.type === "PENALTY")
      .reduce((s, a) => s + a.amount, 0);
    const overtime = counted
      .filter((a) => a.type === "OVERTIME")
      .reduce((s, a) => s + a.amount, 0);

    const grossPay = stored?.grossPay ?? gross;
    const netPay = grossPay + bonuses + overtime - advances - penalties;

    return {
      userId: u.id,
      name: u.userName,
      role: u.role,
      jobTitle: u.jobTitle,
      unit: unitLabelFor(u.role, u.department),
      daysWorked,
      dailyRate: u.dailyRate,
      monthlySalary: u.monthlySalary,
      salaryType: u.salaryType ?? "DAILY",
      grossPay,
      bonuses,
      overtime,
      advances,
      penalties,
      netPay: Number(netPay.toFixed(2)),
      status: stored?.status ?? "PENDING",
      adjustments: userAdjustments.map((a) => ({
        id: a.id,
        type: a.type,
        status: a.status,
        amount: a.amount,
        reason: a.reason,
        notes: a.notes,
        referenceNo: a.referenceNo,
        requestDate: a.requestDate ?? a.requestedAt,
        approvedDate: a.approvedDate ?? a.approvedAt,
        disbursedDate: a.disbursedDate,
        repaymentMonth: a.repaymentMonth,
        repaymentYear: a.repaymentYear,
        paymentMethod: a.paymentMethod,
        transactionCode: a.transactionCode,
        requestedAt: a.requestedAt,
        approvedAt: a.approvedAt,
        approvedById: a.approvedById,
      })),
    };
  });

  return {
    month: m,
    year: y,
    rows,
    totalGross: rows.reduce((s, r) => s + (r.grossPay ?? 0), 0),
    totalNet: rows.reduce((s, r) => s + (r.netPay ?? 0), 0),
  };
};

// =====================================================================
// Payroll adjustments — advances, bonuses, penalties, overtime
// =====================================================================

export const listAdjustments = async ({ userId, month, year, status } = {}) => {
  const where = {};
  if (userId) where.userId = userId;
  if (month) where.month = month;
  if (year) where.year = year;
  if (status) where.status = status;
  return prisma.payrollAdjustment.findMany({
    where,
    orderBy: { requestedAt: "desc" },
  });
};

// Generate a unique reference number `ADV-<year>-<5-digit counter>`.
// Counts existing ADVANCE rows for this year and adds one — atomic
// enough for a single-farm dev fixture; in production you'd want a
// sequence table or upsert-on-conflict.
const nextAdvanceReferenceNo = async (year) => {
  const count = await prisma.payrollAdjustment.count({
    where: { type: "ADVANCE", referenceNo: { not: null } },
  });
  const counter = String(count + 1).padStart(5, "0");
  return `ADV-${year}-${counter}`;
};

export const createAdjustment = async (input, requesterId) => {
  const now = new Date();
  const type = input.type ?? "ADVANCE";
  const status = input.status ?? "PENDING";
  const month = input.month ?? now.getMonth() + 1;
  const year = input.year ?? now.getFullYear();

  // Validate payment method requirements. M-Pesa is the most common
  // disbursement method on this farm — the txn code is the audit trail
  // for the manager to reconcile against their phone.
  if (input.paymentMethod === "MPESA" && !input.transactionCode) {
    const err = new Error(
      "M-Pesa transaction code is required when payment method is M-Pesa",
    );
    err.code = "VALIDATION";
    throw err;
  }

  // Auto-generate referenceNo on ADVANCE rows.
  const referenceNo =
    type === "ADVANCE"
      ? (input.referenceNo ?? (await nextAdvanceReferenceNo(year)))
      : (input.referenceNo ?? null);

  const isCommitted = status === "APPROVED" || status === "DEDUCTED";

  return prisma.payrollAdjustment.create({
    data: {
      userId: input.userId,
      type,
      status,
      amount: input.amount,
      month,
      year,
      reason: input.reason ?? null,
      notes: input.notes ?? null,
      referenceNo,
      requestDate:
        input.requestDate ? new Date(input.requestDate) : new Date(),
      approvedDate: input.approvedDate
        ? new Date(input.approvedDate)
        : (isCommitted ? new Date() : null),
      disbursedDate:
        input.disbursedDate ? new Date(input.disbursedDate) : null,
      repaymentMonth: input.repaymentMonth ?? month,
      repaymentYear: input.repaymentYear ?? year,
      paymentMethod: input.paymentMethod ?? null,
      transactionCode: input.transactionCode ?? null,
      approvedAt: isCommitted ? new Date() : null,
      approvedById: isCommitted ? requesterId ?? null : null,
    },
  });
};

export const updateAdjustmentStatus = async (
  id,
  { status, notes },
  approverId,
) => {
  const data = { status };
  if (notes !== undefined) data.notes = notes;
  if (status === "APPROVED" || status === "DEDUCTED") {
    data.approvedAt = new Date();
    data.approvedById = approverId ?? null;
  } else if (status === "DECLINED" || status === "PENDING") {
    // Clear approval bookkeeping if the row gets reverted.
    data.approvedAt = null;
    data.approvedById = null;
  }
  return prisma.payrollAdjustment.update({ where: { id }, data });
};

export const deleteAdjustment = async (id) =>
  prisma.payrollAdjustment.delete({ where: { id } });

// POST /api/staff/payroll/process — persist computed rows + mark all PAID.
// Idempotent per (userId, month, year).
export const processPayroll = async ({ month, year } = {}) => {
  const summary = await getPayrollSummary({ month, year });
  const m = summary.month;
  const y = summary.year;

  await prisma.$transaction(
    summary.rows.map((r) =>
      prisma.payroll.upsert({
        where: {
          userId_month_year: { userId: r.userId, month: m, year: y },
        },
        create: {
          userId: r.userId,
          month: m,
          year: y,
          daysWorked: r.daysWorked,
          grossPay: r.grossPay,
          status: "PAID",
        },
        update: {
          daysWorked: r.daysWorked,
          grossPay: r.grossPay,
          status: "PAID",
        },
      }),
    ),
  );

  return getPayrollSummary({ month: m, year: y });
};

//////////////////////////////////////////////////////
// DASHBOARD
//////////////////////////////////////////////////////

// GET /api/staff/dashboard — composes everything the Staff & Labour page
// needs in one round-trip.
export const getDashboard = async () => {
  const [attendance, tasks, payroll] = await Promise.all([
    getTodayAttendance(),
    listTasksToday(),
    getPayrollSummary(),
  ]);

  const totalStaff = attendance.length;
  const presentToday = attendance.filter((a) => a.status === "PRESENT").length;
  const absentToday = attendance.filter((a) => a.status === "ABSENT").length;

  return {
    totalStaff,
    presentToday,
    absentToday,
    monthlyPayroll: Math.round(payroll.totalGross),
    attendance,
    tasks,
    payroll,
  };
};
