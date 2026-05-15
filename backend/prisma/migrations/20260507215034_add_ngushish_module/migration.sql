-- CreateEnum
CREATE TYPE "CropStatus" AS ENUM ('ACTIVE', 'GROWING', 'MATURING', 'TASSELING', 'READY_SOON', 'HARVESTED', 'FAILED');

-- CreateTable
CREATE TABLE "Crop" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "acreage" DOUBLE PRECISION NOT NULL,
    "plantedDate" TIMESTAMP(3),
    "expectedHarvest" TIMESTAMP(3),
    "harvestFrequency" TEXT,
    "status" "CropStatus" NOT NULL,
    "destination" TEXT,
    "notes" TEXT,
    "isPerennial" BOOLEAN NOT NULL DEFAULT false,
    "irrigationType" TEXT,
    "irrigated" BOOLEAN NOT NULL DEFAULT false,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Crop_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Harvest" (
    "id" TEXT NOT NULL,
    "cropId" TEXT NOT NULL,
    "quantityKg" DOUBLE PRECISION NOT NULL,
    "harvestDate" TIMESTAMP(3) NOT NULL,
    "qualityGrade" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Harvest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProduceDispatch" (
    "id" TEXT NOT NULL,
    "cropId" TEXT NOT NULL,
    "quantityKg" DOUBLE PRECISION NOT NULL,
    "destination" TEXT NOT NULL,
    "revenue" DOUBLE PRECISION NOT NULL,
    "dispatchDate" TIMESTAMP(3) NOT NULL,
    "buyerName" TEXT,
    "transportCost" DOUBLE PRECISION,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProduceDispatch_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "IrrigationLog" (
    "id" TEXT NOT NULL,
    "cropId" TEXT NOT NULL,
    "irrigationDate" TIMESTAMP(3) NOT NULL,
    "durationMinutes" INTEGER,
    "waterSource" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "IrrigationLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Crop_status_idx" ON "Crop"("status");

-- CreateIndex
CREATE INDEX "Crop_deletedAt_idx" ON "Crop"("deletedAt");

-- CreateIndex
CREATE INDEX "Crop_irrigated_idx" ON "Crop"("irrigated");

-- CreateIndex
CREATE INDEX "Harvest_cropId_idx" ON "Harvest"("cropId");

-- CreateIndex
CREATE INDEX "Harvest_harvestDate_idx" ON "Harvest"("harvestDate");

-- CreateIndex
CREATE INDEX "ProduceDispatch_cropId_idx" ON "ProduceDispatch"("cropId");

-- CreateIndex
CREATE INDEX "ProduceDispatch_dispatchDate_idx" ON "ProduceDispatch"("dispatchDate");

-- CreateIndex
CREATE INDEX "IrrigationLog_cropId_idx" ON "IrrigationLog"("cropId");

-- CreateIndex
CREATE INDEX "IrrigationLog_irrigationDate_idx" ON "IrrigationLog"("irrigationDate");

-- AddForeignKey
ALTER TABLE "Harvest" ADD CONSTRAINT "Harvest_cropId_fkey" FOREIGN KEY ("cropId") REFERENCES "Crop"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProduceDispatch" ADD CONSTRAINT "ProduceDispatch_cropId_fkey" FOREIGN KEY ("cropId") REFERENCES "Crop"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "IrrigationLog" ADD CONSTRAINT "IrrigationLog_cropId_fkey" FOREIGN KEY ("cropId") REFERENCES "Crop"("id") ON DELETE CASCADE ON UPDATE CASCADE;
