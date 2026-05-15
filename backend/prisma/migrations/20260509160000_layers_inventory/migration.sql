-- Layers unit inventory — feed / vaccines / consumables. Powers the
-- "📦 Inventory" pill on the Layers Unit page.
CREATE TABLE "LayersInventoryItem" (
  "id"           TEXT NOT NULL,
  "name"         TEXT NOT NULL,
  "category"     TEXT NOT NULL,
  "subCategory"  TEXT,
  "quantity"     DOUBLE PRECISION NOT NULL,
  "unit"         TEXT,
  "lowThreshold" DOUBLE PRECISION,
  "location"     TEXT,
  "condition"    TEXT,
  "expiresAt"    TIMESTAMP(3),
  "notes"        TEXT,
  "deletedAt"    TIMESTAMP(3),
  "createdAt"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"    TIMESTAMP(3) NOT NULL,

  CONSTRAINT "LayersInventoryItem_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "LayersInventoryItem_category_idx"  ON "LayersInventoryItem"("category");
CREATE INDEX "LayersInventoryItem_deletedAt_idx" ON "LayersInventoryItem"("deletedAt");
CREATE INDEX "LayersInventoryItem_expiresAt_idx" ON "LayersInventoryItem"("expiresAt");
