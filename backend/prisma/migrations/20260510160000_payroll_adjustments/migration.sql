-- Payroll adjustments — advances, bonuses, penalties, overtime.
-- Powers the Advance pill UI on the Payroll table.

CREATE TYPE "PayrollAdjustmentType" AS ENUM (
  'ADVANCE', 'BONUS', 'PENALTY', 'OVERTIME'
);

CREATE TYPE "PayrollAdjustmentStatus" AS ENUM (
  'PENDING', 'APPROVED', 'DEDUCTED', 'DECLINED'
);

CREATE TABLE "PayrollAdjustment" (
  "id"           TEXT NOT NULL,
  "userId"       TEXT NOT NULL,
  "type"         "PayrollAdjustmentType"   NOT NULL,
  "status"       "PayrollAdjustmentStatus" NOT NULL DEFAULT 'PENDING',
  "amount"       DOUBLE PRECISION NOT NULL,
  "month"        INTEGER NOT NULL,
  "year"         INTEGER NOT NULL,
  "reason"       TEXT,
  "notes"        TEXT,
  "requestedAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "approvedAt"   TIMESTAMP(3),
  "approvedById" TEXT,
  "createdAt"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"    TIMESTAMP(3) NOT NULL,
  CONSTRAINT "PayrollAdjustment_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "PayrollAdjustment_userId_idx"     ON "PayrollAdjustment"("userId");
CREATE INDEX "PayrollAdjustment_status_idx"     ON "PayrollAdjustment"("status");
CREATE INDEX "PayrollAdjustment_year_month_idx" ON "PayrollAdjustment"("year", "month");
CREATE INDEX "PayrollAdjustment_type_idx"       ON "PayrollAdjustment"("type");

ALTER TABLE "PayrollAdjustment" ADD CONSTRAINT "PayrollAdjustment_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PayrollAdjustment" ADD CONSTRAINT "PayrollAdjustment_approvedById_fkey"
  FOREIGN KEY ("approvedById") REFERENCES "User"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
