/*
  Warnings:

  - You are about to drop the `PiggeryRecord` table. If the table is not empty, all the data it contains will be lost.

*/
-- CreateEnum
CREATE TYPE "PigCategory" AS ENUM ('SOW', 'BOAR', 'PIGLET');

-- CreateEnum
CREATE TYPE "PigStatus" AS ENUM ('LACTATING', 'GESTATING', 'FARROWING_SOON', 'WEANED');

-- DropForeignKey
ALTER TABLE "PiggeryRecord" DROP CONSTRAINT "PiggeryRecord_houseId_fkey";

-- DropTable
DROP TABLE "PiggeryRecord";

-- CreateTable
CREATE TABLE "Pig" (
    "id" TEXT NOT NULL,
    "tag" TEXT NOT NULL,
    "category" "PigCategory" NOT NULL,
    "status" "PigStatus",
    "litterCount" INTEGER NOT NULL DEFAULT 0,
    "lastFarrowed" TIMESTAMP(3),
    "dueDate" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Pig_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FarrowingRecord" (
    "id" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "pigletsBorn" INTEGER NOT NULL,
    "pigletsAlive" INTEGER NOT NULL,
    "pigletsDead" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "sowId" TEXT NOT NULL,

    CONSTRAINT "FarrowingRecord_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Pig_tag_key" ON "Pig"("tag");

-- CreateIndex
CREATE INDEX "Pig_category_idx" ON "Pig"("category");

-- CreateIndex
CREATE INDEX "Pig_dueDate_idx" ON "Pig"("dueDate");

-- CreateIndex
CREATE INDEX "FarrowingRecord_date_idx" ON "FarrowingRecord"("date");

-- CreateIndex
CREATE INDEX "FarrowingRecord_sowId_idx" ON "FarrowingRecord"("sowId");

-- AddForeignKey
ALTER TABLE "FarrowingRecord" ADD CONSTRAINT "FarrowingRecord_sowId_fkey" FOREIGN KEY ("sowId") REFERENCES "Pig"("id") ON DELETE CASCADE ON UPDATE CASCADE;
