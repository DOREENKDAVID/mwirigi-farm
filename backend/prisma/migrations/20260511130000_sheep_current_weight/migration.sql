-- Sheep current weight — enables ADG tracking on doopers (mirrors Bull.currentWeight).
ALTER TABLE "Sheep" ADD COLUMN "currentWeight" DOUBLE PRECISION;

-- Seed currentWeight from entryWeight for existing rows so ADG = 0 until
-- the first edit, rather than the column appearing as "unmeasured".
UPDATE "Sheep" SET "currentWeight" = "entryWeight" WHERE "entryWeight" IS NOT NULL;
