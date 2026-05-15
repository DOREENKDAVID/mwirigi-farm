-- AlterTable
ALTER TABLE "FeedMaterial" ADD COLUMN     "deletedAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "FeedMaterial_deletedAt_idx" ON "FeedMaterial"("deletedAt");
