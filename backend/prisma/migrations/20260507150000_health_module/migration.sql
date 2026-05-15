-- DropTable
DROP TABLE IF EXISTS "Vaccine";

-- DropEnum
DROP TYPE IF EXISTS "VaccineStatus";

-- CreateEnum
CREATE TYPE "HealthUnit" AS ENUM ('Dairy', 'Piggery', 'Layers', 'Doopers', 'Feedlot');

-- CreateEnum
CREATE TYPE "VaccineProtocolType" AS ENUM ('ANNUAL', 'RECURRING', 'BROODER_DAY');

-- CreateEnum
CREATE TYPE "VaccinationStatus" AS ENUM ('DONE', 'DUE_WINDOW_OPEN', 'DUE_NOW', 'DUE_SOON', 'UPCOMING', 'OVERDUE');

-- CreateEnum
CREATE TYPE "TreatmentStatus" AS ENUM ('ACTIVE', 'IMPROVING', 'RECOVERED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "VetProtocolGroup" AS ENUM ('CHICKS', 'CALVES', 'PIGLETS');

-- CreateTable
CREATE TABLE "VaccineProtocol" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "unit" "HealthUnit" NOT NULL,
    "species" TEXT,
    "type" "VaccineProtocolType" NOT NULL,
    "allowedMonths" INTEGER[] DEFAULT ARRAY[]::INTEGER[],
    "recurrenceMonths" INTEGER,
    "dayOffsetStart" INTEGER,
    "dayOffsetEnd" INTEGER,
    "notes" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VaccineProtocol_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VaccinationRecord" (
    "id" TEXT NOT NULL,
    "protocolId" TEXT NOT NULL,
    "unit" "HealthUnit" NOT NULL,
    "animalCount" INTEGER NOT NULL,
    "administeredAt" TIMESTAMP(3) NOT NULL,
    "nextDueOverride" TIMESTAMP(3),
    "notes" TEXT,
    "recordedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VaccinationRecord_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "VaccinationRecord_protocolId_idx" ON "VaccinationRecord"("protocolId");

-- CreateIndex
CREATE INDEX "VaccinationRecord_administeredAt_idx" ON "VaccinationRecord"("administeredAt");

-- AddForeignKey
ALTER TABLE "VaccinationRecord" ADD CONSTRAINT "VaccinationRecord_protocolId_fkey" FOREIGN KEY ("protocolId") REFERENCES "VaccineProtocol"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "Treatment" (
    "id" TEXT NOT NULL,
    "tag" TEXT NOT NULL,
    "unit" "HealthUnit" NOT NULL,
    "diagnosis" TEXT NOT NULL,
    "medication" TEXT NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3),
    "status" "TreatmentStatus" NOT NULL DEFAULT 'ACTIVE',
    "notes" TEXT,
    "attendingVet" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Treatment_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Treatment_status_idx" ON "Treatment"("status");

-- CreateIndex
CREATE INDEX "Treatment_startDate_idx" ON "Treatment"("startDate");

-- CreateTable
CREATE TABLE "VetProtocolTemplate" (
    "id" TEXT NOT NULL,
    "group" "VetProtocolGroup" NOT NULL,
    "title" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VetProtocolTemplate_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "VetProtocolTemplate_group_key" ON "VetProtocolTemplate"("group");

-- CreateTable
CREATE TABLE "VetProtocolStep" (
    "id" TEXT NOT NULL,
    "templateId" TEXT NOT NULL,
    "order" INTEGER NOT NULL,
    "dayLabel" TEXT NOT NULL,
    "procedure" TEXT NOT NULL,
    "notes" TEXT,

    CONSTRAINT "VetProtocolStep_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "VetProtocolStep_templateId_order_idx" ON "VetProtocolStep"("templateId", "order");

-- AddForeignKey
ALTER TABLE "VetProtocolStep" ADD CONSTRAINT "VetProtocolStep_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "VetProtocolTemplate"("id") ON DELETE CASCADE ON UPDATE CASCADE;
