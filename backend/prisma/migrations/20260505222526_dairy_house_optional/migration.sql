-- DropForeignKey
ALTER TABLE "Cow" DROP CONSTRAINT "Cow_houseId_fkey";

-- AlterTable
ALTER TABLE "Cow" ALTER COLUMN "houseId" DROP NOT NULL;

-- AddForeignKey
ALTER TABLE "Cow" ADD CONSTRAINT "Cow_houseId_fkey" FOREIGN KEY ("houseId") REFERENCES "House"("id") ON DELETE SET NULL ON UPDATE CASCADE;
