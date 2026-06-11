// ── Unified Lifecycle Layer ───────────────────────────────────────────────
//
// Each domain stores "is this entity still operational?" differently:
//
//   Livestock  releasedAt: null           → cow is in the active herd
//              releasedAt: <Date>         → removed (SOLD / DIED / etc.)
//
//   Staff      isActive: true             → worker is operational
//              isActive: false            → deactivated
//
// This file owns those mappings once. Import the named constants instead
// of repeating magic values in service files. Future modules add one entry
// here and inherit consistent behaviour across filters, reports, and audits.
//
// Usage in Prisma queries:
//   prisma.cow.findMany({ where: { ...LIFECYCLE.COW_ACTIVE, workerId } })
//   prisma.user.findMany({ where: LIFECYCLE.STAFF_ACTIVE })

// ── Filter constants (Prisma `where` fragments) ───────────────────────────

export const LIFECYCLE = {
  // Livestock ----------------------------------------------------------------
  COW_ACTIVE:   Object.freeze({ releasedAt: null }),
  COW_INACTIVE: Object.freeze({ NOT: { releasedAt: null } }),

  // Staff --------------------------------------------------------------------
  STAFF_ACTIVE:   Object.freeze({ isActive: true }),
  STAFF_INACTIVE: Object.freeze({ isActive: false }),
};

// ── State resolver ────────────────────────────────────────────────────────
//
// Maps a Prisma row to a unified three-state string.
// Reports can call this without knowing the domain's storage model.
//
//   getLifecycleState('cow',   cowRow)   → 'ACTIVE' | 'INACTIVE'
//   getLifecycleState('staff', userRow)  → 'ACTIVE' | 'INACTIVE'

export const getLifecycleState = (type, row) => {
  switch (type) {
    case "cow":
      return row.releasedAt ? "INACTIVE" : "ACTIVE";
    case "staff":
      return row.isActive ? "ACTIVE" : "INACTIVE";
    default:
      return "UNKNOWN";
  }
};

export const isEntityActive = (type, row) =>
  getLifecycleState(type, row) === "ACTIVE";
