-- AlterTable
ALTER TABLE "House" ADD COLUMN     "birdCount" INTEGER NOT NULL DEFAULT 0;

-- CreateEnum
CREATE TYPE "AllocationType" AS ENUM ('POL_SALE', 'REPLACEMENT');

-- CreateTable
CREATE TABLE "Brooder" (
    "id" TEXT NOT NULL,
    "label" TEXT,
    "population" INTEGER NOT NULL,
    "receivedDate" TIMESTAMP(3) NOT NULL,
    "targetDays" INTEGER NOT NULL DEFAULT 90,
    "mortality" INTEGER NOT NULL DEFAULT 0,
    "actualTransferDate" TIMESTAMP(3),
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Brooder_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Brooder_receivedDate_idx" ON "Brooder"("receivedDate");

-- CreateTable
CREATE TABLE "BrooderVaccination" (
    "id" TEXT NOT NULL,
    "brooderId" TEXT NOT NULL,
    "dayOffset" INTEGER NOT NULL,
    "vaccineName" TEXT NOT NULL,
    "administeredAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BrooderVaccination_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "BrooderVaccination_brooderId_dayOffset_key" ON "BrooderVaccination"("brooderId", "dayOffset");

-- CreateIndex
CREATE INDEX "BrooderVaccination_brooderId_idx" ON "BrooderVaccination"("brooderId");

-- AddForeignKey
ALTER TABLE "BrooderVaccination" ADD CONSTRAINT "BrooderVaccination_brooderId_fkey" FOREIGN KEY ("brooderId") REFERENCES "Brooder"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "AllocationPlan" (
    "id" TEXT NOT NULL,
    "brooderId" TEXT NOT NULL,
    "cycleId" TEXT NOT NULL,
    "type" "AllocationType" NOT NULL,
    "birds" INTEGER NOT NULL,
    "description" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AllocationPlan_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "AllocationPlan_brooderId_idx" ON "AllocationPlan"("brooderId");

-- CreateIndex
CREATE INDEX "AllocationPlan_cycleId_idx" ON "AllocationPlan"("cycleId");

-- AddForeignKey
ALTER TABLE "AllocationPlan" ADD CONSTRAINT "AllocationPlan_brooderId_fkey" FOREIGN KEY ("brooderId") REFERENCES "Brooder"("id") ON DELETE CASCADE ON UPDATE CASCADE;
