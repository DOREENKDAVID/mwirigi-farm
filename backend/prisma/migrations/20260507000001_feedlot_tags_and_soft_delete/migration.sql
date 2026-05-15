-- AlterTable
ALTER TABLE "Bull" ADD COLUMN "deletedAt" TIMESTAMP(3);

-- AlterTable: drop existing Sheep rows are already cleared; add new columns.
ALTER TABLE "Sheep" ADD COLUMN "tag" TEXT NOT NULL,
                    ADD COLUMN "entryDate" TIMESTAMP(3) NOT NULL,
                    ADD COLUMN "entryWeight" DOUBLE PRECISION,
                    ADD COLUMN "deletedAt" TIMESTAMP(3);

-- CreateIndex
CREATE UNIQUE INDEX "Sheep_tag_key" ON "Sheep"("tag");

-- CreateIndex
CREATE INDEX "Bull_deletedAt_idx" ON "Bull"("deletedAt");

-- CreateIndex
CREATE INDEX "Sheep_deletedAt_idx" ON "Sheep"("deletedAt");
