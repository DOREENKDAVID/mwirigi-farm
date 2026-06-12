import { z } from "zod";

export const createSaleSchema = z.object({
  module: z.enum(["DAIRY", "LAYERS"]),
  saleDate: z.coerce.date().optional(), // defaults to now() server-side
  quantity: z.number().positive("quantity must be positive"),
  buyerType: z.enum([
    "SCHOOL",
    "INDIVIDUAL",
    "ORGANIZATION",
    "HOTEL",
    "DISTRIBUTOR",
    "OTHER",
  ]),
  buyerName: z.string().min(1).max(200),
  paymentMode: z.enum([
    "CASH",
    "MPESA",
    "BANK_TRANSFER",
    "CREDIT",
    "CHEQUE",
    "CARD",
  ]),
  paymentReference: z.string().max(200).optional(),
  amountPaid: z.number().nonnegative(),
  notes: z.string().max(2000).optional(),
});

export const updateSaleSchema = createSaleSchema.partial().omit({ module: true });

export const listSalesSchema = z.object({
  module: z.enum(["DAIRY", "LAYERS"]).optional(),
  buyerType: z
    .enum(["SCHOOL", "INDIVIDUAL", "ORGANIZATION", "HOTEL", "DISTRIBUTOR", "OTHER"])
    .optional(),
  paymentMode: z
    .enum(["CASH", "MPESA", "BANK_TRANSFER", "CREDIT", "CHEQUE", "CARD"])
    .optional(),
  startDate: z.coerce.date().optional(),
  endDate: z.coerce.date().optional(),
  limit: z.coerce.number().int().positive().max(200).optional().default(50),
  offset: z.coerce.number().int().nonnegative().optional().default(0),
});
