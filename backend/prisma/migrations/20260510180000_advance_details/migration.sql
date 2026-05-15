-- Salary advance reference + workflow dates.

CREATE TYPE "AdvancePaymentMethod" AS ENUM ('CASH', 'MPESA', 'BANK_TRANSFER');

ALTER TABLE "PayrollAdjustment"
  ADD COLUMN "referenceNo"     TEXT,
  ADD COLUMN "requestDate"     TIMESTAMP(3),
  ADD COLUMN "approvedDate"    TIMESTAMP(3),
  ADD COLUMN "disbursedDate"   TIMESTAMP(3),
  ADD COLUMN "repaymentMonth"  INTEGER,
  ADD COLUMN "repaymentYear"   INTEGER,
  ADD COLUMN "paymentMethod"   "AdvancePaymentMethod",
  ADD COLUMN "transactionCode" TEXT;

CREATE UNIQUE INDEX "PayrollAdjustment_referenceNo_key" ON "PayrollAdjustment"("referenceNo");
CREATE INDEX        "PayrollAdjustment_referenceNo_idx" ON "PayrollAdjustment"("referenceNo");
