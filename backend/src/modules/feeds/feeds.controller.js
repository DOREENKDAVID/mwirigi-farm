import * as service from "./feeds.service.js";
import {
  createMaterialSchema,
  updateMaterialSchema,
  listMaterialsQuerySchema,
  createDeliverySchema,
  listDeliveriesQuerySchema,
  createConsumptionSchema,
  createBulkConsumptionSchema,
  updateBulkFeedSchema,
  createDistributionSchema,
  idParamSchema,
} from "./feeds.validation.js";

// Standard {success, message, data} envelope shared across the module.
const ok = (res, data, message = "OK", status = 200) =>
  res.status(status).json({ success: true, message, data });

const fail = (res, message, status = 400, extra = {}) =>
  res.status(status).json({ success: false, message, ...extra });

const handleZodError = (res, err) => {
  if (err?.issues) {
    fail(res, "Validation error", 400, {
      issues: err.issues.map((i) => ({ path: i.path, message: i.message })),
    });
    return true;
  }
  return false;
};

const handleServiceError = (res, err) => {
  const msg = err?.message ?? "Internal server error";
  // Prefix match also catches the bulk service's "Material not found: <id>".
  if (msg.startsWith("Material not found") || msg === "Bulk feed entry not found") {
    return fail(res, msg, 404);
  }
  if (msg === "Material with this name already exists") {
    return fail(res, msg, 409);
  }
  return fail(res, msg, 500);
};

//////////////////////////////////////////////////////
// MATERIALS
//////////////////////////////////////////////////////

export const listMaterials = async (req, res) => {
  try {
    const query = listMaterialsQuerySchema.parse(req.query);
    const data = await service.listMaterials(query);
    return ok(res, data, "Materials fetched successfully");
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

export const getMaterialById = async (req, res) => {
  try {
    const { id } = idParamSchema.parse(req.params);
    const m = await service.getMaterialById(id);
    return ok(res, m, "Material fetched successfully");
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

export const createMaterial = async (req, res) => {
  try {
    const body = createMaterialSchema.parse(req.body);
    const m = await service.createMaterial(body);
    return ok(res, m, "Material created successfully", 201);
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

export const updateMaterial = async (req, res) => {
  try {
    const { id } = idParamSchema.parse(req.params);
    const patch = updateMaterialSchema.parse(req.body);
    const m = await service.updateMaterial(id, patch);
    return ok(res, m, "Material updated successfully");
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

export const deleteMaterial = async (req, res) => {
  try {
    const { id } = idParamSchema.parse(req.params);
    await service.softDeleteMaterial(id);
    return ok(res, null, "Material deleted successfully");
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

//////////////////////////////////////////////////////
// DELIVERIES
//////////////////////////////////////////////////////

export const createDelivery = async (req, res) => {
  try {
    const body = createDeliverySchema.parse(req.body);
    const userId = req.user?.id ?? null;
    const delivery = await service.createDelivery(body, userId);
    return ok(res, delivery, "Delivery logged successfully", 201);
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

export const listDeliveries = async (req, res) => {
  try {
    const query = listDeliveriesQuerySchema.parse(req.query);
    const data = await service.listDeliveries(query);
    return ok(res, data, "Deliveries fetched successfully");
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

//////////////////////////////////////////////////////
// CONSUMPTION
//////////////////////////////////////////////////////

export const createConsumption = async (req, res) => {
  try {
    const body = createConsumptionSchema.parse(req.body);
    const userId = req.user?.id ?? null;
    const log = await service.createConsumptionLog(body, userId);
    return ok(res, log, "Consumption rate updated successfully", 201);
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

export const createBulkConsumption = async (req, res) => {
  try {
    const body = createBulkConsumptionSchema.parse(req.body);
    const userId = req.user?.id ?? null;
    const logs = await service.createBulkConsumptionLogs(
      body.entries,
      userId,
    );
    return ok(
      res,
      { count: logs.length, logs },
      "Consumption rates updated successfully",
      201,
    );
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

//////////////////////////////////////////////////////
// BULK FEED
//////////////////////////////////////////////////////

export const listBulkFeed = async (_req, res) => {
  try {
    const data = await service.listBulkFeed();
    return ok(res, data, "Bulk feed fetched successfully");
  } catch (err) {
    return handleServiceError(res, err);
  }
};

export const updateBulkFeed = async (req, res) => {
  try {
    const { id } = idParamSchema.parse(req.params);
    const patch = updateBulkFeedSchema.parse(req.body);
    const data = await service.updateBulkFeed(id, patch);
    return ok(res, data, "Bulk feed updated successfully");
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

//////////////////////////////////////////////////////
// DISTRIBUTION
//////////////////////////////////////////////////////

export const listDistribution = async (_req, res) => {
  try {
    const data = await service.listDistribution();
    return ok(res, data, "Distribution fetched successfully");
  } catch (err) {
    return handleServiceError(res, err);
  }
};

export const upsertDistribution = async (req, res) => {
  try {
    const body = createDistributionSchema.parse(req.body);
    const data = await service.upsertDistribution(body);
    return ok(res, data, "Distribution recorded successfully", 201);
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

//////////////////////////////////////////////////////
// DASHBOARD
//////////////////////////////////////////////////////

export const getDashboard = async (_req, res) => {
  try {
    const data = await service.getDashboardKpis();
    return ok(res, data, "Dashboard KPIs fetched successfully");
  } catch (err) {
    return handleServiceError(res, err);
  }
};
