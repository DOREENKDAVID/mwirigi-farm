import { z } from "zod";

const FINANCE_UNITS = [
  "Dairy", "Layers", "Piggery", "Ngushish", "Feedlot", "Doopers", "Other",
];

const REVENUE_CATEGORIES = [
  "MILK_SALES", "EGG_SALES", "PIG_SALES", "CROP_SALES",
  "FEED_SALES", "ANIMAL_SALES", "EQUIPMENT_SALES", "OTHER_INCOME",
];

const EXPENSE_CATEGORIES = [
  "FEEDS", "LABOUR", "VACCINES", "UTILITIES", "FUEL",
  "TRANSPORT", "MAINTENANCE", "FARM_INPUTS", "SALARIES",
  "EQUIPMENT", "MISC",
];

const PAYMENT_METHODS = ["CASH", "MPESA", "BANK_TRANSFER", "CHEQUE", "CARD"];

export const revenueSchema = z.object({
  unit: z.enum(FINANCE_UNITS),
  category: z.enum(REVENUE_CATEGORIES),
  amount: z.number().positive("Amount must be greater than zero"),
  quantity: z.number().nonnegative().nullable().optional(),
  unitLabel: z.string().trim().max(40).nullable().optional(),
  date: z.coerce.date().optional(),
  notes: z.string().trim().max(500).nullable().optional(),
});

export const expenseSchema = z.object({
  unit: z.enum(FINANCE_UNITS),
  category: z.enum(EXPENSE_CATEGORIES),
  amount: z.number().positive("Amount must be greater than zero"),
  vendor: z.string().trim().max(120).nullable().optional(),
  paymentMethod: z.enum(PAYMENT_METHODS).nullable().optional(),
  receiptUrl: z.string().trim().max(400).nullable().optional(),
  approved: z.boolean().optional(),
  date: z.coerce.date().optional(),
  notes: z.string().trim().max(500).nullable().optional(),
});
