# Mwirigi Farm Backend

## Reproduction module

The reproduction module tracks AI (artificial insemination) and calving events
for dairy cows. The list view (`GET /api/reproduction`) returns one row per cow
that has any reproduction history; the table in the Flutter dairy screen reads
this directly.

### Endpoints

| Method | Path                          | Auth roles                | Purpose |
|--------|-------------------------------|---------------------------|---------|
| GET    | `/api/reproduction`           | any authenticated         | List view (one row per cow). Supports `?search=` (cow tag, case-insensitive contains), `?status=` (`PENDING`/`CONFIRMED`/`OPEN`/`ABORTED`), `?page=`, `?limit=`. |
| POST   | `/api/reproduction`           | CEO, DAIRY_MANAGER, VET   | Create AI or CALVING event (discriminator: `eventType`). |
| GET    | `/api/reproduction/:cowId`    | any authenticated         | Full event history for one cow. |
| PATCH  | `/api/reproduction/:id`       | CEO, DAIRY_MANAGER, VET   | Update `pregnancyStatus`, `pregnancyCheckDate`, or `notes` on a single record. Auto-fills `expectedCalvingDate` when status flips to `CONFIRMED` (see business rules). |
| DELETE | `/api/reproduction/:id`       | CEO                       | Soft delete (sets `deletedAt`). |

### Request shapes

**Create AI event** — `POST /api/reproduction`

```json
{
  "eventType": "AI",
  "tag": "MW-100",
  "eventDate": "2026-05-06",
  "sireCode": "SIRE-417",
  "notes": "optional"
}
```

`tag` is resolved server-side to a cow id. Pass `cowId` (UUID) instead if you
already have it. `pregnancyStatus` is set to `PENDING` automatically;
`expectedCalvingDate` is left null until the AI is confirmed.

**Create CALVING event** — `POST /api/reproduction`

```json
{
  "eventType": "CALVING",
  "tag": "MW-100",
  "eventDate": "2026-05-06",
  "calfTag": "CALF-2605",
  "notes": "optional"
}
```

A CALVING insert also marks any active AI for that cow (`PENDING` or
`CONFIRMED`) as `OPEN`, so the cow leaves the active-pregnancy state.

**Update pregnancy status** — `PATCH /api/reproduction/:id`

```json
{ "pregnancyStatus": "CONFIRMED", "pregnancyCheckDate": "2026-06-01" }
```

### Business rules

- **283-day gestation.** When an AI record's `pregnancyStatus` is updated to
  `CONFIRMED`, the service auto-fills `expectedCalvingDate = eventDate + 283 days`
  in the same write. Other status transitions leave `expectedCalvingDate`
  untouched.
- **21-day duplicate guard.** Two AI events for the same cow within 21 days
  are rejected with `400` and a message naming the previous event date.
- **Calving resets pregnancy.** A CALVING insert wraps in a transaction with an
  `updateMany` that flips any non-deleted, non-OPEN AI records for the cow to
  `OPEN`. The cow appears in the list view with no active pregnancy after this.
- **`lifetimeCalvesCount` is computed**, not stored — it's the count of
  non-deleted CALVING records for the cow, returned on the list view.

### Seed

```powershell
node prisma/seed.js
```

Idempotent. Creates 3 sample cows (`Mw-012`, `Mw-035`, `Mw-082`) and matching
reproduction history (AI events with various pregnancy statuses, plus calving
records) so the dairy screen renders with realistic data on a fresh install.
