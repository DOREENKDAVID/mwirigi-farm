-- CreateEnum
CREATE TYPE "ReproductionEventType" AS ENUM ('AI', 'CALVING');

-- CreateEnum
CREATE TYPE "PregnancyStatus" AS ENUM ('PENDING', 'CONFIRMED', 'OPEN', 'ABORTED');

-- CreateTable
CREATE TABLE "ReproductionRecord" (
    "id" TEXT NOT NULL,
    "cowId" TEXT NOT NULL,
    "eventType" "ReproductionEventType" NOT NULL,
    "eventDate" TIMESTAMP(3) NOT NULL,
    "sireCode" TEXT,
    "pregnancyStatus" "PregnancyStatus" NOT NULL DEFAULT 'PENDING',
    "pregnancyCheckDate" TIMESTAMP(3),
    "expectedCalvingDate" TIMESTAMP(3),
    "calfTag" TEXT,
    "notes" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReproductionRecord_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ReproductionRecord_cowId_idx" ON "ReproductionRecord"("cowId");

-- CreateIndex
CREATE INDEX "ReproductionRecord_eventDate_idx" ON "ReproductionRecord"("eventDate");

-- CreateIndex
CREATE INDEX "ReproductionRecord_eventType_idx" ON "ReproductionRecord"("eventType");

-- AddForeignKey
ALTER TABLE "ReproductionRecord" ADD CONSTRAINT "ReproductionRecord_cowId_fkey" FOREIGN KEY ("cowId") REFERENCES "Cow"("id") ON DELETE CASCADE ON UPDATE CASCADE;
