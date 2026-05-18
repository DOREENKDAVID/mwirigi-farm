-- Farmers Choice dispatch log. Stand-alone table — no FK into FattenPen
-- because the operational record is the truck-load that left, not the
-- exact DB pen rows that existed at the moment of dispatch. `revenueId`
-- is optional so the finance ledger can be reconciled to a delivery.

CREATE TABLE "FarmersChoiceDelivery" (
    "id"           TEXT NOT NULL,
    "date"         TIMESTAMP(3) NOT NULL,
    "ref"          TEXT NOT NULL,
    "pens"         TEXT NOT NULL,
    "count"        INTEGER NOT NULL,
    "category"     TEXT NOT NULL,
    "ageRange"     TEXT,
    "driver"       TEXT NOT NULL,
    "notes"        TEXT,
    "revenueId"    TEXT,
    "recordedById" TEXT,
    "deletedAt"    TIMESTAMP(3),
    "createdAt"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt"    TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FarmersChoiceDelivery_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "FarmersChoiceDelivery_revenueId_key"
    ON "FarmersChoiceDelivery"("revenueId");
CREATE INDEX "FarmersChoiceDelivery_date_idx"
    ON "FarmersChoiceDelivery"("date");
CREATE INDEX "FarmersChoiceDelivery_deletedAt_idx"
    ON "FarmersChoiceDelivery"("deletedAt");
