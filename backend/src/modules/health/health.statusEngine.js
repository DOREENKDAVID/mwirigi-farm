// =====================================================================
// HEALTH STATUS ENGINE
// =====================================================================
// Pure functions only. No DB calls — feed in the protocol + records and
// today's date, get back status + nextDue + lastDone display strings.
//
// Centralized so controllers/services never recompute the logic inline,
// per the user's spec point 2.
//
// Status values (subset of VaccinationStatus enum):
//   DONE              — current cycle is covered by a record
//   DUE_WINDOW_OPEN   — annual cycle is in (or past) its allowedMonths,
//                       no record yet for this cycle
//   DUE_NOW           — recurring cycle: nextDue <= today (also when
//                       brooder vaccine is in its day-window)
//   DUE_SOON          — within DUE_SOON_HORIZON_DAYS of next due
//   UPCOMING          — further than DUE_SOON_HORIZON_DAYS
//
// Two horizons:
//   DUE_SOON_HORIZON_DAYS — for the schedule pill colour (30 days).
//   DUE_7D_HORIZON_DAYS   — for the "Vaccines due (7d)" KPI count (7).

export const DUE_SOON_HORIZON_DAYS = 30;
export const DUE_7D_HORIZON_DAYS = 7;

const startOfDay = (d) => {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
};

const daysBetween = (a, b) =>
  Math.floor((startOfDay(b).getTime() - startOfDay(a).getTime()) / 86_400_000);

const addMonths = (d, n) => {
  const x = new Date(d);
  x.setMonth(x.getMonth() + n);
  return x;
};

const addYears = (d, n) => {
  const x = new Date(d);
  x.setFullYear(x.getFullYear() + n);
  return x;
};

const formatMonthYear = (d) =>
  d.toLocaleString("en-US", { month: "short", year: "numeric" });

const formatMonthRange = (months, year) => {
  if (!months?.length) return null;
  const sorted = [...months].sort((a, b) => a - b);
  const monthName = (m) =>
    new Date(year, m - 1, 1).toLocaleString("en-US", { month: "short" });
  if (sorted.length === 1) return `${monthName(sorted[0])} ${year}`;
  // Contiguous span like [2,3] → "Feb-Mar 2026"; non-contiguous → join.
  const isContiguous = sorted.every(
    (m, i) => i === 0 || m === sorted[i - 1] + 1,
  );
  if (isContiguous) {
    return `${monthName(sorted[0])}-${monthName(sorted[sorted.length - 1])} ${year}`;
  }
  return `${sorted.map(monthName).join("/")} ${year}`;
};

// ---------------------------------------------------------------------
// ANNUAL — calendar-locked to allowedMonths, repeats yearly
// ---------------------------------------------------------------------
//
// "Cycle" semantics: each calendar year is one cycle, anchored at the
// allowedMonths window. A record is considered to cover a cycle if its
// administeredAt falls within that year's window (or any time in that
// year, more permissively — for FMD, a Mar 2025 record covers the 2025
// cycle whether the window opened in Feb or Mar).
//
// Display:
//   lastDone — month + year of latest record
//   nextDue  — formatted month range for the next-pending cycle
const computeAnnual = ({ protocol, records, today }) => {
  const months = protocol.allowedMonths ?? [];
  const sorted = records.slice().sort((a, b) =>
    a.administeredAt > b.administeredAt ? -1 : 1,
  );
  const latest = sorted[0] ?? null;

  const todayYear = today.getFullYear();
  const currentMonth = today.getMonth() + 1;

  // Find the latest cycle year that has a record covering it.
  const coveredYears = new Set(
    sorted.map((r) => new Date(r.administeredAt).getFullYear()),
  );

  // Determine target cycle year:
  //   if today is at/after window start this year → current year
  //   else → previous year (cycle whose window is closest behind us)
  const earliestMonth = Math.min(...(months.length ? months : [12]));
  const cycleYear =
    currentMonth >= earliestMonth ? todayYear : todayYear - 1;

  const cycleCovered = coveredYears.has(cycleYear);
  const windowStart = new Date(cycleYear, earliestMonth - 1, 1);
  const latestMonth = Math.max(...(months.length ? months : [12]));
  const windowEnd = new Date(cycleYear, latestMonth, 0); // last day of last month
  const daysToWindowStart = daysBetween(today, windowStart);

  let status;
  if (cycleCovered) {
    status = "DONE";
  } else if (today >= windowStart) {
    // Window is open or has passed without a record.
    status = "DUE_WINDOW_OPEN";
  } else if (daysToWindowStart <= DUE_SOON_HORIZON_DAYS) {
    status = "DUE_SOON";
  } else {
    status = "UPCOMING";
  }

  // Display strings.
  const lastDoneStr = latest ? formatMonthYear(latest.administeredAt) : null;
  // Next-due display: if we're DONE, point at the next cycle (year+1).
  // Otherwise point at the current pending cycle.
  const nextDueYear = cycleCovered ? cycleYear + 1 : cycleYear;
  const nextDueStr = formatMonthRange(months, nextDueYear);
  const nextDueAt = new Date(nextDueYear, earliestMonth - 1, 1);
  const daysUntilDue = cycleCovered
    ? daysBetween(today, nextDueAt)
    : Math.max(0, daysToWindowStart);

  return {
    status,
    lastDone: lastDoneStr,
    lastDoneAt: latest ? new Date(latest.administeredAt).toISOString() : null,
    nextDue: nextDueStr,
    nextDueAt: nextDueAt.toISOString(),
    daysUntilDue,
    cycleStart: windowStart.toISOString(),
    cycleEnd: windowEnd.toISOString(),
  };
};

// ---------------------------------------------------------------------
// RECURRING — fixed interval (recurrenceMonths) from last administration
// ---------------------------------------------------------------------
const computeRecurring = ({ protocol, records, today }) => {
  const months = protocol.recurrenceMonths ?? 6;
  const sorted = records.slice().sort((a, b) =>
    a.administeredAt > b.administeredAt ? -1 : 1,
  );
  const latest = sorted[0] ?? null;

  if (!latest) {
    // No history at all — treat as DUE_NOW so it shows up in workflows.
    return {
      status: "DUE_NOW",
      lastDone: null,
      lastDoneAt: null,
      nextDue: formatMonthYear(today),
      nextDueAt: today.toISOString(),
      daysUntilDue: 0,
      cycleStart: today.toISOString(),
      cycleEnd: today.toISOString(),
    };
  }

  const last = new Date(latest.administeredAt);
  const overrideDate = latest.nextDueOverride
    ? new Date(latest.nextDueOverride)
    : null;
  const nextDueAt = overrideDate ?? addMonths(last, months);
  const daysUntilDue = daysBetween(today, nextDueAt);

  let status;
  if (daysUntilDue <= 0) {
    status = "DUE_NOW";
  } else if (daysUntilDue <= DUE_SOON_HORIZON_DAYS) {
    status = "DUE_SOON";
  } else {
    status = "DONE";
  }

  return {
    status,
    lastDone: formatMonthYear(last),
    lastDoneAt: last.toISOString(),
    nextDue: formatMonthYear(nextDueAt),
    nextDueAt: nextDueAt.toISOString(),
    daysUntilDue,
    cycleStart: last.toISOString(),
    cycleEnd: nextDueAt.toISOString(),
  };
};

// ---------------------------------------------------------------------
// Top-level dispatcher. Returns the schedule-row body that the composer
// merges with the brooder rows from layersUnit.service.
// ---------------------------------------------------------------------
export const computeProtocolView = ({ protocol, records, today }) => {
  const t = today ?? startOfDay(new Date());
  if (protocol.type === "ANNUAL") {
    return computeAnnual({ protocol, records, today: t });
  }
  if (protocol.type === "RECURRING") {
    return computeRecurring({ protocol, records, today: t });
  }
  // BROODER_DAY rows are NOT stored in DB; if one ever is, fall through
  // to UPCOMING so we don't crash.
  return {
    status: "UPCOMING",
    lastDone: null,
    lastDoneAt: null,
    nextDue: null,
    nextDueAt: null,
    daysUntilDue: null,
    cycleStart: null,
    cycleEnd: null,
  };
};

// ---------------------------------------------------------------------
// Helpers reused by KPI / compliance code.
// ---------------------------------------------------------------------
export { startOfDay, daysBetween, addMonths, addYears };

// Determines whether a row counts toward the "Vaccines due (7d)" KPI.
// User spec: count rows where status=DUE_NOW OR the due window opens
// within next 7 days. "DUE_WINDOW_OPEN" (already-open annual cycle) is
// excluded — it's actionable but not "opening soon".
export const countsForDue7d = (row) => {
  if (row.status === "DUE_NOW") return true;
  if (row.status === "DUE_SOON" && row.daysUntilDue != null) {
    return row.daysUntilDue >= 0 && row.daysUntilDue <= DUE_7D_HORIZON_DAYS;
  }
  return false;
};
