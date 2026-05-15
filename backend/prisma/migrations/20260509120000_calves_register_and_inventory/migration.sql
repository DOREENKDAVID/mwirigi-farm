-- Extend ReproductionRecord with calving detail fields used by the
-- Calves register pill on the Dairy page.
ALTER TABLE "ReproductionRecord"
  ADD COLUMN "calfSex"           TEXT,
  ADD COLUMN "calfBirthWeightKg" DOUBLE PRECISION,
  ADD COLUMN "calvingEase"       INTEGER,
  ADD COLUMN "calvingFate"       TEXT;

-- New DairyInventoryItem table — bedding / equipment / veterinary supplies.
CREATE TABLE "DairyInventoryItem" (
  "id"        TEXT NOT NULL,
  "name"      TEXT NOT NULL,
  "category"  TEXT NOT NULL,
  "quantity"  DOUBLE PRECISION NOT NULL,
  "unit"      TEXT,
  "location"  TEXT,
  "condition" TEXT,
  "notes"     TEXT,
  "deletedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "DairyInventoryItem_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "DairyInventoryItem_category_idx"  ON "DairyInventoryItem"("category");
CREATE INDEX "DairyInventoryItem_deletedAt_idx" ON "DairyInventoryItem"("deletedAt");
