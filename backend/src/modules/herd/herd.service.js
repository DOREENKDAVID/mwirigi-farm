import prisma from "../prisma/client.js";

//////////////////////////////////////////////////////
// COW SERVICES
//////////////////////////////////////////////////////

export const createCow = async ({ tag, breed, avgYield, houseId }) => {
  // normalize tag (important!)
  const normalizedTag =
  tag.trim().charAt(0).toUpperCase() + tag.trim().slice(1).toLowerCase();

  // check if cow already exists
  const existingCow = await prisma.cow.findUnique({
    where: { tag: normalizedTag },
  });

  if (existingCow) {
    throw new Error("Cow with this tag already exists");
  }

  // create cow
  return await prisma.cow.create({
    data: {
      tag: normalizedTag,
      breed,
      avgYield: avgYield || 0,
      houseId,
    },
  });
};

export const getAllCows = async () => {
  return await prisma.cow.findMany({
    include: {
      milkRecords: true,
    },
  });
};

export const getCowByTag = async (tag) => {
    const normalizedTag =
  tag.trim().charAt(0).toUpperCase() + tag.trim().slice(1).toLowerCase();
  return await prisma.cow.findUnique({
    where: { tag: normalizedTag },
    include: {
      milkRecords: true,
    },
  });
};

export const updateCow = async (tag, data) => {
    const normalizedTag =
  tag.trim().charAt(0).toUpperCase() + tag.trim().slice(1).toLowerCase();
  return await prisma.cow.update({
    where: { tag: normalizedTag },
    data,
  });
};

export const deleteCow = async (tag) => {
    const normalizedTag =
  tag.trim().charAt(0).toUpperCase() + tag.trim().slice(1).toLowerCase();
  return await prisma.cow.delete({
    where: { tag: normalizedTag },
  });
};

//////////////////////////////////////////////////////
// MILK RECORD SERVICES
//////////////////////////////////////////////////////

export const createMilkRecord = async ({ cowTag, litres, session, date, userId }) => {
  // optional: validate cow exists
  const cow = await prisma.cow.findUnique({
    where: { tag: cowTag },
  });

  if (!cow) throw new Error("Cow not found");

  return await prisma.milkRecord.create({
    data: {
      cowId: cow.id,
      litres,
      session,
      date,
      userId,
    },
  });
};

export const getMilkRecords = async () => {
  return await prisma.milkRecord.findMany({
    include: {
      cow: true,
      user: true,
    },
    orderBy: {
      date: "desc",
    },
  });
};

export const getMilkRecordsByCow = async (cowId) => {
  return await prisma.milkRecord.findMany({
    where: { tag },
    orderBy: {
      date: "desc",
    },
  });
};

export const deleteMilkRecord = async (id) => {
  return await prisma.milkRecord.delete({
    where: { tag },
  });
};