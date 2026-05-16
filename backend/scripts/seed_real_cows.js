// One-shot script to replace the existing cow herd with the 115-cow
// Mwirigi Farm register. Empty placeholder slots (cows with no name
// in the source) are skipped — 55 real cows are inserted/updated.
//
// Matching strategy (to preserve milk history):
//   1. Existing cow.nickname (case-insensitive) == new nickname
//      — preserve real named cows like "Topten" since their milk
//      history is presumed more valuable than a placeholder tag row.
//   2. Existing cow.tag (case-insensitive) == new nickname (e.g.
//      cow tagged "Topten" before being renumbered to MW-001).
//   3. Existing cow.tag == new normalized tag (e.g. "Mw-001").
// Matched cows are UPDATED in place — their id stays, so their
// MilkRecord rows (linked by cowId) survive. Unmatched existing
// cows are deleted along with their milk + reproduction records.
//
// Run with:  node scripts/seed_real_cows.js
// Requires DATABASE_URL in .env.

import "dotenv/config";
import { PrismaPg } from "@prisma/adapter-pg";
import pkg from "@prisma/client";
const { PrismaClient } = pkg;

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

// [tag, nickname, breed, origin, statusCode, workerName]
// Placeholder rows (empty nickname/breed) stripped from the source.
const SEED = [
  ['MW-001','Topten','Friesian','F','M','Ronald'],
  ['MW-002','Makena','Friesian','F','M','Ronald'],
  ['MW-003','Orion','Friesian','F','M','Ronald'],
  ['MW-004','Kirote','Friesian','F','M','Ronald'],
  ['MW-005','Caspa','Friesian','F','D','Ronald'],
  ['MW-006','Favour','Friesian','F','M','Ronald'],
  ['MW-012','Mrefu','Friesian','F','M','Musyoka'],
  ['MW-013','Reloy','Friesian','F','M','Musyoka'],
  ['MW-014','Meni','Friesian','F','M','Musyoka'],
  ['MW-015','Kachumi','Friesian','F','M','Musyoka'],
  ['MW-016','Cicilia','Friesian','F','M','Musyoka'],
  ['MW-017','Smart','Friesian','F','D','Musyoka'],
  ['MW-023','Marion','Friesian','F','M','Joshua'],
  ['MW-024','Karendi','Friesian','F','M','Joshua'],
  ['MW-025','Angela','Friesian','F','M','Joshua'],
  ['MW-026','Tesn.J','Friesian','F','M','Joshua'],
  ['MW-027','Madox','Friesian','F','D','Joshua'],
  ['MW-034','Nyambura','Friesian','F','M','Ivan'],
  ['MW-035','Rose','Friesian','F','M','Ivan'],
  ['MW-036','Monica','Friesian','F','M','Ivan'],
  ['MW-037','Mumbi','Friesian','F','M','Ivan'],
  ['MW-038','Oscar','Friesian','F','D','Ivan'],
  ['MW-045','Dereva','Friesian','F','M','Jacob'],
  ['MW-046','Shiru','Friesian','F','M','Jacob'],
  ['MW-047','Daisy','Friesian','F','M','Jacob'],
  ['MW-048','Melvin','Friesian','F','M','Jacob'],
  ['MW-049','Lucky','Friesian','F','D','Jacob'],
  ['MW-056','Mwiru','Friesian','F','M','Mukisa'],
  ['MW-057','Vera','Friesian','F','M','Mukisa'],
  ['MW-058','Sandra','Jersey','F','M','Mukisa'],
  ['MW-059','Makose','Friesian','F','M','Mukisa'],
  ['MW-060','Twin','Friesian','F','D','Mukisa'],
  ['MW-066','Caro','Friesian','F','M','Toby'],
  ['MW-067','Katiba','Friesian','F','M','Toby'],
  ['MW-068','Karambu','Friesian','F','M','Toby'],
  ['MW-069','Muthoni','Friesian','F','M','Toby'],
  ['MW-070','Blessing','Friesian','F','D','Toby'],
  ['MW-076','Munyaka','Friesian','F','M','Karis'],
  ['MW-077','Tanya black','Friesian','F','M','Karis'],
  ['MW-078','Shiku','Friesian','F','M','Karis'],
  ['MW-086','Sela','Friesian','F','M','John'],
  ['MW-087','Milly','Friesian','F','M','John'],
  ['MW-088','Marion','Friesian','F','M','John'],
  ['MW-089','Max','Friesian','F','M','John'],
  ['MW-090','Olimpic','Friesian','F','D','John'],
  ['MW-096','Tanya','Jersey','F','M','Sam'],
  ['MW-097','Star','Friesian','F','M','Sam'],
  ['MW-098','Dasher','Friesian','F','M','Sam'],
  ['MW-099','Kagendo','Friesian','F','M','Sam'],
  ['MW-100','Summer','Friesian','F','D','Sam'],
  ['MW-106','Monica A','Friesian','F','M','Nick'],
  ['MW-107','Marry','Friesian','F','M','Nick'],
  ['MW-108','Champion','Friesian','F','M','Nick'],
  ['MW-109','Princess','Friesian','F','D','Nick'],
  ['MW-110','Jerica','Friesian','F','D','Nick'],
];

const BREED_MAP = { Friesian: 'FRIESIAN', Jersey: 'JERSEY' };
const STATUS_MAP = { M: 'MILKING', D: 'DRY_OFF' };
const DRY_REASON = 'End of lactation cycle';

const normalizeTag = (t) =>
  t.trim().charAt(0).toUpperCase() + t.trim().slice(1).toLowerCase();

async function main() {
  const existing = await prisma.cow.findMany({
    select: { id: true, tag: true, nickname: true, dateOfBirth: true },
  });
  console.log(`Existing cows on Neon: ${existing.length}`);

  const workers = await prisma.worker.findMany({ select: { id: true, name: true } });
  const workerByName = Object.fromEntries(workers.map((w) => [w.name, w.id]));

  const matchedIds = new Set();
  const updates = [];
  const creates = [];
  const matchLog = [];

  for (const [tag, nickname, breed, origin, statusCode, workerName] of SEED) {
    const normTag = normalizeTag(tag);
    const lowerName = nickname.toLowerCase();
    let match =
      existing.find(
        (c) =>
          (c.nickname ?? '').toLowerCase() === lowerName &&
          !matchedIds.has(c.id),
      ) ||
      existing.find(
        (c) => c.tag.toLowerCase() === lowerName && !matchedIds.has(c.id),
      ) ||
      existing.find((c) => c.tag === normTag && !matchedIds.has(c.id));

    const status = STATUS_MAP[statusCode];
    const data = {
      tag: normTag,
      nickname,
      breed: BREED_MAP[breed],
      breedOrigin: origin || null,
      status,
      statusReason: status === 'DRY_OFF' ? DRY_REASON : null,
      workerId: workerByName[workerName] ?? null,
    };

    if (match) {
      matchedIds.add(match.id);
      updates.push({ id: match.id, data, from: match.tag });
      matchLog.push(`  ✓ ${match.tag} → ${normTag} (${nickname})`);
    } else {
      creates.push({ ...data, nickname });
      matchLog.push(`  + NEW: ${normTag} (${nickname})`);
    }
  }

  const toDelete = existing.filter((c) => !matchedIds.has(c.id));

  console.log(`\nMatch plan:`);
  console.log(matchLog.join('\n'));
  console.log(`\nSummary:`);
  console.log(`  Match + update: ${updates.length}`);
  console.log(`  New cows:       ${creates.length}`);
  console.log(`  To delete:      ${toDelete.length} (${toDelete.map((c) => c.tag).join(', ')})`);

  if (toDelete.length > 0) {
    const ids = toDelete.map((c) => c.id);
    const milkDel = await prisma.milkRecord.deleteMany({ where: { cowId: { in: ids } } });
    const reproDel = await prisma.reproductionRecord.deleteMany({ where: { cowId: { in: ids } } });
    await prisma.cow.deleteMany({ where: { id: { in: ids } } });
    console.log(`\n  Wiped ${milkDel.count} milk records, ${reproDel.count} repro records, ${toDelete.length} cows`);
  }

  // Update matched in two passes to avoid unique-tag conflicts when
  // multiple cows are swapping tags ("Topten" → "Mw-001" while
  // another row was already "Mw-001"). First pass: prefix with __tmp_
  // so all unique constraints free up; second pass: set the real tag.
  for (const { id } of updates) {
    await prisma.cow.update({
      where: { id },
      data: { tag: `__tmp_${id.slice(0, 8)}` },
    });
  }
  for (const { id, data } of updates) {
    await prisma.cow.update({ where: { id }, data });
  }

  for (const data of creates) {
    await prisma.cow.create({
      data: {
        ...data,
        dateOfBirth: new Date('2020-01-01'),
      },
    });
  }

  const finalCows = await prisma.cow.count();
  const finalMilk = await prisma.milkRecord.count();
  console.log(`\nDone. Final: ${finalCows} cows, ${finalMilk} milk records preserved.`);
}

main()
  .catch((e) => {
    console.error('Seed failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
