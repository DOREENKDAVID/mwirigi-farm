// Pure helpers used by the feeds service. Kept outside service.js so the
// status thresholds can be unit-tested without touching Prisma.

export const FEED_STATUS = Object.freeze({
  CRITICAL: "CRITICAL",
  LOW: "LOW",
  ADEQUATE: "ADEQUATE",
});

// Defensive divide: a brand-new material has `dailyUseKg = 0` until the
// first consumption log is filed. We surface that as `null` rather than
// Infinity so the UI can render "—".
export const calculateDaysLeft = (stockOnHandKg, dailyUseKg) => {
  const stock = Number(stockOnHandKg) || 0;
  const daily = Number(dailyUseKg) || 0;
  if (daily <= 0) return null;
  return stock / daily;
};

// CRITICAL when daysLeft <= reorder lead time.
// LOW when daysLeft <= 2 * reorder lead time.
// ADEQUATE otherwise. Matches the inline footer rule in the HTML mockup
// exactly ("Default lead time = 5 days; tap any row to edit").
export const determineFeedStatus = (daysLeft, reorderLevelDays) => {
  if (daysLeft === null || daysLeft === undefined) return FEED_STATUS.ADEQUATE;
  const lead = Number(reorderLevelDays) > 0 ? Number(reorderLevelDays) : 5;
  if (daysLeft <= lead) return FEED_STATUS.CRITICAL;
  if (daysLeft <= lead * 2) return FEED_STATUS.LOW;
  return FEED_STATUS.ADEQUATE;
};

// kg threshold below which an alert/order should fire. The HTML mockup
// shows "Reorder when stock drops below 74 bags" for 14.67 bags/day × 5d,
// i.e. dailyUse * leadTime. We return the kg form so the UI can convert
// to packs if needed.
export const calculateReorderLevelKg = (dailyUseKg, reorderLevelDays) => {
  const daily = Number(dailyUseKg) || 0;
  const lead = Number(reorderLevelDays) > 0 ? Number(reorderLevelDays) : 5;
  return daily * lead;
};

// Single-shot view: the read shape every list/detail endpoint returns.
// Pulls the persisted columns through verbatim and decorates with the
// three computed fields.
export const decorateMaterial = (m) => {
  const daysLeft = calculateDaysLeft(m.stockOnHandKg, m.dailyUseKg);
  return {
    id: m.id,
    name: m.name,
    category: m.category,
    packSize: m.packSize,
    stockOnHandKg: m.stockOnHandKg,
    dailyUseKg: m.dailyUseKg,
    reorderLevelDays: m.reorderLevelDays,
    reorderAtKg: calculateReorderLevelKg(m.dailyUseKg, m.reorderLevelDays),
    daysLeft: daysLeft === null ? null : Number(daysLeft.toFixed(2)),
    status: determineFeedStatus(daysLeft, m.reorderLevelDays),
    supplier: m.supplier,
    costPerKg: m.costPerKg,
    createdAt: m.createdAt,
    updatedAt: m.updatedAt,
  };
};
