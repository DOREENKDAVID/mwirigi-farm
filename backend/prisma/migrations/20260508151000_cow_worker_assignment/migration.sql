-- Cow.workerId: explicit per-cow worker assignment. Cows may now span
-- houses (one worker can supervise cows in multiple houses). The legacy
-- House.worker 1:1 stays in place as a supervision default; operational
-- workflows (milk logging, manager view, worker pills) consult the
-- direct Cow.workerId link instead.

ALTER TABLE "Cow" ADD COLUMN "workerId" TEXT;

ALTER TABLE "Cow"
    ADD CONSTRAINT "Cow_workerId_fkey"
    FOREIGN KEY ("workerId") REFERENCES "Worker"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "Cow_workerId_idx" ON "Cow"("workerId");
CREATE INDEX "Cow_houseId_idx" ON "Cow"("houseId");

-- Backfill: for each cow with a houseId, copy the worker assigned to
-- that house (via the existing House.worker 1:1 relation, modeled on
-- Worker.houseId). Cows without a house stay null.
UPDATE "Cow" c
SET "workerId" = w."id"
FROM "Worker" w
WHERE w."houseId" = c."houseId" AND c."houseId" IS NOT NULL;
