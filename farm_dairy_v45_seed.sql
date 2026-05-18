-- =====================================================================
-- Dairy reconciliation — v4.5 (full 56-cow allocation per herd manager)
-- =====================================================================
-- Three things happen in this file:
--
--   1. Two missing dairy houses (D and Maternity) are added so the full
--      6-house layout (A · B · C · D · E · F + Maternity) exists in the
--      DB, not just in the v4.5 HTML mockup.
--
--   2. All 56 existing Cow rows get their nickname / houseId / workerId
--      updated to match the herd-manager's allocation list:
--        House A=7, B=9, C=10, D=5, E=8, F=4 (43 housed) + Maternity=13
--      Tags (Mw-001..Mw-042 + 14 named) are kept so that milk records,
--      reproduction history and any other foreign keys stay valid.
--      Cows assigned to Maternity get status='PREGNANT'; all others
--      stay MILKING. The 13th maternity cow (the one missing from the
--      herd manager's typed list) is "Olympic" — explicitly carried as
--      a spelling variant in the HTML mockup's `houseByName` map.
--
--   3. Four CALVING ReproductionRecords (CALF-001..CALF-004) are added
--      so the v4.5 Calves Register UI has data. Dams are looked up by
--      their *post-rename* nicknames (Topten, Rose, Mrefu, Makena),
--      so this section must run AFTER the cow renames.
--
-- Idempotent: every UPDATE is keyed by tag; INSERTs ON CONFLICT.
-- Re-running this file converges to the same final state.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. New House rows: Dairy D + Dairy Maternity
-- ---------------------------------------------------------------------
INSERT INTO public."House"
  (id, name, type, capacity, "createdAt", "updatedAt", color, "birdCount")
VALUES
  ('d4ad4ad4-0000-4000-8000-d4ad4ad4d4ad',
   'Dairy D',         'Dairy', 14, NOW(), NOW(), '#0F6E56', 0),
  ('a4e4a4e4-0000-4000-8000-a4e4a4e4a4e4',
   'Dairy Maternity', 'Dairy', 20, NOW(), NOW(), '#854F0B', 0)
ON CONFLICT (name) DO UPDATE
  SET "updatedAt" = NOW(),
      color       = EXCLUDED.color;

-- ---------------------------------------------------------------------
-- 2. Cow renames + house/worker reassignment
-- ---------------------------------------------------------------------
-- A repeatable macro pattern via a CTE — for each (tag, nickname, house,
-- worker) row, look up the house and worker UUIDs by name and apply the
-- update. Status flips to PREGNANT when the cow lands in Maternity;
-- everything else becomes MILKING.

WITH allocation (tag, nickname, house_name, worker_name) AS (
  VALUES
    -- HOUSE A (7 cows)
    ('Mrefu',      'Mrefu',      'Dairy A',         'Musyoka'),
    ('Topten',     'Topten',     'Dairy A',         'Ronald'),
    ('Mw-003',     'Tamara',     'Dairy A',         'Joshua'),
    ('Nyambura',   'Nyambura',   'Dairy A',         'Ivan'),
    ('Mw-002',     'Dereva',     'Dairy A',         'Jacob'),
    ('Makena',     'Makena',     'Dairy A',         'Ronald'),
    ('Orion',      'Orion',      'Dairy A',         'Ronald'),
    -- HOUSE B (9 cows)
    ('Mw-004',     'Shiru',      'Dairy B',         'Jacob'),
    ('Reloy',      'Reloy',      'Dairy B',         'Musyoka'),
    ('Mw-005',     'Mwiru',      'Dairy B',         'Mukisa'),
    ('Mw-006',     'Katiba',     'Dairy B',         'Toby'),
    ('Mw-007',     'Vera',       'Dairy B',         'Mukisa'),
    ('Mw-008',     'Munyaka',    'Dairy B',         'Karis'),
    ('Mw-009',     'Sela',       'Dairy B',         'John'),
    ('Mw-010',     'Sandra',     'Dairy B',         'Mukisa'),
    ('Mw-011',     'Tanya',      'Dairy B',         'Sam'),
    -- HOUSE C (10 cows)
    ('Mw-001',     'Daisy',      'Dairy C',         'Jacob'),
    ('Karendi',    'Karendi',    'Dairy C',         'Joshua'),
    ('Rose',       'Rose',       'Dairy C',         'Ivan'),
    ('Mw-012',     'Favour',     'Dairy C',         'Ronald'),
    ('Angela',     'Angela',     'Dairy C',         'Joshua'),
    ('Tesn-j',     'Tesn.J',     'Dairy C',         'Joshua'),
    ('Mw-013',     'Caro',       'Dairy C',         'Toby'),
    ('Mw-014',     'Monica A',   'Dairy C',         'Nick'),
    ('Meni',       'Meni',       'Dairy C',         'Musyoka'),
    ('Mw-015',     'Mary',       'Dairy C',         'Nick'),
    -- HOUSE D (5 cows) — new house
    ('Mw-016',     'Monica B',   'Dairy D',         'Ivan'),
    ('Mw-017',     'Milly',      'Dairy D',         'John'),
    ('Mw-018',     'Marion',     'Dairy D',         'John'),
    ('Mw-019',     'Melvin',     'Dairy D',         'Jacob'),
    ('Mw-020',     'Star',       'Dairy D',         'Sam'),
    -- HOUSE E (8 cows)
    ('Kirote',     'Kirote',     'Dairy E',         'Ronald'),
    ('Mw-021',     'Mumbi',      'Dairy E',         'Ivan'),
    ('Kachumi',    'Kachumi',    'Dairy E',         'Musyoka'),
    ('Mw-022',     'Champion',   'Dairy E',         'Nick'),
    ('Cicilia',    'Cicilia',    'Dairy E',         'Musyoka'),
    ('Mw-023',     'Dasher',     'Dairy E',         'Sam'),
    ('Mw-024',     'Kagendo',    'Dairy E',         'Sam'),
    ('Mw-025',     'Max',        'Dairy E',         'John'),
    -- HOUSE F (4 cows)
    ('Mw-026',     'Karambu',    'Dairy F',         'Toby'),
    ('Mw-027',     'Makose',     'Dairy F',         'Mukisa'),
    ('Mw-028',     'Shiku',      'Dairy F',         'Karis'),
    ('Mw-029',     'Tanya Black','Dairy F',         'Karis'),
    -- MATERNITY (13 cows — 12 listed + Olympic as 13th, the missing one)
    ('Mw-030',     'Muthoni',    'Dairy Maternity', 'Toby'),
    ('Mw-031',     'Princess',   'Dairy Maternity', 'Nick'),
    ('Mw-032',     'Caspa',      'Dairy Maternity', 'Ronald'),
    ('Mw-033',     'Smart',      'Dairy Maternity', 'Musyoka'),
    ('Mw-034',     'Jerica',     'Dairy Maternity', 'Nick'),
    ('Mw-035',     'Olimpic',    'Dairy Maternity', 'John'),
    ('Mw-036',     'Blessing',   'Dairy Maternity', 'Toby'),
    ('Mw-037',     'Summer',     'Dairy Maternity', 'Sam'),
    ('Mw-038',     'Madox',      'Dairy Maternity', 'Joshua'),
    ('Mw-039',     'Oscar',      'Dairy Maternity', 'Ivan'),
    ('Mw-040',     'Twin',       'Dairy Maternity', 'Mukisa'),
    ('Mw-041',     'Lucky',      'Dairy Maternity', 'Jacob'),
    ('Mw-042',     'Olympic',    'Dairy Maternity', 'John')
)
UPDATE public."Cow" c
SET
  nickname    = a.nickname,
  "houseId"   = h.id,
  "workerId"  = w.id,
  status      = CASE
                  WHEN a.house_name = 'Dairy Maternity' THEN 'PREGNANT'::"CowStatus"
                  ELSE 'MILKING'::"CowStatus"
                END,
  "updatedAt" = NOW()
FROM allocation a
JOIN public."House"  h ON h.name = a.house_name
JOIN public."Worker" w ON w.name = a.worker_name
WHERE c.tag = a.tag;

-- ---------------------------------------------------------------------
-- 3. CALVING reproduction records — 4 active calves (CALF-001..CALF-004)
-- ---------------------------------------------------------------------
-- Dams are looked up by their NEW nicknames (post-rename above).
-- 26-001 (the feedlot-transferred calf) is not seeded here because
-- once weaned and tagged into the feedlot 26-series it belongs to
-- the feedlot register, not the dairy calves register.

INSERT INTO public."ReproductionRecord"
  (id, "cowId", "eventType", "eventDate",
   "sireCode", "pregnancyStatus",
   "calfTag", "calfSex", "calfBirthWeightKg", "calvingEase", "calvingFate",
   notes, "createdAt", "updatedAt")
SELECT
  'b1a1f001-0000-4000-8000-000000000001',
  c.id, 'CALVING', '2026-04-10 00:00:00',
  'AI Code A42', 'PENDING',
  'CALF-001', 'F', 34, 2, 'Heifer to herd',
  'Bottle-fed colostrum within 4h. Healthy.',
  NOW(), NOW()
FROM public."Cow" c WHERE c.nickname = 'Topten'
ON CONFLICT (id) DO UPDATE SET
  "cowId"             = EXCLUDED."cowId",
  "calfTag"           = EXCLUDED."calfTag",
  "calfSex"           = EXCLUDED."calfSex",
  "calfBirthWeightKg" = EXCLUDED."calfBirthWeightKg",
  "sireCode"          = EXCLUDED."sireCode",
  notes               = EXCLUDED.notes,
  "updatedAt"         = NOW();

INSERT INTO public."ReproductionRecord"
  (id, "cowId", "eventType", "eventDate",
   "sireCode", "pregnancyStatus",
   "calfTag", "calfSex", "calfBirthWeightKg", "calvingEase", "calvingFate",
   notes, "createdAt", "updatedAt")
SELECT
  'b1a1f001-0000-4000-8000-000000000002',
  c.id, 'CALVING', '2026-03-22 00:00:00',
  'AI Code B17', 'PENDING',
  'CALF-002', 'F', 31, 2, 'Heifer to herd',
  'Day 47 — on dry matter + milk',
  NOW(), NOW()
FROM public."Cow" c WHERE c.nickname = 'Rose'
ON CONFLICT (id) DO UPDATE SET
  "cowId"             = EXCLUDED."cowId",
  "calfTag"           = EXCLUDED."calfTag",
  "calfSex"           = EXCLUDED."calfSex",
  "calfBirthWeightKg" = EXCLUDED."calfBirthWeightKg",
  "sireCode"          = EXCLUDED."sireCode",
  notes               = EXCLUDED.notes,
  "updatedAt"         = NOW();

INSERT INTO public."ReproductionRecord"
  (id, "cowId", "eventType", "eventDate",
   "sireCode", "pregnancyStatus",
   "calfTag", "calfSex", "calfBirthWeightKg", "calvingEase", "calvingFate",
   notes, "createdAt", "updatedAt")
SELECT
  'b1a1f001-0000-4000-8000-000000000003',
  c.id, 'CALVING', '2026-02-14 00:00:00',
  'AI Code A42', 'PENDING',
  'CALF-003', 'M', 36, 3, 'Bull → feedlot at weaning',
  'Day 83 — ready for vaccinations and weaning soon',
  NOW(), NOW()
FROM public."Cow" c WHERE c.nickname = 'Mrefu'
ON CONFLICT (id) DO UPDATE SET
  "cowId"             = EXCLUDED."cowId",
  "calfTag"           = EXCLUDED."calfTag",
  "calfSex"           = EXCLUDED."calfSex",
  "calfBirthWeightKg" = EXCLUDED."calfBirthWeightKg",
  "sireCode"          = EXCLUDED."sireCode",
  notes               = EXCLUDED.notes,
  "updatedAt"         = NOW();

INSERT INTO public."ReproductionRecord"
  (id, "cowId", "eventType", "eventDate",
   "sireCode", "pregnancyStatus",
   "calfTag", "calfSex", "calfBirthWeightKg", "calvingEase", "calvingFate",
   notes, "createdAt", "updatedAt")
SELECT
  'b1a1f001-0000-4000-8000-000000000004',
  c.id, 'CALVING', '2026-04-25 00:00:00',
  'AI Code A42', 'PENDING',
  'CALF-004', 'F', 32, 2, 'Heifer to herd',
  'Day 13. Doing well.',
  NOW(), NOW()
FROM public."Cow" c WHERE c.nickname = 'Makena'
ON CONFLICT (id) DO UPDATE SET
  "cowId"             = EXCLUDED."cowId",
  "calfTag"           = EXCLUDED."calfTag",
  "calfSex"           = EXCLUDED."calfSex",
  "calfBirthWeightKg" = EXCLUDED."calfBirthWeightKg",
  "sireCode"          = EXCLUDED."sireCode",
  notes               = EXCLUDED.notes,
  "updatedAt"         = NOW();

COMMIT;
