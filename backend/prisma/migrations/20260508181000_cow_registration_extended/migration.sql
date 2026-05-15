-- Extended cow record fields driven by the v4.1 Register Cow dialog:
-- photo, nickname, production stats, genetics, and health notes. All
-- optional so existing rows survive without backfill.

ALTER TABLE "Cow" ADD COLUMN "nickname"        TEXT;
ALTER TABLE "Cow" ADD COLUMN "imageUrl"        TEXT;
ALTER TABLE "Cow" ADD COLUMN "lactationNumber" INTEGER;
ALTER TABLE "Cow" ADD COLUMN "weightKg"        DOUBLE PRECISION;
ALTER TABLE "Cow" ADD COLUMN "colorMarkings"   TEXT;
ALTER TABLE "Cow" ADD COLUMN "acquisitionDate" TIMESTAMP(3);
ALTER TABLE "Cow" ADD COLUMN "acquisitionType" TEXT;
ALTER TABLE "Cow" ADD COLUMN "motherTag"       TEXT;
ALTER TABLE "Cow" ADD COLUMN "fatherTag"       TEXT;
ALTER TABLE "Cow" ADD COLUMN "healthNotes"     TEXT;
