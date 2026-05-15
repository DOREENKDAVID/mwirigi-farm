/*
  Warnings:

  - You are about to drop the column `closingStock` on the `EggRecord` table. All the data in the column will be lost.
  - You are about to drop the column `deadRemoved` on the `EggRecord` table. All the data in the column will be lost.
  - You are about to drop the column `eggsCollected` on the `EggRecord` table. All the data in the column will be lost.
  - You are about to drop the column `feedKg` on the `EggRecord` table. All the data in the column will be lost.
  - You are about to drop the column `layingPercent` on the `EggRecord` table. All the data in the column will be lost.
  - You are about to drop the column `openingStock` on the `EggRecord` table. All the data in the column will be lost.
  - You are about to drop the column `remarks` on the `EggRecord` table. All the data in the column will be lost.
  - You are about to drop the column `trays` on the `EggRecord` table. All the data in the column will be lost.
  - Added the required column `crates` to the `EggRecord` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "EggRecord" DROP COLUMN "closingStock",
DROP COLUMN "deadRemoved",
DROP COLUMN "eggsCollected",
DROP COLUMN "feedKg",
DROP COLUMN "layingPercent",
DROP COLUMN "openingStock",
DROP COLUMN "remarks",
DROP COLUMN "trays",
ADD COLUMN     "crates" INTEGER NOT NULL;

-- AlterTable
ALTER TABLE "House" ADD COLUMN     "birdCount" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "MortalityRecord" (
    "id" TEXT NOT NULL,
    "count" INTEGER NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "houseId" TEXT NOT NULL,

    CONSTRAINT "MortalityRecord_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "MortalityRecord_date_idx" ON "MortalityRecord"("date");

-- CreateIndex
CREATE INDEX "MortalityRecord_houseId_idx" ON "MortalityRecord"("houseId");

-- AddForeignKey
ALTER TABLE "MortalityRecord" ADD CONSTRAINT "MortalityRecord_houseId_fkey" FOREIGN KEY ("houseId") REFERENCES "House"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
