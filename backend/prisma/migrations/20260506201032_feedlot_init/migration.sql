-- CreateEnum
CREATE TYPE "SheepCategory" AS ENUM ('EWE', 'RAM', 'LAMB');

-- CreateTable
CREATE TABLE "Bull" (
    "id" TEXT NOT NULL,
    "tag" TEXT NOT NULL,
    "breed" TEXT NOT NULL,
    "entryDate" TIMESTAMP(3) NOT NULL,
    "entryWeight" DOUBLE PRECISION NOT NULL,
    "currentWeight" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Bull_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WeightRecord" (
    "id" TEXT NOT NULL,
    "weight" DOUBLE PRECISION NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "bullId" TEXT NOT NULL,

    CONSTRAINT "WeightRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Sheep" (
    "id" TEXT NOT NULL,
    "category" "SheepCategory" NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Sheep_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LambingRecord" (
    "id" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "lambsBorn" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LambingRecord_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Bull_tag_key" ON "Bull"("tag");

-- CreateIndex
CREATE INDEX "Bull_entryDate_idx" ON "Bull"("entryDate");

-- CreateIndex
CREATE INDEX "WeightRecord_bullId_idx" ON "WeightRecord"("bullId");

-- CreateIndex
CREATE INDEX "WeightRecord_date_idx" ON "WeightRecord"("date");

-- CreateIndex
CREATE INDEX "Sheep_category_idx" ON "Sheep"("category");

-- CreateIndex
CREATE INDEX "LambingRecord_date_idx" ON "LambingRecord"("date");

-- AddForeignKey
ALTER TABLE "WeightRecord" ADD CONSTRAINT "WeightRecord_bullId_fkey" FOREIGN KEY ("bullId") REFERENCES "Bull"("id") ON DELETE CASCADE ON UPDATE CASCADE;
