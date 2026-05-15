-- Feedlot inventory — bedding / equipment / veterinary / feed. Mirrors
-- DairyInventoryItem so the frontend card can reuse the same pattern.
CREATE TABLE "FeedlotInventoryItem" (
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

  CONSTRAINT "FeedlotInventoryItem_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "FeedlotInventoryItem_category_idx"  ON "FeedlotInventoryItem"("category");
CREATE INDEX "FeedlotInventoryItem_deletedAt_idx" ON "FeedlotInventoryItem"("deletedAt");
