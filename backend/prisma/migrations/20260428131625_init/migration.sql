-- CreateEnum
CREATE TYPE "Role" AS ENUM ('CEO', 'DAIRY_MANAGER', 'LAYERS_MANAGER', 'PIGGERY_MANAGER', 'VET', 'ICT');

-- CreateEnum
CREATE TYPE "SessionType" AS ENUM ('AM', 'MID', 'PM');

-- CreateEnum
CREATE TYPE "VaccineStatus" AS ENUM ('CURRENT', 'DUE_SOON', 'OVERDUE');

-- CreateEnum
CREATE TYPE "Sections" AS ENUM ('Dairy', 'Piggery', 'Poultry');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "role" "Role" NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "House" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" "Sections" NOT NULL,
    "capacity" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "House_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Worker" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "houseId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Worker_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Cow" (
    "id" TEXT NOT NULL,
    "tag" TEXT NOT NULL,
    "breed" TEXT NOT NULL,
    "avgYield" DOUBLE PRECISION NOT NULL,
    "hasCalf" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "houseId" TEXT NOT NULL,

    CONSTRAINT "Cow_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MilkRecord" (
    "id" TEXT NOT NULL,
    "litres" DOUBLE PRECISION NOT NULL,
    "session" "SessionType" NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "cowId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,

    CONSTRAINT "MilkRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EggRecord" (
    "id" TEXT NOT NULL,
    "eggs" INTEGER NOT NULL,
    "feed" DOUBLE PRECISION NOT NULL,
    "dead" INTEGER NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "remarks" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "houseId" TEXT NOT NULL,

    CONSTRAINT "EggRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PiggeryRecord" (
    "id" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "dateOfService" TIMESTAMP(3),
    "expectantSows" INTEGER,
    "dayOfFarrowing" INTEGER,
    "winners" INTEGER NOT NULL,
    "fatteners" INTEGER NOT NULL,
    "beaconners" INTEGER NOT NULL,
    "totalAlive" INTEGER NOT NULL,
    "dead" INTEGER NOT NULL,
    "remarks" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "houseId" TEXT NOT NULL,

    CONSTRAINT "PiggeryRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Vaccine" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "lastDate" TIMESTAMP(3) NOT NULL,
    "nextDate" TIMESTAMP(3) NOT NULL,
    "status" "VaccineStatus" NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Vaccine_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FarmConfig" (
    "id" TEXT NOT NULL,
    "farmName" TEXT NOT NULL,
    "version" TEXT NOT NULL,
    "location" TEXT NOT NULL,
    "year" TEXT NOT NULL,
    "milkTarget" DOUBLE PRECISION NOT NULL,
    "eggsTarget" INTEGER NOT NULL,
    "householdDeduct" DOUBLE PRECISION NOT NULL,
    "calfDeduction" DOUBLE PRECISION NOT NULL,
    "sowCount" INTEGER NOT NULL,
    "gestationDays" INTEGER NOT NULL,
    "weaningDays" INTEGER NOT NULL,
    "saleAgeDays" INTEGER NOT NULL,
    "beaconnersTarget" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FarmConfig_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "House_name_key" ON "House"("name");

-- CreateIndex
CREATE UNIQUE INDEX "Worker_houseId_key" ON "Worker"("houseId");

-- CreateIndex
CREATE UNIQUE INDEX "Cow_tag_key" ON "Cow"("tag");

-- CreateIndex
CREATE INDEX "MilkRecord_date_session_idx" ON "MilkRecord"("date", "session");

-- CreateIndex
CREATE INDEX "EggRecord_date_idx" ON "EggRecord"("date");

-- CreateIndex
CREATE INDEX "PiggeryRecord_date_idx" ON "PiggeryRecord"("date");

-- AddForeignKey
ALTER TABLE "Worker" ADD CONSTRAINT "Worker_houseId_fkey" FOREIGN KEY ("houseId") REFERENCES "House"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Cow" ADD CONSTRAINT "Cow_houseId_fkey" FOREIGN KEY ("houseId") REFERENCES "House"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MilkRecord" ADD CONSTRAINT "MilkRecord_cowId_fkey" FOREIGN KEY ("cowId") REFERENCES "Cow"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MilkRecord" ADD CONSTRAINT "MilkRecord_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EggRecord" ADD CONSTRAINT "EggRecord_houseId_fkey" FOREIGN KEY ("houseId") REFERENCES "House"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PiggeryRecord" ADD CONSTRAINT "PiggeryRecord_houseId_fkey" FOREIGN KEY ("houseId") REFERENCES "House"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
