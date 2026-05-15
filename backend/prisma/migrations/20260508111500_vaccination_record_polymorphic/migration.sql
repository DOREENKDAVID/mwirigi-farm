-- VaccinationRecord becomes polymorphic: it now holds both cross-unit
-- (annual/recurring, via protocolId) AND brooder/chick events (via
-- brooderId + vaccineName + dayOffset). Brooder events used to live in
-- BrooderVaccination; that table is now legacy.

-- DropForeignKey to relax the NOT NULL on protocolId.
ALTER TABLE "VaccinationRecord" DROP CONSTRAINT "VaccinationRecord_protocolId_fkey";

-- Make protocolId nullable so brooder events can omit it.
ALTER TABLE "VaccinationRecord" ALTER COLUMN "protocolId" DROP NOT NULL;

-- New brooder-shape columns.
ALTER TABLE "VaccinationRecord" ADD COLUMN "brooderId" TEXT;
ALTER TABLE "VaccinationRecord" ADD COLUMN "vaccineName" TEXT;
ALTER TABLE "VaccinationRecord" ADD COLUMN "dayOffset" INTEGER;

-- Re-add the protocol FK as nullable.
ALTER TABLE "VaccinationRecord"
    ADD CONSTRAINT "VaccinationRecord_protocolId_fkey"
    FOREIGN KEY ("protocolId") REFERENCES "VaccineProtocol"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Brooder FK. Cascade so deleting a brooder removes its vaccination
-- history too (matches the existing BrooderVaccination relation).
ALTER TABLE "VaccinationRecord"
    ADD CONSTRAINT "VaccinationRecord_brooderId_fkey"
    FOREIGN KEY ("brooderId") REFERENCES "Brooder"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Idempotency guard for brooder events. Postgres treats NULL != NULL,
-- so cross-unit rows (both columns NULL) are unaffected.
CREATE UNIQUE INDEX "VaccinationRecord_brooderId_dayOffset_key"
    ON "VaccinationRecord"("brooderId", "dayOffset");

-- Reads filter by brooderId, so index it.
CREATE INDEX "VaccinationRecord_brooderId_idx"
    ON "VaccinationRecord"("brooderId");
