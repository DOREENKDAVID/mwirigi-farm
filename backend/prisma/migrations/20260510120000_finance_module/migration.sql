-- Finance module — revenue, expenses, budgets per farm unit. CEO-level
-- consolidated dashboard reads from these tables.

CREATE TYPE "FinanceUnit" AS ENUM (
  'Dairy', 'Layers', 'Piggery', 'Ngushish', 'Feedlot', 'Doopers', 'Other'
);

CREATE TYPE "RevenueCategory" AS ENUM (
  'MILK_SALES', 'EGG_SALES', 'PIG_SALES', 'CROP_SALES',
  'FEED_SALES', 'ANIMAL_SALES', 'EQUIPMENT_SALES', 'OTHER_INCOME'
);

CREATE TYPE "ExpenseCategory" AS ENUM (
  'FEEDS', 'LABOUR', 'VACCINES', 'UTILITIES', 'FUEL',
  'TRANSPORT', 'MAINTENANCE', 'FARM_INPUTS', 'SALARIES',
  'EQUIPMENT', 'MISC'
);

CREATE TYPE "PaymentMethod" AS ENUM (
  'CASH', 'MPESA', 'BANK_TRANSFER', 'CHEQUE', 'CARD'
);

CREATE TABLE "Revenue" (
  "id"          TEXT NOT NULL,
  "unit"        "FinanceUnit" NOT NULL,
  "category"    "RevenueCategory" NOT NULL,
  "amount"      DOUBLE PRECISION NOT NULL,
  "quantity"    DOUBLE PRECISION,
  "unitLabel"   TEXT,
  "date"        TIMESTAMP(3) NOT NULL,
  "notes"       TEXT,
  "createdById" TEXT,
  "createdAt"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"   TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Revenue_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "Revenue_unit_idx"     ON "Revenue"("unit");
CREATE INDEX "Revenue_date_idx"     ON "Revenue"("date");
CREATE INDEX "Revenue_category_idx" ON "Revenue"("category");
ALTER TABLE "Revenue" ADD CONSTRAINT "Revenue_createdById_fkey"
  FOREIGN KEY ("createdById") REFERENCES "User"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "Expense" (
  "id"            TEXT NOT NULL,
  "unit"          "FinanceUnit" NOT NULL,
  "category"      "ExpenseCategory" NOT NULL,
  "amount"        DOUBLE PRECISION NOT NULL,
  "vendor"        TEXT,
  "paymentMethod" "PaymentMethod",
  "receiptUrl"    TEXT,
  "approved"      BOOLEAN NOT NULL DEFAULT true,
  "date"          TIMESTAMP(3) NOT NULL,
  "notes"         TEXT,
  "createdById"   TEXT,
  "createdAt"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"     TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Expense_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "Expense_unit_idx"     ON "Expense"("unit");
CREATE INDEX "Expense_date_idx"     ON "Expense"("date");
CREATE INDEX "Expense_category_idx" ON "Expense"("category");
CREATE INDEX "Expense_approved_idx" ON "Expense"("approved");
ALTER TABLE "Expense" ADD CONSTRAINT "Expense_createdById_fkey"
  FOREIGN KEY ("createdById") REFERENCES "User"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "Budget" (
  "id"              TEXT NOT NULL,
  "unit"            "FinanceUnit" NOT NULL,
  "allocatedAmount" DOUBLE PRECISION NOT NULL,
  "month"           INTEGER NOT NULL,
  "year"            INTEGER NOT NULL,
  "notes"           TEXT,
  "createdAt"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"       TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Budget_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "Budget_unit_month_year_key" ON "Budget"("unit", "month", "year");
CREATE INDEX "Budget_year_month_idx" ON "Budget"("year", "month");
