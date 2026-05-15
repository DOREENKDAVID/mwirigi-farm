-- Reminders are a virtual feed (composed from existing tables on every
-- read). This table only persists user-side overrides — completion and
-- snooze state — keyed by a stable syntheticId.
CREATE TABLE "ReminderOverride" (
  "id"            TEXT NOT NULL,
  "syntheticId"   TEXT NOT NULL,
  "status"        TEXT NOT NULL,                      -- "DONE" | "SNOOZED"
  "completedAt"   TIMESTAMP(3),
  "snoozedUntil"  TIMESTAMP(3),
  "notes"         TEXT,
  "completedById" TEXT,
  "createdAt"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"     TIMESTAMP(3) NOT NULL,

  CONSTRAINT "ReminderOverride_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ReminderOverride_syntheticId_key" ON "ReminderOverride"("syntheticId");
CREATE INDEX "ReminderOverride_status_idx" ON "ReminderOverride"("status");

ALTER TABLE "ReminderOverride"
  ADD CONSTRAINT "ReminderOverride_completedById_fkey"
  FOREIGN KEY ("completedById") REFERENCES "User"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
