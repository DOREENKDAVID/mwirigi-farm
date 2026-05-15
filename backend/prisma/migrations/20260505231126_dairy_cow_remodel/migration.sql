/*
  Warnings:

  - You are about to drop the column `avgYield` on the `Cow` table. All the data in the column will be lost.
  - You are about to drop the column `hasCalf` on the `Cow` table. All the data in the column will be lost.
  - Added the required column `dateOfBirth` to the `Cow` table without a default value. This is not possible if the table is not empty.
  - Added the required column `status` to the `Cow` table without a default value. This is not possible if the table is not empty.
  - Changed the type of `breed` on the `Cow` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.

*/
-- CreateEnum
CREATE TYPE "Breed" AS ENUM ('FRIESIAN', 'AYRSHIRE', 'JERSEY', 'SAHIWAL', 'CROSSBREED');

-- CreateEnum
CREATE TYPE "CowStatus" AS ENUM ('MILKING', 'DRY_OFF', 'PREGNANT', 'SICK', 'HEIFER');

-- AlterTable
ALTER TABLE "Cow" DROP COLUMN "avgYield",
DROP COLUMN "hasCalf",
ADD COLUMN     "dateOfBirth" TIMESTAMP(3) NOT NULL,
ADD COLUMN     "status" "CowStatus" NOT NULL,
DROP COLUMN "breed",
ADD COLUMN     "breed" "Breed" NOT NULL;
