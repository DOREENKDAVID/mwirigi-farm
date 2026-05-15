/*
  Warnings:

  - You are about to drop the column `dead` on the `EggRecord` table. All the data in the column will be lost.
  - You are about to drop the column `eggs` on the `EggRecord` table. All the data in the column will be lost.
  - You are about to drop the column `feed` on the `EggRecord` table. All the data in the column will be lost.
  - Added the required column `closingStock` to the `EggRecord` table without a default value. This is not possible if the table is not empty.
  - Added the required column `deadRemoved` to the `EggRecord` table without a default value. This is not possible if the table is not empty.
  - Added the required column `eggsCollected` to the `EggRecord` table without a default value. This is not possible if the table is not empty.
  - Added the required column `feedKg` to the `EggRecord` table without a default value. This is not possible if the table is not empty.
  - Added the required column `openingStock` to the `EggRecord` table without a default value. This is not possible if the table is not empty.
  - Added the required column `payType` to the `Worker` table without a default value. This is not possible if the table is not empty.
  - Added the required column `role` to the `Worker` table without a default value. This is not possible if the table is not empty.
  - Added the required column `unit` to the `Worker` table without a default value. This is not possible if the table is not empty.

*/
-- CreateEnum
CREATE TYPE "PayType" AS ENUM ('DAILY', 'MONTHLY');

-- DropForeignKey
ALTER TABLE "Worker" DROP CONSTRAINT "Worker_houseId_fkey";

-- AlterTable
ALTER TABLE "EggRecord" DROP COLUMN "dead",
DROP COLUMN "eggs",
DROP COLUMN "feed",
ADD COLUMN     "closingStock" INTEGER NOT NULL,
ADD COLUMN     "deadRemoved" INTEGER NOT NULL,
ADD COLUMN     "eggsCollected" INTEGER NOT NULL,
ADD COLUMN     "feedKg" DOUBLE PRECISION NOT NULL,
ADD COLUMN     "layingPercent" DOUBLE PRECISION,
ADD COLUMN     "openingStock" INTEGER NOT NULL,
ADD COLUMN     "trays" DOUBLE PRECISION;

-- AlterTable
ALTER TABLE "Worker" ADD COLUMN     "payRate" DOUBLE PRECISION,
ADD COLUMN     "payType" "PayType" NOT NULL,
ADD COLUMN     "role" TEXT NOT NULL,
ADD COLUMN     "unit" TEXT NOT NULL,
ALTER COLUMN "houseId" DROP NOT NULL;

-- CreateTable
CREATE TABLE "Report" (
    "id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "data" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Report_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "EggRecord_houseId_idx" ON "EggRecord"("houseId");

-- AddForeignKey
ALTER TABLE "Worker" ADD CONSTRAINT "Worker_houseId_fkey" FOREIGN KEY ("houseId") REFERENCES "House"("id") ON DELETE SET NULL ON UPDATE CASCADE;
