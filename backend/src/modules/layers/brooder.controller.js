import { z } from "zod";
import * as service from "./brooder.service.js";
import { listAuditLogs } from "../../utils/audit.js";

const OCCURRENCE_TYPES = [
  "MORTALITY",
  "DISEASE",
  "TEMPERATURE_ISSUE",
  "FEED_ISSUE",
  "WATER_ISSUE",
  "EQUIPMENT_FAILURE",
  "VACCINATION",
  "THEFT",
  "OTHER",
];

const SEVERITY = ["LOW", "MEDIUM", "HIGH", "CRITICAL"];

const occurrenceSchema = z.object({
  brooderId: z.string().uuid("Invalid brooderId"),
  type: z.enum(OCCURRENCE_TYPES),
  severity: z.enum(SEVERITY).optional(),
  occurredAt: z.coerce.date().optional(),
  numberAffected: z.number().int().min(0).max(100000).optional(),
  description: z.string().trim().max(4000).nullable().optional(),
  actionTaken: z.string().trim().max(4000).nullable().optional(),
  imageUrl: z.string().trim().max(500).nullable().optional(),
  followUpNeeded: z.boolean().optional(),
});

const handleZodError = (res, err) => {
  if (err?.issues) {
    return res.status(400).json({
      error: "Validation error",
      issues: err.issues.map((i) => ({ path: i.path, message: i.message })),
    });
  }
  return null;
};

export const logOccurrence = async (req, res) => {
  try {
    const body = occurrenceSchema.parse(req.body);
    const row = await service.logOccurrence(body, req.user?.id);
    res.status(201).json(row);
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "Brooder not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

export const listOccurrences = async (req, res) => {
  try {
    const brooderId = req.query.brooderId;
    if (typeof brooderId !== "string" || !brooderId) {
      return res.status(400).json({ error: "brooderId query is required" });
    }
    res.json(await service.listOccurrencesForBrooder(brooderId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

const ALLOCATION_TYPES = ["POL_SALE", "REPLACEMENT"];

const allocationSchema = z.object({
  brooderId: z.string().uuid("Invalid brooderId"),
  type: z.enum(ALLOCATION_TYPES),
  birds: z.number().int().positive().max(1_000_000),
  description: z.string().trim().min(1).max(400),
  reason: z.string().trim().max(2000).nullable().optional(),
});

export const createAllocation = async (req, res) => {
  try {
    const body = allocationSchema.parse(req.body);
    const plan = await service.createAllocationPlan(body, req.user?.id);
    res.status(201).json(plan);
  } catch (err) {
    if (handleZodError(res, err)) return;
    if (err.message === "Brooder not found") {
      return res.status(404).json({ error: err.message });
    }
    res.status(400).json({ error: err.message });
  }
};

export const allocationHistory = async (req, res) => {
  try {
    const brooderId = req.query.brooderId;
    if (typeof brooderId !== "string" || !brooderId) {
      return res.status(400).json({ error: "brooderId query is required" });
    }
    const logs = await listAuditLogs({
      entity: "AllocationPlan",
      entityId: brooderId,
      limit: 100,
    });
    res.json(logs);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const weeklyReport = async (req, res) => {
  try {
    const brooderId = req.query.brooderId;
    if (typeof brooderId !== "string" || !brooderId) {
      return res.status(400).json({ error: "brooderId query is required" });
    }
    res.json(await service.weeklyOccurrenceReport(brooderId));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
