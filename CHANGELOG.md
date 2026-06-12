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
