import * as service from "./ngushish.service.js";
import {
  createCropSchema,
  updateCropSchema,
  listCropsQuerySchema,
  createHarvestSchema,
  listHarvestsQuerySchema,
  createDispatchSchema,
  listDispatchesQuerySchema,
  createIrrigationSchema,
  listIrrigationQuerySchema,
  idParamSchema,
} from "./ngushish.validation.js";

// Standard response envelope used across all ngushish endpoints. Keeps the
// shape consistent with the spec ({ success, message, data } / { success,
// message }).
const ok = (res, data, message = "OK", status = 200) =>
  res.status(status).json({ success: true, message, data });

const fail = (res, message, status = 400, extra = {}) =>
  res.status(status).json({ success: false, message, ...extra });

// Zod errors get mapped to a 400 with a flat issues list. Returns true if
// it handled the error so the caller can early-return.
const handleZodError = (res, err) => {
  if (err?.issues) {
    fail(res, "Validation error", 400, {
      issues: err.issues.map((i) => ({ path: i.path, message: i.message })),
    });
    return true;
  }
  return false;
};

// "Crop not found" is the only domain error any service path throws — map
// it to 404, everything else to 500.
const handleServiceError = (res, err) => {
  if (err?.message === "Crop not found") return fail(res, err.message, 404);
  return fail(res, err.message ?? "Internal server error", 500);
};

//////////////////////////////////////////////////////
// CROPS
//////////////////////////////////////////////////////

export const listCrops = async (req, res) => {
  try {
    const query = listCropsQuerySchema.parse(req.query);
    const data = await service.listCrops(query);
    return ok(res, data, "Crops fetched successfully");
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

export const getCropById = async (req, res) => {
  try {
    const { id } = idParamSchema.parse(req.params);
    const crop = await service.getCropById(id);
    return ok(res, crop, "Crop fetched successfully");
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

export const createCrop = async (req, res) => {
  try {
    const body = createCropSchema.parse(req.body);
    const crop = await service.createCrop(body);
    return ok(res, crop, "Crop created successfully", 201);
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

export const updateCrop = async (req, res) => {
  try {
    const { id } = idParamSchema.parse(req.params);
    const patch = updateCropSchema.parse(req.body);
    const crop = await service.updateCrop(id, patch);
    return ok(res, crop, "Crop updated successfully");
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

export const deleteCrop = async (req, res) => {
  try {
    const { id } = idParamSchema.parse(req.params);
    await service.softDeleteCrop(id);
    return ok(res, null, "Crop deleted successfully");
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

//////////////////////////////////////////////////////
// HARVESTS
//////////////////////////////////////////////////////

export const createHarvest = async (req, res) => {
  try {
    const body = createHarvestSchema.parse(req.body);
    const harvest = await service.createHarvest(body);
    return ok(res, harvest, "Harvest recorded successfully", 201);
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

export const listHarvests = async (req, res) => {
  try {
    const query = listHarvestsQuerySchema.parse(req.query);
    const data = await service.listHarvests(query);
    return ok(res, data, "Harvests fetched successfully");
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

//////////////////////////////////////////////////////
// DISPATCHES
//////////////////////////////////////////////////////

export const createDispatch = async (req, res) => {
  try {
    const body = createDispatchSchema.parse(req.body);
    const dispatch = await service.createDispatch(body);
    return ok(res, dispatch, "Dispatch recorded successfully", 201);
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

export const listDispatches = async (req, res) => {
  try {
    const query = listDispatchesQuerySchema.parse(req.query);
    const data = await service.listDispatches(query);
    return ok(res, data, "Dispatches fetched successfully");
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

//////////////////////////////////////////////////////
// IRRIGATION
//////////////////////////////////////////////////////

export const createIrrigation = async (req, res) => {
  try {
    const body = createIrrigationSchema.parse(req.body);
    const log = await service.createIrrigationLog(body);
    return ok(res, log, "Irrigation event recorded successfully", 201);
  } catch (err) {
    if (handleZodError(res, err)) return;
    return handleServiceError(res, err);
  }
};

export const listIrrigation = async (req, res) => {
  try {
    const query = listIrrigationQuerySchema.parse(req.query);
    const data = await service.listIrrigation(query);
    return ok(res, data, "Irrigation logs fetched successfully");
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

//////////////////////////////////////////////////////
// INVENTORY
//////////////////////////////////////////////////////

export const listInventory = async (_req, res) => {
  try {
    const data = await service.listNgushishInventory();
    return ok(res, data, "Inventory fetched successfully");
  } catch (err) {
    return handleServiceError(res, err);
  }
};

export const createInventory = async (req, res) => {
  try {
    const body = req.body ?? {};
    if (!body.name || typeof body.name !== "string") {
      return fail(res, "name is required", 400);
    }
    if (!body.category) {
      return fail(res, "category is required", 400);
    }
    if (typeof body.quantity !== "number" || body.quantity < 0) {
      return fail(res, "quantity must be >= 0", 400);
    }
    const row = await service.createNgushishInventoryItem(body);
    return ok(res, row, "Inventory item created", 201);
  } catch (err) {
    return handleServiceError(res, err);
  }
};

export const updateInventory = async (req, res) => {
  try {
    const row = await service.updateNgushishInventoryItem(
      req.params.id,
      req.body ?? {},
    );
    return ok(res, row, "Inventory item updated");
  } catch (err) {
    return handleServiceError(res, err);
  }
};

export const deleteInventory = async (req, res) => {
  try {
    await service.softDeleteNgushishInventoryItem(req.params.id);
    return ok(res, null, "Inventory item deleted");
  } catch (err) {
    return handleServiceError(res, err);
  }
};
