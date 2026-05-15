-- AlterTable
ALTER TABLE "Pig" ADD COLUMN     "deletedAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "Pig_deletedAt_idx" ON "Pig"("deletedAt");
