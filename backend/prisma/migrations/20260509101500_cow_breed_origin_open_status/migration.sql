-- v4.1 Register Cow dialog additions:
--   * Cow.breedOrigin  ('F' / 'L' / 'X' classification)
--   * Breed enum gains BROWN_SWISS, BORAN, ZEBU
--   * CowStatus enum gains OPEN ("not yet confirmed")

ALTER TABLE "Cow" ADD COLUMN "breedOrigin" TEXT;

ALTER TYPE "Breed" ADD VALUE IF NOT EXISTS 'BROWN_SWISS';
ALTER TYPE "Breed" ADD VALUE IF NOT EXISTS 'BORAN';
ALTER TYPE "Breed" ADD VALUE IF NOT EXISTS 'ZEBU';

ALTER TYPE "CowStatus" ADD VALUE IF NOT EXISTS 'OPEN';
