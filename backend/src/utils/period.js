// =====================================================================
// Shared period resolver
// =====================================================================
// One source of truth for "today" / "yesterday" / "this week" / etc.
// Used by every analytics-style endpoint that accepts a `period` query
// param, so the same selection means the same window everywhere.
//
// Returns `{ start, end, prevStart, prevEnd, label }` so callers can
// build period-over-period comparisons without doing date math.
//
// Inspired by the dairy.reports.service version which inlined the
// same logic; that file now imports this util instead.

const DAY_MS = 24 * 60 * 60 * 1000;

const startOfDay = (d) => {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
};
const endOfDay = (d) => {
  const x = new Date(d);
  x.setHours(23, 59, 59, 999);
  return x;
};

// Sunday-based ISO-like week. Returns the start of the week
// containing `date` (Sun 00:00:00).
const startOfWeek = (date) => {
  const d = startOfDay(date);
  d.setDate(d.getDate() - d.getDay());
  return d;
};

const startOfMonth = (d) =>
  new Date(d.getFullYear(), d.getMonth(), 1);

// Supported preset wire-values. Frontend's PeriodPreset enum mirrors
// this set 1:1 — any change here must be propagated.
export const PERIOD_PRESETS = [
  "today",
  "yesterday",
  "week",
  "lastWeek",
  "month",
  "lastMonth",
  "quarter",
  "halfyear",
  "annual",
  "custom",
];

// Public entrypoint. `period` is the preset; for `custom`, callers
// must also supply `startDate` + `endDate`. Defaults to "month" if
// the preset is missing/unknown so a stale or empty query string
// still resolves to a useful window.
export const resolveRange = ({ period, startDate, endDate } = {}) => {
  const now = new Date();
  const today = startOfDay(now);
  let start;
  let end;
  let label;

  switch (period) {
    case "today": {
      start = startOfDay(today);
      end = endOfDay(today);
      label = "Today";
      break;
    }
    case "yesterday": {
      const y = new Date(today.getTime() - DAY_MS);
      start = startOfDay(y);
      end = endOfDay(y);
      label = "Yesterday";
      break;
    }
    case "week": {
      // Last 7 days ending today, inclusive. Matches how the existing
      // dairy 7-day trend cards bucket data so the chart and the KPI
      // line up.
      end = endOfDay(today);
      start = startOfDay(new Date(today.getTime() - 6 * DAY_MS));
      label = "This week";
      break;
    }
    case "lastWeek": {
      // The 7 days immediately preceding the current 7-day window —
      // pairs with "week" so a side-by-side comparison is symmetric.
      end = endOfDay(new Date(today.getTime() - 7 * DAY_MS));
      start = startOfDay(new Date(today.getTime() - 13 * DAY_MS));
      label = "Last week";
      break;
    }
    case "month": {
      start = startOfMonth(today);
      end = endOfDay(today);
      label = "This month";
      break;
    }
    case "lastMonth": {
      start = new Date(today.getFullYear(), today.getMonth() - 1, 1);
      end = endOfDay(new Date(today.getFullYear(), today.getMonth(), 0));
      label = "Last month";
      break;
    }
    case "quarter": {
      const qStart = Math.floor(today.getMonth() / 3) * 3;
      start = new Date(today.getFullYear(), qStart, 1);
      end = endOfDay(today);
      label = "This quarter";
      break;
    }
    case "halfyear": {
      const hStart = today.getMonth() < 6 ? 0 : 6;
      start = new Date(today.getFullYear(), hStart, 1);
      end = endOfDay(today);
      label = "This half-year";
      break;
    }
    case "annual": {
      start = new Date(today.getFullYear(), 0, 1);
      end = endOfDay(today);
      label = "This year";
      break;
    }
    case "custom": {
      if (!startDate || !endDate) {
        throw new Error("custom period requires startDate and endDate");
      }
      start = startOfDay(new Date(startDate));
      end = endOfDay(new Date(endDate));
      if (end < start) throw new Error("endDate must be on or after startDate");
      label = "Custom range";
      break;
    }
    default: {
      // Default to "month" so an empty / unrecognised query param
      // still returns a useful payload rather than 400'ing.
      start = startOfMonth(today);
      end = endOfDay(today);
      label = "This month";
    }
  }

  // Previous-period window = the same-length window ending the
  // instant before `start`. For preset windows whose semantics
  // already imply a "previous" (e.g. lastWeek pairs with week) this
  // is still the right thing — the comparison is always "this period
  // vs the immediately-preceding span of equal length".
  const lenMs = end.getTime() - start.getTime();
  const prevEnd = new Date(start.getTime() - 1);
  const prevStart = new Date(prevEnd.getTime() - lenMs);
  return {
    start,
    end,
    prevStart: startOfDay(prevStart),
    prevEnd: endOfDay(prevEnd),
    label,
  };
};

// Convenience for endpoints that don't care about previous-period.
export const dateOnly = (range) => ({ start: range.start, end: range.end });

// Compute a delta percentage with the same null-guard semantics the
// dairy reports use: returns `null` (not 0) when `prev` was zero so
// the UI can show "—" instead of a misleading "0%".
export const deltaPct = (current, prev) =>
  prev > 0 ? Number((((current - prev) / prev) * 100).toFixed(1)) : null;
