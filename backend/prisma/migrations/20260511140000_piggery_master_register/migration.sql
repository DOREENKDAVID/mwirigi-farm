-- Piggery master register expansion (Rev 2 schema).
-- Adds location/breeding fields to Pig, plus Litter / NurseryGroup /
-- FattenPen / PiggeryInventoryItem tables. Also extends PigStatus enum
-- with DRY + SERVICE values used by the master register.

ALTER TYPE "PigStatus" ADD VALUE IF NOT EXISTS 'DRY';
ALTER TYPE "PigStatus" ADD VALUE IF NOT EXISTS 'SERVICE';

ALTER TABLE "Pig"
  ADD COLUMN IF NOT EXISTS "house"       TEXT,
  ADD COLUMN IF NOT EXISTS "pen"         TEXT,
  ADD COLUMN IF NOT EXISTS "serviceDate" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "expFarrow"   TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "breed"       TEXT,
  ADD COLUMN IF NOT EXISTS "age"         TEXT,
  ADD COLUMN IF NOT EXISTS "role"        TEXT,
  ADD COLUMN IF NOT EXISTS "note"        TEXT;

CREATE INDEX IF NOT EXISTS "Pig_house_idx" ON "Pig"("house");

ALTER TABLE "FarrowingRecord"
  ADD COLUMN IF NOT EXISTS "winners"    INTEGER,
  ADD COLUMN IF NOT EXISTS "fatteners"  INTEGER,
  ADD COLUMN IF NOT EXISTS "beaconners" INTEGER,
  ADD COLUMN IF NOT EXISTS "remarks"    TEXT,
  ADD COLUMN IF NOT EXISTS "service"    TIMESTAMP(3);

CREATE TABLE IF NOT EXISTS "Litter" (
  "id"        TEXT NOT NULL,
  "litterId"  TEXT NOT NULL,
  "born"      TIMESTAMP(3),
  "count"     INTEGER NOT NULL DEFAULT 0,
  "note"      TEXT,
  "sowId"     TEXT NOT NULL,
  "deletedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Litter_pkey"        PRIMARY KEY ("id"),
  CONSTRAINT "Litter_litterId_key" UNIQUE ("litterId"),
  CONSTRAINT "Litter_sow_fk"      FOREIGN KEY ("sowId") REFERENCES "Pig"("id") ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS "Litter_sowId_idx"     ON "Litter"("sowId");
CREATE INDEX IF NOT EXISTS "Litter_deletedAt_idx" ON "Litter"("deletedAt");

CREATE TABLE IF NOT EXISTS "NurseryGroup" (
  "id"        TEXT NOT NULL,
  "pen"       TEXT NOT NULL,
  "count"     INTEGER NOT NULL,
  "age"       TEXT,
  "born"      TIMESTAMP(3),
  "breed"     TEXT,
  "note"      TEXT,
  "deletedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "NurseryGroup_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "NurseryGroup_deletedAt_idx" ON "NurseryGroup"("deletedAt");

CREATE TABLE IF NOT EXISTS "FattenPen" (
  "id"         TEXT NOT NULL,
  "pen"        TEXT NOT NULL,
  "house"      TEXT NOT NULL,
  "count"      INTEGER NOT NULL,
  "age"        TEXT,
  "saleReady"  BOOLEAN NOT NULL DEFAULT false,
  "saleWindow" TEXT,
  "deletedAt"  TIMESTAMP(3),
  "createdAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"  TIMESTAMP(3) NOT NULL,
  CONSTRAINT "FattenPen_pkey"    PRIMARY KEY ("id"),
  CONSTRAINT "FattenPen_pen_key" UNIQUE ("pen")
);
CREATE INDEX IF NOT EXISTS "FattenPen_house_idx"     ON "FattenPen"("house");
CREATE INDEX IF NOT EXISTS "FattenPen_deletedAt_idx" ON "FattenPen"("deletedAt");

CREATE TABLE IF NOT EXISTS "PiggeryInventoryItem" (
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
  CONSTRAINT "PiggeryInventoryItem_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "PiggeryInventoryItem_category_idx"  ON "PiggeryInventoryItem"("category");
CREATE INDEX IF NOT EXISTS "PiggeryInventoryItem_deletedAt_idx" ON "PiggeryInventoryItem"("deletedAt");
