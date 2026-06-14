# Mwirigi Farm — Changelog

---

## 11 June 2026

### 1. Piggery — Pen Release Workflow

- Replaced Edit / Delete row buttons with a **3-dot overflow menu** (Edit Pen / Release Pigs / Delete Pen)
- Added **Release Pen dialog**: auto-filled pen info, total live weight input, live net weight display, destination dropdown (Farmers Choice / Local Sale / Other), conditional fields per destination, notes field
- Weight formula: `finalWeight = totalWeight − (30 kg × pig count)`
- `finalWeight` and `deadWeightDeduction` stored in the database at release time (snapshot, not recomputed)
- Destination routing: Farmers Choice → creates `FarmersChoiceDelivery` + optional `Revenue`; Local Sale → `Revenue` only
- Race condition guard: uses `updateMany({ where: { id, releasedAt: null } })` inside a Prisma transaction so duplicate releases are rejected atomically
- **Release Summary Modal** shown after a successful release: displays live weight, dead-weight deduction, net weight, destination, and amount recorded
- Status badge on pen rows: **Released** (blue) / **Sale-ready** (green) / **Active** (amber)
- Audit trail written for Edit, Release, and Delete actions
- Schema updated: added `totalWeight`, `deadWeightDeduction`, `finalWeight`, `releasedAt`, `releaseDestination`, `releaseNotes`, `revenueId` fields to `FattenPen`
- New backend route: `POST /api/piggery/pens/:id/release`

### 2. CEO Dashboard — KPI Accuracy

- **Milk sold** KPI now shows net sellable milk: `gross milk − calves consumption − bucket weight − household use` (uses `getTodayNetSummary` from the dairy service)
- Gross milk still shown as a sub-label for reference
- **Crates sold** KPI now shows net sellable crates: `floor((totalEggs − householdEggs) / 30)`
- Gross egg crates still shown as a sub-label
- Both KPI percentage bars now track against net figures, not gross

### 3. Sales Pill — Layers & Dairy

- Shared **SalesPage** widget used by both Layers (egg crate sales) and Dairy (milk litre sales)
- KPI strip: today's sale count · total quantity · total revenue
- Sales list showing each transaction as a card, newest first
- **Log Sale** FAB opens `LogSaleDialog` — after a successful POST the list reloads automatically
- Period filter bar (UI in place; backend filtering wired on demand)
- New backend module: `sales.service.js`, `sales.controller.js`, `sales.routes.js`, `sales.validation.js`
- New Flutter model: `sales.dart` with `Sale`, `SaleList`, `SalesTodaySummary`
- New `ApiService` methods: `getSales()`, `getSalesSummary()`, `logSale()`

### 4. Health — Vaccination Edit & Filters

- **Edit button** on every vaccination row — opens `EditVaccineDialog` to update vaccine name, date, next due date, and notes
- Vaccination schedule table filters: filters applied client-side on the loaded records
- Responsive layout: desktop shows a full data table, mobile shows cards — edit button present on both

### 5. Staff Module — Employee Pill

- New **Employees tab** (`EmployeeList`) — full staff directory showing active and released workers
- Filter pills: Active / Released / All, by department (Dairy, Layers, Piggery, Feedlot, Admin, Feeds, Ngushish), and a live search bar
- **Edit Employee dialog** (`EditEmployeeDialog`) — edits HR fields: department, job title, phone number, salary type (Daily / Monthly), daily rate, monthly salary; sends only changed fields via `PATCH /staff/:id`
- **Release Worker dialog** (`ReleaseWorkerDialog`) — terminates a worker with a reason dropdown (Contract Ended / Resigned / Dismissed / Retired / Seasonal Ended / Other), release date picker, and notes; record is preserved with `status = RELEASED`, nothing is deleted — mirrors the cow release workflow
- 3-dot overflow menu on each employee row: Edit / Release (hidden if already released)

### 6. Reports — PDF Download & Share

- All report pages (Dairy, Layers, Health) have **Download PDF** and **Share** action buttons in the app bar
- PDF generation handled by dedicated utilities: `dairy_report_pdf.dart`, `layers_report_pdf.dart`, `health_report_pdf.dart`
- Download opens the system print/save dialog; Share opens the OS share sheet
- `report_preview_page.dart` provides a shared preview wrapper used across report types

### 7. Reports — Activity & Audit Report

- New **Activities** pill in the Reports section (`activity_report_page.dart`)
- Loads from `GET /api/activity-log` — tracks all farm actions: creates, updates, deletes, releases
- Displayed as a **date-grouped timeline**
- Filters: date range (preset pills + custom picker) · module (All / Dairy / Layers / Health / Staff / Piggery) · action type (All / Created / Updated / Deleted)
- App bar actions: **Download PDF** and **Share** via `activity_report_pdf.dart`
- Captures audit events like pen releases, cow releases, staff releases, record deletions

### 8. Layers — Backdated Entry

- Daily entry form now has a **date picker** allowing entries up to 365 days in the past
- When a past date is selected, the form fetches that day's existing record from the backend and pre-fills all fields — so editing a past entry doesn't overwrite with blanks
- Opening stock for a backdated entry is seeded from the most recent record before the chosen date
- Backend `upsertDailyEntry` keys on `(houseId, date)` so backdated saves correctly update the right record

### 6. Piggery — Farmers Choice Dispatch Pill

- **Farmers 🚚 tab** added to the Piggery pill navigation (repurposed from the unused vaccination slot)
- Shows the full FC dispatch log: `fc_dispatch_log_card.dart`
- **Log FC Dispatch dialog** (`log_fc_dispatch_dialog.dart`) — records deliveries to Farmers Choice with weight, category, driver, and reference number
- Dispatch entries created automatically when a pen is released to `FARMERS_CHOICE` destination

### 7. Sales → Finance Revenue Integration

- Every `ProductSale` with `amountPaid > 0` **atomically creates a linked `Revenue` row** in the same transaction — no separate step needed
- Editing a sale (amount, quantity, date) **patches the linked Revenue row** automatically
- Deleting a sale **preserves the Revenue row** (SetNull cascade) so finance history is not lost
- Revenue category auto-mapped per module (Dairy → milk, Layers → eggs)
- Covers both Layers and Dairy sales modules

### 8. Dairy — Released Cows Excluded from Milking

- All milking queries filter `WHERE releasedAt IS NULL` — sold or dead cows drop out of milking lists immediately on release
- Released cows are **preserved in history** (milk records, health records) for reporting — nothing is deleted
- Release action (sale / death / culled) writes an audit log entry captured in the Activity Report
- Calf weaning also sets `releasedAt` on the calf's cow row if one exists, removing it from active herd lists

### 9. Finance — Revenue Pill

- New **Revenue tab** in the Finance page with:
  - Module filter chips: All / Dairy / Layers / Piggery / Ngushish / Feedlot / Doopers
  - Date range picker
  - KPI strip: Total Revenue / Dairy / Layers / Piggery
  - Full revenue data table: Date / Module / Category / Qty / Unit / Amount / Notes
- New `RevenueRow` model in Flutter
- New `GET /api/finance/revenue` endpoint with `unit`, `category`, `from`, `to`, `page`, `limit` query params
- New `getFinanceRevenue()` method in `ApiService`

---

## 12 June 2026

### 4. Auth Screens — Brand Logo

- Added the **farm logo** (`BrandLogo`, height 80) to the top of:
  - Forgot Password screen
  - Email Verification (OTP) screen
  - Reset Password (OTP) screen
- Matches the existing login page layout

### 5. Google Sign-In Fix

- **Root cause**: error code 10 (`DEVELOPER_ERROR`) — no Android OAuth client registered (only a web client existed in `google-services.json`)
- **Package rename**: changed app package from `com.example.frontend` → `com.mwirigifarm.app` (the default name conflicted with other Firebase projects sharing the same SHA-1)
  - Updated `android/app/build.gradle.kts` (`namespace` + `applicationId`)
  - Moved `MainActivity.kt` to the new package directory
- Registered SHA-1 fingerprint in Firebase under `com.mwirigifarm.app`
- Downloaded and replaced `google-services.json` — now includes `client_type: 1` (Android OAuth client)
- Added `serverClientId` to `GoogleSignIn()` in Flutter so `idToken` is always returned to the backend
- Fixed `GOOGLE_OAUTH_CLIENT_IDS` in `.env` — was pointing to a completely different Google project; corrected to the Firebase project's web client ID
- Added `google-services.json` to `.gitignore` and untracked it from git history

### 6. Email System Overhaul

- **Resend OTP endpoint wired up**: `resendOtp` existed in the service but had no controller or route — added `resendOtpController` and `POST /auth/resend-otp`
- **Flutter resend button was fake**: previously just showed a snackbar with no API call — replaced with a real call to `/auth/resend-otp` with a 60-second cooldown timer
- **Switched email provider from Resend → Gmail SMTP** via Nodemailer — Resend sandbox only delivers to the account owner's email, blocking all other users
- Sender changed to `thefarm.ke@gmail.com` with a Gmail App Password
- All OTP emails (signup verification, password reset, resend) now deliver to any email address

### 7. GitHub Setup

- Initialized remote repository at `https://github.com/DOREENKDAVID/mwirigi-farm`
- Resolved merge conflicts from remote initialization (kept all local changes)
- Pushed full codebase to `master`

---

## 14 June 2026

### 1. Piggery — Sow & Boar Release / Sell Workflow

**Backend**
- Added `releasedAt DateTime?`, `releaseReason String?`, `releaseNotes String?`, `releaseAmount Float?` to the `Pig` model in `schema.prisma`; schema pushed to NeonDB (`prisma db push`)
- `listSows` and `listBoars` queries now filter `releasedAt: null` so released animals drop out of active registers immediately
- New service function `releasePig(id, input, actorId)` in `piggery.service.js`:
  - Pre-flight check: pig must exist, not soft-deleted, not already released
  - Atomic Prisma `$transaction`: creates `Revenue` row (`unit: "Piggery"`, `category: "PIG_SALES"`) when `releaseAmount > 0`, then `updateMany` with race-condition guard, then writes audit log
- New Zod schema `releasePigSchema` in `piggery.validation.js` (releaseReason enum, optional amount / notes / date)
- New controller `releasePig` in `piggery.controller.js` with 404 / 409 / 400 error handling
- New route `POST /api/piggery/pigs/:id/release` (roles: CEO, PIGGERY_MANAGER)

**Flutter**
- Added `releasedAt` and `releaseReason` fields to `Sow` and `Boar` models in `piggery.dart`
- New `ApiService.releasePig(id, body)` method hitting the new route
- New `release_pig_dialog.dart` — reason dropdown (Sold / Culled / Died / Old Age / Injured / Other), optional sale amount field (shown only when Sold), release date picker, notes; confirm button styled red
- `sow_register_table.dart`: replaced Edit + Delete icon buttons (`_ActionIcons`) with a **3-dot `PopupMenuButton`** (`_SowRowActions`) offering Edit Sow / Release-Sell / Delete
- `piggery_page.dart`:
  - Added `_openReleaseBoar(Boar b)` method
  - Added `onRelease` parameter to `_BoarsTable`
  - Replaced `_RowActions` in the boars DataTable with an inline `PopupMenuButton` (Edit Boar / Release-Sell / Delete)
  - Wired `onRelease: (b) => _openReleaseBoar(b)` in the tab switch

**Finance integration**
- Revenue created on pig release (`unit: "Piggery"`, `category: "PIG_SALES"`) automatically appears in the Finance → Revenue → Piggery KPI pill and revenue table — no additional wiring needed

**Activity Report integration**
- `writeAuditLog` called on every pig release (`entity: "Pig"`, `action: "RELEASE"`, `module: "Piggery"`) — events surface in the Activity Report under the Piggery module filter
- Added `RELEASE` to the action filter dropdown in `activity_report_page.dart` ("Released" label, purple badge `#5B2CA6`) so releases can be filtered specifically

### 2. Piggery — FC Pen Release Approval Workflow (State Machine)

Full request → approval → dispatch state machine for Farmers Choice pen deliveries, replacing the previous direct-release flow.

**Prisma schema additions** (pushed to NeonDB)

- `FattenPen` — added `pendingReleaseId String?` (plain string, tracks active in-flight request; cleared on approve/reject)
- New `Farm` model — single-row farm entity seeded at app startup with fixed UUID `00000000-0000-0000-0000-000000000001`
- New `ReleaseRequest` model — captures a worker's FC pen release request; status: `PENDING → APPROVED → DISPATCHED` (or `REJECTED`); stores `originalCount` and `originalAge` snapshots for restoration on rejection
- New `PendingDispatch` model — aggregation batch per `(farmId, category)`; status: `ACCUMULATING → DISPATCHED`; multiple batches can coexist for different categories
- New `DispatchLog` model — immutable record of a completed FC truck dispatch; optional link to `Revenue`; replaces `FarmersChoiceDelivery` going forward

**Backend service (`piggery.service.js`)**

- `ensureFarm()` — idempotent upsert called at app startup from `app.js`
- `releasePen()` — now throws for `FARMERS_CHOICE` ("use the approval workflow"); creates `DispatchLog` directly for `LOCAL_SALE` / `OTHER`
- `requestPenRelease(penId, input, actorId)` — creates `ReleaseRequest(PENDING)`, sets `pen.pendingReleaseId`; audit log action `RELEASE_REQUEST`
- `approveReleaseRequest(requestId, actorId)` — finds or creates an `ACCUMULATING` `PendingDispatch` for `farmId + category`; sets `pen.releasedAt`, clears `pendingReleaseId`; audit log action `APPROVE`
- `rejectReleaseRequest(requestId, input, actorId)` — sets status `REJECTED`, restores `pen.count` and `pen.age` from snapshots, clears `pendingReleaseId`; audit log action `REJECT`
- `listReleaseRequests(status)` — returns requests with embedded pen data
- `listPendingDispatches()` — returns `ACCUMULATING` batches with derived `pens[]`, `totalCount`, `requestIds[]`
- `confirmDispatch(pendingDispatchId, input, actorId)` — atomic transaction: creates `DispatchLog`, optionally creates `Revenue(unit:"Piggery", category:"ANIMAL_SALES")`, marks all requests `DISPATCHED`, closes the batch; audit log action `DISPATCH`
- `listDispatchLogs()` — reads from `DispatchLog` ordered newest first

**Backend API (new routes)**

| Method | Path | Roles |
|--------|------|-------|
| `POST` | `/api/piggery/pens/:id/request-release` | CEO, PIGGERY_MANAGER |
| `GET` | `/api/piggery/release-requests` | CEO, PIGGERY_MANAGER |
| `PATCH` | `/api/piggery/release-requests/:id/approve` | CEO, PIGGERY_MANAGER |
| `PATCH` | `/api/piggery/release-requests/:id/reject` | CEO, PIGGERY_MANAGER |
| `GET` | `/api/piggery/pending-dispatches` | CEO, PIGGERY_MANAGER |
| `POST` | `/api/piggery/dispatch/confirm` | CEO, PIGGERY_MANAGER |
| `GET` | `/api/piggery/dispatch-logs` | CEO, PIGGERY_MANAGER |

**Flutter models (`piggery.dart`)**

- `FattenPen` — added `pendingReleaseId String?` and computed getter `bool get isPendingRelease => pendingReleaseId != null && releasedAt == null`
- New `PenReleaseRequest` class with all request fields + `fromJson`
- New `PendingDispatchBatch` class with `pens List<String>`, `totalCount`, `requestIds List<String>` + `fromJson`
- New `DispatchLogEntry` class with all dispatch fields, `bool get hasRevenue` + `fromJson`

**Flutter services & dialogs**

- 7 new `ApiService` methods wired to the 7 new backend endpoints
- `ReleasePenDialog` restructured: destination shown first; FC path shows a lean request form (category + ageRange, no weight/amount — deferred to dispatch confirm); Local Sale / Other path shows the existing direct-release form. Button label: "Submit Request" for FC, "Confirm Release" for others
- New `DispatchConfirmDialog` — pre-filled from `PendingDispatchBatch` (read-only chip strip: pens / head / category); manager enters date, FC reference, driver, age range, amount; calls `ApiService.confirmDispatch()`; creates Revenue and closes the batch

**Flutter Farmers pill (`piggery_page.dart`)**

- Replaced `FcDispatchLogCard` with new `FarmersTab` widget
- Pen status badge priority: **⏳ Pending** (amber) > **Released** (blue) > **⚡ Sale-ready** (green) > Active

**`FarmersTab` layout (three sections)**

1. **Pending Requests** — loads `GET /release-requests?status=PENDING`; each request shows pen label, count, category, house, requested-at timestamp; Approve (green) and Reject (red outlined) action buttons; Reject opens an inline notes dialog; restores pen state on rejection
2. **Ready to Dispatch** — loads `GET /pending-dispatches`; each batch card shows total head, category, list of pens; tap → opens `DispatchConfirmDialog`; on confirm, revenue auto-created if amount > 0, batch closes and history refreshes
3. **Dispatch History** — loads `GET /dispatch-logs`; rendered as a scrollable `DataTable` (Date / Ref / Pens / Count / Category / Age / Driver / Amount); reference cell colour-coded: green pill if Revenue exists, amber if amount was zero; "Log dispatch" button for manual FC entries via `LogFcDispatchDialog`

**Finance & audit integration**

- `confirmDispatch` auto-creates `Revenue(unit:"Piggery", category:"ANIMAL_SALES")` when amount > 0 — surfaces immediately in Finance → Revenue → Piggery pill and KPI strip
- All state transitions write to `AuditLog` (reusing the existing `writeAuditLog` helper) — events appear in the Activity Report under the Piggery module filter with action labels `RELEASE_REQUEST`, `APPROVE`, `REJECT`, and `DISPATCH`
