import * as staffService from "./staff.service.js";
import {
  createStaffSchema,
  updateStaffSchema,
  releaseStaffSchema,
  markAttendanceSchema,
  createTaskSchema,
  updateTaskSchema,
  reassignTaskSchema,
  workerAvailabilitySchema,
  payrollQuerySchema,
} from "./staff.validation.js";

const handleZodError = (res, err) => {
  if (err?.issues) {
    return res.status(400).json({
      error: "Validation error",
      issues: err.issues.map((i) => ({ path: i.path, message: i.message })),
    });
  }
  return null;
};

// ----- Staff CRUD -----

export const createStaff = async (req, res) => {
  try {
    const body = createStaffSchema.parse(req.body);
    const result = await staffService.createStaff(body);
    res.status(201).json(result);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(400).json({ error: err.message });
  }
};

export const listStaff = async (req, res) => {
  try {
    const includeInactive = req.query.includeInactive === "true";
    // ?status=ACTIVE | RELEASED | (absent = all when includeInactive=true)
    const status = ["ACTIVE", "RELEASED"].includes(req.query.status)
      ? req.query.status
      : null;
    res.json(await staffService.listStaff({ includeInactive, status }));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const getStaffById = async (req, res) => {
  try {
    res.json(await staffService.getStaffById(req.params.id));
  } catch (err) {
    res.status(404).json({ error: err.message });
  }
};

export const updateStaff = async (req, res) => {
  try {
    const patch = updateStaffSchema.parse(req.body);
    res.json(await staffService.updateStaff(req.params.id, patch, req.user?.id));
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "Staff not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

export const deleteStaff = async (req, res) => {
  try {
    await staffService.deactivateStaff(req.params.id, req.user?.id);
    res.status(204).end();
  } catch (err) {
    if (err.message === "Staff not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(500).json({ error: err.message });
  }
};

// POST /api/staff/:id/release
export const releaseStaff = async (req, res) => {
  try {
    const body = releaseStaffSchema.parse(req.body);
    const result = await staffService.releaseStaff(
      req.params.id,
      body,
      req.user?.id,
    );
    res.json(result);
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "Staff not found") {
      return res.status(404).json({ error: err.message });
    }
    if (err.message === "Staff is already released") {
      return res.status(409).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

// ----- Attendance -----

export const markAttendance = async (req, res) => {
  try {
    const body = markAttendanceSchema.parse(req.body);
    res.status(201).json(await staffService.markAttendance(body));
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(400).json({ error: err.message });
  }
};

export const checkIn = async (req, res) => {
  try {
    res.json(await staffService.checkIn({ userId: req.user.id }));
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

export const checkOut = async (req, res) => {
  try {
    res.json(await staffService.checkOut({ userId: req.user.id }));
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

export const getTodayAttendance = async (_req, res) => {
  try {
    res.json(await staffService.getTodayAttendance());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ----- Tasks -----

export const createTask = async (req, res) => {
  try {
    const body = createTaskSchema.parse(req.body);
    const task = await staffService.createTask(body, req.user.id);
    res.status(201).json(task);
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(400).json({ error: err.message });
  }
};

export const listTasksToday = async (_req, res) => {
  try {
    res.json(await staffService.listTasksToday());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const updateTask = async (req, res) => {
  try {
    const patch = updateTaskSchema.parse(req.body);
    res.json(await staffService.updateTask(req.params.id, patch));
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "Task not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

export const deleteTask = async (req, res) => {
  try {
    await staffService.deleteTask(req.params.id);
    res.status(204).end();
  } catch (err) {
    if (err.message === "Task not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(500).json({ error: err.message });
  }
};

export const reassignTask = async (req, res) => {
  try {
    const body = reassignTaskSchema.parse(req.body);
    const task = await staffService.reassignTask(
      req.params.id,
      body,
      req.user?.id,
    );
    res.json(task);
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (
      err.message === "Task not found" ||
      err.message === "Replacement staff not found"
    ) {
      return res.status(404).json({ error: err.message });
    }
    if (err.message === "Task is already assigned to this user") {
      return res.status(409).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

export const setWorkerAvailability = async (req, res) => {
  try {
    const body = workerAvailabilitySchema.parse(req.body);
    const worker = await staffService.setWorkerAvailability(
      req.params.id,
      body,
    );
    res.json(worker);
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "Worker not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

// ----- Payroll -----

export const getPayroll = async (req, res) => {
  try {
    const query = payrollQuerySchema.parse(req.query);
    res.json(await staffService.getPayrollSummary(query));
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(500).json({ error: err.message });
  }
};

export const processPayroll = async (req, res) => {
  try {
    const query = payrollQuerySchema.parse(req.body ?? {});
    res.json(await staffService.processPayroll(query));
  } catch (err) {
    if (handleZodError(res, err)) return;
    res.status(500).json({ error: err.message });
  }
};

// ----- Dashboard -----

export const getDashboard = async (_req, res) => {
  try {
    res.json(await staffService.getDashboard());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// ----- Payroll adjustments (advances / bonuses / penalties / overtime) -----

export const listAdjustments = async (req, res) => {
  try {
    const { userId, status } = req.query;
    const month = req.query.month ? Number(req.query.month) : undefined;
    const year = req.query.year ? Number(req.query.year) : undefined;
    res.json(
      await staffService.listAdjustments({ userId, month, year, status }),
    );
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const createAdjustment = async (req, res) => {
  try {
    const body = req.body ?? {};
    if (!body.userId) {
      return res.status(400).json({ error: "userId is required" });
    }
    if (typeof body.amount !== "number" || body.amount <= 0) {
      return res.status(400).json({ error: "amount must be > 0" });
    }
    const row = await staffService.createAdjustment(body, req.user?.id);
    res.status(201).json(row);
  } catch (err) {
    if (err.code === "VALIDATION") {
      return res.status(400).json({ error: err.message });
    }
    res.status(500).json({ error: err.message });
  }
};

export const updateAdjustment = async (req, res) => {
  try {
    const allowed = ["PENDING", "APPROVED", "DEDUCTED", "DECLINED"];
    const { status, notes } = req.body ?? {};
    if (status && !allowed.includes(status)) {
      return res.status(400).json({ error: `status must be one of ${allowed.join(", ")}` });
    }
    const row = await staffService.updateAdjustmentStatus(
      req.params.id,
      { status, notes },
      req.user?.id,
    );
    res.json(row);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const deleteAdjustment = async (req, res) => {
  try {
    await staffService.deleteAdjustment(req.params.id);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
