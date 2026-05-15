-- CreateEnum
CREATE TYPE "FeedCategory" AS ENUM ('MAIZE_GERM', 'SOYA', 'SUNFLOWER', 'LIME', 'PREMIX', 'WHEAT_BRAN', 'COTTON_SEED', 'FISH_MEAL', 'OTHER');

-- CreateEnum
CREATE TYPE "BulkFeedType" AS ENUM ('SILAGE', 'NAPIER', 'MAIZE_SILAGE');

-- CreateEnum
CREATE TYPE "BulkFeedUnit" AS ENUM ('PERCENT', 'ACRES', 'TONNES');

-- CreateEnum
CREATE TYPE "BulkFeedStatus" AS ENUM ('ACTIVE', 'REPLENISH_SOON', 'MATURING', 'DEPLETED');

-- CreateEnum
CREATE TYPE "LivestockUnit" AS ENUM ('DAIRY', 'CALVES', 'HEIFERS', 'DOOPERS', 'FEEDLOT', 'PIGGERY', 'LAYERS', 'BROODER');

-- AlterEnum
ALTER TYPE "Role" ADD VALUE 'FEEDS_MANAGER';

-- CreateTable
CREATE TABLE "FeedMaterial" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "category" "FeedCategory" NOT NULL,
    "packSize" TEXT NOT NULL,
    "stockOnHandKg" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "dailyUseKg" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "reorderLevelDays" INTEGER NOT NULL DEFAULT 5,
    "supplier" TEXT,
    "costPerKg" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FeedMaterial_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FeedDelivery" (
    "id" TEXT NOT NULL,
    "materialId" TEXT NOT NULL,
    "quantityKg" DOUBLE PRECISION NOT NULL,
    "unitCost" DOUBLE PRECISION,
    "supplier" TEXT,
    "invoiceNumber" TEXT,
    "deliveredAt" TIMESTAMP(3) NOT NULL,
    "notes" TEXT,
    "createdById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FeedDelivery_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FeedConsumptionLog" (
    "id" TEXT NOT NULL,
    "materialId" TEXT NOT NULL,
    "quantityUsedKg" DOUBLE PRECISION NOT NULL,
    "durationDays" INTEGER NOT NULL,
    "calculatedDailyUseKg" DOUBLE PRECISION NOT NULL,
    "notes" TEXT,
    "createdById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FeedConsumptionLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BulkFeedStock" (
    "id" TEXT NOT NULL,
    "type" "BulkFeedType" NOT NULL,
    "quantity" DOUBLE PRECISION NOT NULL,
    "unit" "BulkFeedUnit" NOT NULL,
    "status" "BulkFeedStatus" NOT NULL,
    "notes" TEXT,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BulkFeedStock_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FeedDistribution" (
    "id" TEXT NOT NULL,
    "livestockUnit" "LivestockUnit" NOT NULL,
    "concentrateKg" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "silageKg" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "napierKg" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "animalCount" INTEGER NOT NULL DEFAULT 0,
    "recordedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FeedDistribution_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "FeedMaterial_name_key" ON "FeedMaterial"("name");

-- CreateIndex
CREATE INDEX "FeedMaterial_category_idx" ON "FeedMaterial"("category");

-- CreateIndex
CREATE INDEX "FeedDelivery_materialId_idx" ON "FeedDelivery"("materialId");

-- CreateIndex
CREATE INDEX "FeedDelivery_deliveredAt_idx" ON "FeedDelivery"("deliveredAt");

-- CreateIndex
CREATE INDEX "FeedConsumptionLog_materialId_idx" ON "FeedConsumptionLog"("materialId");

-- CreateIndex
CREATE UNIQUE INDEX "BulkFeedStock_type_key" ON "BulkFeedStock"("type");

-- CreateIndex
CREATE INDEX "FeedDistribution_livestockUnit_idx" ON "FeedDistribution"("livestockUnit");

-- CreateIndex
CREATE INDEX "FeedDistribution_recordedAt_idx" ON "FeedDistribution"("recordedAt");

-- AddForeignKey
ALTER TABLE "FeedDelivery" ADD CONSTRAINT "FeedDelivery_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "FeedMaterial"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeedConsumptionLog" ADD CONSTRAINT "FeedConsumptionLog_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "FeedMaterial"("id") ON DELETE CASCADE ON UPDATE CASCADE;
