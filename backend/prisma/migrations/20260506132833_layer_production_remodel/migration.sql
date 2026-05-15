/*
  Warnings:

  - You are about to drop the column `birdCount` on the `House` table. All the data in the column will be lost.
  - You are about to drop the `EggRecord` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `MortalityRecord` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "EggRecord" DROP CONSTRAINT "EggRecord_houseId_fkey";

-- DropForeignKey
ALTER TABLE "MortalityRecord" DROP CONSTRAINT "MortalityRecord_houseId_fkey";

-- AlterTable
ALTER TABLE "House" DROP COLUMN "birdCount",
ADD COLUMN     "color" TEXT NOT NULL DEFAULT '#27500A';

-- DropTable
DROP TABLE "EggRecord";

-- DropTable
DROP TABLE "MortalityRecord";

-- CreateTable
CREATE TABLE "LayerProduction" (
    "id" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "openingStock" INTEGER NOT NULL,
    "eggsCollected" INTEGER NOT NULL,
    "trays" DOUBLE PRECISION NOT NULL,
    "percentLaying" DOUBLE PRECISION NOT NULL,
    "feedKg" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "deadRemoved" INTEGER NOT NULL DEFAULT 0,
    "closingStock" INTEGER NOT NULL,
    "dayAge" INTEGER NOT NULL,
    "remarks" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "houseId" TEXT NOT NULL,

    CONSTRAINT "LayerProduction_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "LayerProduction_date_idx" ON "LayerProduction"("date");

-- CreateIndex
CREATE INDEX "LayerProduction_houseId_idx" ON "LayerProduction"("houseId");

-- CreateIndex
CREATE UNIQUE INDEX "LayerProduction_houseId_date_key" ON "LayerProduction"("houseId", "date");

-- AddForeignKey
ALTER TABLE "LayerProduction" ADD CONSTRAINT "LayerProduction_houseId_fkey" FOREIGN KEY ("houseId") REFERENCES "House"("id") ON DELETE CASCADE ON UPDATE CASCADE;
