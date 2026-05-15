// Reports catalog — composes 11 enterprise reports from existing
// service aggregators. Each builder returns the same DTO shape:
//
//   {
//     title, period, summary,
//     kpis:    [{label, value, unit?, target?, colorClass?}],
//     sections: [
//       { type: "narrative",         title, body },
//       { type: "table",             title, headers, rows },
//       { type: "progress",          title, items: [{label, pct, detail}] },
//       { type: "split",             title, items: [{label, value, sub, color}] },
//       { type: "session-breakdown", sessions: [{label, value, highlight?}] },
//       { type: "reminders",         title, limit },
//       { type: "comments",          title, lines },
//       { type: "signature",         roles: [...] },
//     ],
//     footnote?: string,
//   }
//
// The frontend renders any of these section types uniformly.

import prisma from "../../prisma/client.js";
import * as dairyService from "../dairy/dairy.service.js";
import * as layersService from "../layers/layers.service.js";
import * as piggeryService from "../piggery/piggery.service.js";
import * as feedsService from "../feeds/feeds.service.js";
import * as ngushishService from "../ngushish/ngushish.service.js";
import * as staffService from "../staff/staff.service.js";
import * as reminderService from "../reminders/reminders.service.js";
import { listVaccinations } from "../health/health.service.js";

const fmtToday = () =>
  new Date().toLocaleDateString("en-KE", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });

const fmtMonth = () =>
  new Date().toLocaleDateString("en-KE", {
    month: "long",
    year: "numeric",
  });

const fmtNum = (n) => {
  if (n == null) return "—";
  if (typeof n === "string") return n;
  if (n === Math.floor(n)) return n.toLocaleString("en-KE");
  return n.toFixed(1);
};

const commentSection = (title, lines = 5) => ({
  type: "comments",
  title,
  lines,
});

const signatureSection = (roles) => ({ type: "signature", roles });

// ===================================================================
// 1. Daily CEO Report
// ===================================================================

const buildDailyCeoReport = async () => {
  const [dairySummary, layersKpis, pigKpis, feedsDashboard, reminderKpis] =
    await Promise.all([
      dairyService.getSummary().catch(() => ({})),
      layersService.getKpis().catch(() => ({})),
      piggeryService.getKpis().catch(() => ({})),
      feedsService.getDashboardKpis().catch(() => ({})),
      reminderService.getKpis().catch(() => ({})),
    ]);

  const milkToday = dairySummary.milkToday ?? 0;
  const cratesToday = layersKpis.traysToday ?? 0;
  const beaconnersMonth = pigKpis.beaconnersMonth ?? 0;
  const maternity = dairySummary.maternityCount ?? 0;
  const overdue = reminderKpis.overdue ?? 0;
  const critFeed = feedsDashboard.criticalCount ?? 0;

  return {
    title: "Daily CEO Report",
    period: fmtToday(),
    summary:
      "Operational snapshot across all units. Read the headline numbers; act on the alerts.",
    kpis: [
      { label: "Milk today", value: fmtNum(milkToday), unit: "L", target: "/ 2,000 L target", colorClass: milkToday >= 1500 ? "g" : "a" },
      { label: "Egg crates", value: fmtNum(cratesToday), unit: "crates", target: "/ 700 target", colorClass: cratesToday >= 500 ? "g" : "a" },
      { label: "Beaconners MTD", value: fmtNum(beaconnersMonth), unit: "", target: "/ 100 target", colorClass: beaconnersMonth >= 100 ? "g" : "a" },
      { label: "Maternity", value: maternity, unit: "cows", target: "awaiting calving", colorClass: "b" },
      { label: "Overdue", value: overdue, unit: "items", target: "reminders past due", colorClass: overdue > 0 ? "r" : "g" },
      { label: "Critical feed", value: critFeed, unit: "materials", target: "below reorder level", colorClass: critFeed > 0 ? "r" : "g" },
    ],
    sections: [
      {
        type: "narrative",
        title: "Headline",
        body:
          "Today's operations are tracking against a 2,000 L milk target, " +
          "a 700-crate egg target, and a 100/month beaconners target.",
      },
      {
        type: "table",
        title: "Unit production snapshot",
        headers: ["Unit", "Today", "Status"],
        rows: [
          ["Dairy", `${fmtNum(milkToday)} L milk`, milkToday >= 1500 ? "On track" : "Below target"],
          ["Layers", `${fmtNum(cratesToday)} crates`, cratesToday >= 500 ? "On track" : "Below target"],
          ["Piggery", `${beaconnersMonth} beaconners MTD`, beaconnersMonth >= 100 ? "Target met" : "Building"],
        ],
      },
      { type: "reminders", title: "Items that need attention today", limit: 8 },
      commentSection("Manager observations / actions taken", 6),
      signatureSection(["Prepared by", "Reviewed by", "Approved by"]),
    ],
    footnote:
      "Generated automatically. Comments and signatures to be filled in by hand before filing.",
  };
};

// ===================================================================
// 2. Milk Production Records
// ===================================================================

const buildMilkRecordsReport = async () => {
  const [cows, todaySessions, todayNet] = await Promise.all([
    dairyService.getAllCows({}),
    dairyService.getTodaySessions().catch(() => ({ workers: [] })),
    dairyService.getTodayNetSummary().catch(() => ({})),
  ]);

  const milking = cows.filter((c) => c.status === "MILKING").length;
  const dry = cows.filter((c) => c.status === "DRY_OFF").length;
  const pregnant = cows.filter((c) => c.status === "PREGNANT").length;
  const sessions = todayNet.sessions ?? { AM: 0, MID: 0, PM: 0 };
  const dayNet = todayNet.dayNet ?? 0;

  const todayByCow = {};
  for (const w of todaySessions.workers ?? []) {
    for (const c of w.cows ?? []) {
      const e = c.entries ?? {};
      todayByCow[c.id] = (e.AM ?? 0) + (e.MID ?? 0) + (e.PM ?? 0);
    }
  }

  const statusLabel = (s) =>
    ({ MILKING: "Milking", DRY_OFF: "Dry", PREGNANT: "Pregnant",
       HEIFER: "Heifer", OPEN: "Open", SICK: "Sick" }[s] ?? s);

  const rows = cows
    .sort((a, b) => a.tag.localeCompare(b.tag, undefined, { numeric: true }))
    .map((c) => [
      c.tag,
      c.nickname ?? "—",
      c.breed ?? "—",
      c.house?.name ?? "—",
      c.worker?.name ?? "—",
      statusLabel(c.status),
      todayByCow[c.id] ? `${fmtNum(todayByCow[c.id])} L` : "—",
    ]);

  return {
    title: "Milk Production Records",
    period: fmtMonth(),
    summary:
      "Per-cow daily output, by house and worker. Maternity and dry cows shown for completeness.",
    kpis: [
      { label: "Total herd", value: cows.length, unit: "cows", target: "documented", colorClass: "g" },
      { label: "Currently milking", value: milking, unit: "", target: "in lactation", colorClass: "g" },
      { label: "In maternity", value: pregnant, unit: "", target: "awaiting calving", colorClass: "b" },
      { label: "Dry cows", value: dry, unit: "", target: "resting", colorClass: "a" },
      { label: "AM net", value: fmtNum(sessions.AM), unit: "L", target: "this morning", colorClass: "g" },
      { label: "Day net", value: fmtNum(dayNet), unit: "L", target: "all 3 sessions", colorClass: "g" },
    ],
    sections: [
      {
        type: "session-breakdown",
        sessions: [
          { label: "AM session", value: `${fmtNum(sessions.AM)} L` },
          { label: "Midday session", value: `${fmtNum(sessions.MID)} L` },
          { label: "PM session", value: `${fmtNum(sessions.PM)} L` },
          { label: "Day net (after deductions)", value: `${fmtNum(dayNet)} L`, highlight: true },
        ],
      },
      {
        type: "table",
        title: "Per-cow records",
        headers: ["Tag", "Name", "Breed", "House", "Worker", "Status", "Today"],
        rows,
      },
      commentSection("Vet observations / notes"),
      signatureSection(["Logged by (Dairy Manager)", "Reviewed by (Vet)"]),
    ],
  };
};

// ===================================================================
// 3. Egg Production Records
// ===================================================================

const buildEggRecordsReport = async () => {
  const [snapshot, brooderRows, layersKpis] = await Promise.all([
    layersService.getSnapshot().catch(() => []),
    prisma.brooder.findMany({ orderBy: { receivedDate: "desc" }, take: 1 }),
    layersService.getKpis().catch(() => ({})),
  ]);
  const brooder = brooderRows[0];
  const brooderAge = brooder
    ? Math.floor(
        (Date.now() - new Date(brooder.receivedDate).getTime()) / 86_400_000,
      )
    : 0;

  const totalBirds = layersKpis.totalBirds ?? 0;
  const cratesToday = layersKpis.traysToday ?? 0;
  const mortalityToday = layersKpis.mortalityToday ?? 0;
  const mortalityPct =
    totalBirds > 0 ? ((mortalityToday / totalBirds) * 100).toFixed(2) : "0";

  const houseRows = snapshot.map((h) => [
    h.name,
    fmtNum(h.currentStock ?? 0),
    fmtNum(h.trays ?? 0),
    fmtNum(h.feedKg ?? 0),
    h.phasingOut ? "⚠ Phasing out" : "Continuing",
  ]);
  if (snapshot.length > 0) {
    houseRows.push([
      "TOTAL",
      fmtNum(snapshot.reduce((s, h) => s + (h.currentStock ?? 0), 0)),
      fmtNum(snapshot.reduce((s, h) => s + (h.trays ?? 0), 0)),
      fmtNum(snapshot.reduce((s, h) => s + (h.feedKg ?? 0), 0)),
      "—",
    ]);
  }

  return {
    title: "Egg Production Records",
    period: fmtMonth(),
    summary:
      `${snapshot.length} layer house${snapshot.length === 1 ? "" : "s"}` +
      (brooder ? ` plus a ${fmtNum(brooder.population)}-chick brooder cohort.` : "."),
    kpis: [
      { label: "Layers in production", value: fmtNum(totalBirds), unit: "birds", target: snapshot.map((h) => h.name).join(" · "), colorClass: "g" },
      { label: "Brooder cohort", value: brooder ? fmtNum(brooder.population) : "—", unit: "chicks", target: brooder ? `Day ${brooderAge}` : "—", colorClass: "a" },
      { label: "Crates today", value: fmtNum(cratesToday), unit: "", target: "/ 700 target", colorClass: cratesToday >= 500 ? "g" : "a" },
      { label: "Mortality today", value: mortalityToday, unit: "birds", target: `${mortalityPct}%`, colorClass: parseFloat(mortalityPct) > 0.1 ? "r" : "g" },
    ],
    sections: [
      {
        type: "table",
        title: "Per-house production",
        headers: ["House", "Birds", "Crates today", "Feed (kg)", "Status"],
        rows: houseRows,
      },
      commentSection("Manager / vet notes"),
      signatureSection(["Logged by (Layers Manager)", "Reviewed by (Vet)"]),
    ],
  };
};

// ===================================================================
// 4. Vaccination Schedule
// ===================================================================

const buildVaccScheduleReport = async () => {
  const vaccs = await listVaccinations().catch(() => []);
  const rows = vaccs.map((v) => [
    v.vaccine,
    v.unit ?? "—",
    fmtNum(v.animals),
    v.lastDoneAt
      ? new Date(v.lastDoneAt).toLocaleDateString("en-KE", { day: "numeric", month: "short", year: "numeric" })
      : "—",
    v.nextDueAt
      ? new Date(v.nextDueAt).toLocaleDateString("en-KE", { day: "numeric", month: "short", year: "numeric" })
      : "—",
    v.status === "DONE" ? "Done"
      : v.status === "OVERDUE" ? "⚠ Overdue"
      : v.status === "DUE_NOW" ? "⚠ Due now"
      : v.status === "DUE_SOON" ? "Due soon"
      : v.status === "DUE_WINDOW_OPEN" ? "Due window open"
      : "Upcoming",
  ]);

  const done = vaccs.filter((v) => v.status === "DONE").length;
  const due = vaccs.filter((v) =>
    ["OVERDUE", "DUE_NOW", "DUE_WINDOW_OPEN", "DUE_SOON"].includes(v.status),
  ).length;
  const compliancePct = vaccs.length > 0 ? Math.round((done / vaccs.length) * 100) : 0;

  return {
    title: "Vaccination Schedule",
    period: fmtMonth(),
    summary:
      "Cross-unit vaccine schedule per vet protocol. Annual whole-herd vaccines are calendar-locked; brooder vaccines are tied to chick age.",
    kpis: [
      { label: "Total vaccines tracked", value: vaccs.length, unit: "", target: "across all units", colorClass: "g" },
      { label: "Done", value: done, unit: "", target: "on schedule", colorClass: "g" },
      { label: "Due / overdue", value: due, unit: "", target: "action needed", colorClass: due > 0 ? "r" : "g" },
      { label: "Compliance", value: `${compliancePct}%`, unit: "", target: "schedule adherence", colorClass: compliancePct >= 80 ? "g" : "a" },
    ],
    sections: [
      {
        type: "table",
        title: "Schedule",
        headers: ["Vaccine", "Unit", "Animals", "Last done", "Next due", "Status"],
        rows,
      },
      commentSection("Vet observations / drug batch numbers", 6),
      signatureSection(["Vaccinated by", "Verified by Vet", "Approved by Manager"]),
    ],
  };
};

// ===================================================================
// 5. Treatment Log
// ===================================================================

const buildTreatmentLogReport = async () => {
  const treatments = await prisma.treatment.findMany({
    where: { status: { in: ["ACTIVE", "IMPROVING"] } },
    orderBy: { startDate: "desc" },
  });
  const dairy = treatments.filter((t) => t.unit === "Dairy").length;
  const piggery = treatments.filter((t) => t.unit === "Piggery").length;
  const layers = treatments.filter((t) => t.unit === "Layers").length;

  const rows = treatments.map((t) => [
    t.tag,
    t.unit,
    t.diagnosis,
    t.medication,
    new Date(t.startDate).toLocaleDateString("en-KE", { day: "numeric", month: "short", year: "numeric" }),
    t.attendingVet ?? "—",
    t.status === "ACTIVE" ? "Active" : "Improving",
  ]);

  return {
    title: "Treatment Log",
    period: fmtMonth(),
    summary:
      "Active treatments under the supervision of the farm vet. Withdrawal periods must be observed before milk dispatch or animal sale.",
    kpis: [
      { label: "Under treatment", value: treatments.length, unit: "animals", target: "currently", colorClass: "a" },
      { label: "Dairy cases", value: dairy, unit: "", target: "", colorClass: "g" },
      { label: "Piggery cases", value: piggery, unit: "", target: "", colorClass: "g" },
      { label: "Layers cases", value: layers, unit: "", target: "", colorClass: "g" },
    ],
    sections: [
      {
        type: "table",
        title: "Active treatments",
        headers: ["Tag", "Unit", "Diagnosis", "Treatment", "Start", "Vet", "Status"],
        rows,
      },
      commentSection("Drug withdrawal periods / follow-up", 6),
      signatureSection(["Attending Vet", "Reviewed by Manager"]),
    ],
  };
};

// ===================================================================
// 6. Piggery Production Report
// ===================================================================

const buildPiggeryReport = async () => {
  const kpis = await piggeryService.getKpis().catch(() => ({}));
  return {
    title: "Piggery Production Report",
    period: fmtMonth(),
    summary:
      `${kpis.totalHead ?? 0} head on farm · ${kpis.totalSows ?? 0} sows · ` +
      "target 100 beaconners/month for Farmers Choice.",
    kpis: [
      { label: "Total head", value: fmtNum(kpis.totalHead ?? 0), unit: "", target: "all categories", colorClass: "g" },
      { label: "Sows", value: kpis.totalSows ?? 0, unit: "", target: `${kpis.nursingCount ?? 0} nursing · ${kpis.gestationCount ?? 0} gestation`, colorClass: "g" },
      { label: "Due in 30d", value: kpis.dueIn30 ?? 0, unit: "sows", target: "farrowing pens needed", colorClass: (kpis.dueIn30 ?? 0) > 5 ? "a" : "g" },
      { label: "Beaconners MTD", value: kpis.beaconnersMonth ?? 0, unit: "", target: "/ 100 target", colorClass: (kpis.beaconnersMonth ?? 0) >= 100 ? "g" : "a" },
    ],
    sections: [
      {
        type: "narrative",
        title: "This week priorities",
        body:
          (kpis.dueIn30 ?? 0) > 0
            ? `${kpis.dueIn30} sow${kpis.dueIn30 === 1 ? "" : "s"} due in the next 30 days — ensure farrowing pens are prepared.`
            : "No sows due in the next 30 days. Continue routine breeding programme.",
      },
      commentSection("Manager / vet notes", 6),
      signatureSection(["Logged by (Piggery Manager)", "Reviewed by Vet"]),
    ],
  };
};

// ===================================================================
// 7. Feeds Inventory Report
// ===================================================================

const buildFeedsReport = async () => {
  const dashboard = await feedsService.getDashboardKpis().catch(() => ({
    materials: [],
    criticalCount: 0,
    lowCount: 0,
    adequateCount: 0,
  }));
  const materials = dashboard.materials ?? [];
  const rows = materials.map((m) => [
    String(m.id ?? ""),
    m.name ?? "—",
    m.pack ?? "—",
    m.dailyUse != null ? `${fmtNum(m.dailyUse)} ${m.unit ?? ""}/d` : "—",
    `${fmtNum(m.stock ?? 0)} ${m.unit ?? ""}`,
    m.daysLeft != null && Number.isFinite(m.daysLeft) ? `${Math.round(m.daysLeft)} d` : "∞",
    m.reorderPoint != null ? `${fmtNum(m.reorderPoint)} ${m.unit ?? ""}` : "—",
    m.status === "critical" ? "⚠ Critical"
      : m.status === "low" ? "Low"
      : m.status === "adequate" ? "Adequate"
      : "—",
  ]);

  return {
    title: "Feeds Inventory",
    period: fmtMonth(),
    summary:
      "Raw materials tracked daily. Status flips to Critical when days-left ≤ lead time, Low when ≤ 2× lead time.",
    kpis: [
      { label: "Materials", value: materials.length, unit: "", target: "tracked", colorClass: "g" },
      { label: "Critical", value: dashboard.criticalCount ?? 0, unit: "", target: "order now", colorClass: "r" },
      { label: "Low", value: dashboard.lowCount ?? 0, unit: "", target: "monitor", colorClass: "a" },
      { label: "Adequate", value: dashboard.adequateCount ?? 0, unit: "", target: "healthy", colorClass: "g" },
    ],
    sections: [
      {
        type: "table",
        title: "Inventory snapshot",
        headers: ["#", "Material", "Pack", "Daily use", "Stock", "Days left", "Reorder at", "Status"],
        rows,
      },
      {
        type: "narrative",
        title: "Action items",
        body:
          (dashboard.criticalCount ?? 0) > 0
            ? `Order ${dashboard.criticalCount} material(s) immediately — they are below the reorder point.`
            : `No critical materials. ${dashboard.lowCount ?? 0} should be monitored over the next week.`,
      },
      commentSection("Procurement notes / suppliers contacted"),
      signatureSection(["Logged by (Feed Manager)", "Approved by Manager"]),
    ],
  };
};

// ===================================================================
// 7b. Ngusishi Crop Register
// ===================================================================
//
// Printable master-register snapshot mirroring the Ngusishi Farm Template
// (10 May 2026). One row per block with status, age, due date, season,
// and operator action note. Header KPIs roll the status buckets up so
// the manager can sign the page with confidence.

const fmtDateShort = (d) => {
  if (!d) return "—";
  const date = d instanceof Date ? d : new Date(d);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleDateString("en-KE", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
};

const buildNgushishCropRegisterReport = async () => {
  const result = await ngushishService
    .listCrops({ page: 1, limit: 200 })
    .catch(() => ({ items: [] }));
  const blocks = result.items ?? [];

  // Sort by block code so the printed register reads top-to-bottom A→D.
  const sorted = [...blocks].sort((a, b) =>
    (a.block ?? "").localeCompare(b.block ?? "", undefined, { numeric: true }),
  );

  const counts = { READY: 0, GROWING: 0, AWAITING: 0, INFRASTRUCTURE: 0 };
  let totalAcres = 0;
  for (const b of blocks) {
    if (b.status in counts) counts[b.status] += 1;
    totalAcres += b.acreage ?? 0;
  }

  const rows = sorted.map((b) => [
    b.block ?? "—",
    fmtNum(b.acreage ?? 0),
    b.name ?? "—",
    b.status === "READY"          ? "✅ Ready"
      : b.status === "GROWING"     ? "🌱 Growing"
      : b.status === "AWAITING"    ? "🟡 Awaiting"
      : b.status === "INFRASTRUCTURE" ? "🏠 Infra"
      : b.status,
    b.age ?? "—",
    b.status === "READY" ? "HARVEST NOW" : fmtDateShort(b.dueDate),
    b.season ?? "—",
    (b.actionNote ?? "").trim(),
  ]);

  return {
    title: "Ngusishi Crop Register",
    period: fmtMonth(),
    summary:
      `Master block register — ${blocks.length} blocks · ` +
      `${fmtNum(totalAcres)} acres · Season 2025/26 · Manager: A. Wangari.`,
    kpis: [
      { label: "Total blocks", value: blocks.length, unit: "", target: `${fmtNum(totalAcres)} ac`, colorClass: "g" },
      { label: "Ready",         value: counts.READY,         unit: "", target: "urgent — harvest now", colorClass: "r" },
      { label: "Growing",       value: counts.GROWING,       unit: "", target: "active in field",      colorClass: "g" },
      { label: "Awaiting",      value: counts.AWAITING,      unit: "", target: "prepared for planting", colorClass: "a" },
    ],
    sections: [
      {
        type: "table",
        title: "Crop register",
        headers: [
          "Block",
          "Area (ac)",
          "Crop",
          "Status",
          "Crop age",
          "Due / harvest",
          "Season",
          "Notes & actions",
        ],
        rows,
      },
      {
        type: "narrative",
        title: "This week's priorities",
        body:
          counts.READY > 0
            ? `${counts.READY} block(s) marked READY — harvest now, organise labour and buyers today.`
            : "No blocks ready to harvest this week. Stay on top of growing-stage operations.",
      },
      commentSection("Field manager observations", 6),
      signatureSection([
        "Logged by (Horticulture Mgr)",
        "Reviewed by CEO",
      ]),
    ],
  };
};

// ===================================================================
// 7c. Ngusishi Inventory
// ===================================================================
//
// Stock snapshot for inputs / equipment / agrochemicals. Status reflects
// the same Out / Low / Good logic the frontend uses (qty == 0 → Out,
// qty < 5 → Low unless explicitly stored as Good).

const buildNgushishInventoryReport = async () => {
  const items = await ngushishService
    .listNgushishInventory()
    .catch(() => []);

  const condFor = (item) => {
    const c = (item.condition ?? "").toLowerCase();
    if ((item.quantity ?? 0) === 0 || c === "out") return "out";
    if (c === "low" || ((item.quantity ?? 0) < 5 && c !== "good")) return "low";
    return "good";
  };

  let outCount = 0;
  let lowCount = 0;
  let goodCount = 0;
  for (const i of items) {
    const c = condFor(i);
    if (c === "out") outCount += 1;
    else if (c === "low") lowCount += 1;
    else goodCount += 1;
  }

  // Group rows by category so the printed page matches the on-screen
  // card. Categories rendered in the canonical order.
  const groups = {};
  for (const i of items) {
    const cat = i.category ?? "Other";
    if (!groups[cat]) groups[cat] = [];
    groups[cat].push(i);
  }
  const order = ["Inputs", "Equipment", "Agrochemicals", "Tags"];
  const orderedCats = [
    ...order.filter((c) => groups[c]),
    ...Object.keys(groups).filter((c) => !order.includes(c)),
  ];

  const sections = [];
  for (const cat of orderedCats) {
    const rows = groups[cat].map((i) => {
      const c = condFor(i);
      return [
        i.name ?? "—",
        `${fmtNum(i.quantity ?? 0)}${i.unit ? ` ${i.unit}` : ""}`,
        i.location ?? "—",
        c === "out" ? "⚠ Out" : c === "low" ? "Low" : "Good",
        i.notes ?? "",
      ];
    });
    sections.push({
      type: "table",
      title: `${cat} (${groups[cat].length})`,
      headers: ["Item", "Quantity", "Location", "Condition", "Notes"],
      rows,
    });
  }

  sections.push({
    type: "narrative",
    title: "Action items",
    body:
      outCount > 0
        ? `${outCount} item(s) are out of stock — reorder before fieldwork resumes.`
        : lowCount > 0
          ? `${lowCount} item(s) running low. Plan reorders this week.`
          : "Inventory healthy. Reconcile counts during next stocktake.",
  });
  sections.push(commentSection("Procurement notes / suppliers contacted"));
  sections.push(
    signatureSection(["Logged by (Horticulture Mgr)", "Approved by CEO"]),
  );

  return {
    title: "Ngusishi Inventory",
    period: fmtMonth(),
    summary:
      "Inputs, equipment and agrochemicals for the horticulture unit. " +
      "Flag any anomalies before the next field operation.",
    kpis: [
      { label: "Items tracked", value: items.length, unit: "", target: "across categories", colorClass: "g" },
      { label: "Out of stock",  value: outCount,     unit: "", target: "reorder now",        colorClass: "r" },
      { label: "Low",           value: lowCount,     unit: "", target: "monitor",            colorClass: "a" },
      { label: "Good",          value: goodCount,    unit: "", target: "healthy",            colorClass: "g" },
    ],
    sections,
  };
};

// ===================================================================
// 8. Unit P&L Summary (placeholder until finance schema lands)
// ===================================================================

const buildUnitPLReport = async () => ({
  title: "Unit P&L Summary",
  period: fmtMonth(),
  summary:
    "Revenue, expenses and profit by unit. NOTE: no financial module is wired yet — this report renders empty cells until the finance schema lands.",
  kpis: [
    { label: "Total revenue", value: "—", unit: "KSh", target: "all units", colorClass: "g" },
    { label: "Total expenses", value: "—", unit: "KSh", target: "feeds, labour, health", colorClass: "a" },
    { label: "Net profit", value: "—", unit: "KSh", target: "—", colorClass: "g" },
    { label: "Best unit", value: "—", unit: "", target: "—", colorClass: "g" },
  ],
  sections: [
    {
      type: "table",
      title: "Per-unit P&L",
      headers: ["Unit", "Revenue (KSh)", "Expenses (KSh)", "Profit (KSh)", "Margin"],
      rows: [
        ["Dairy", "—", "—", "—", "—"],
        ["Layers", "—", "—", "—", "—"],
        ["Piggery", "—", "—", "—", "—"],
        ["Ngushish", "—", "—", "—", "—"],
        ["Feedlot", "—", "—", "—", "—"],
      ],
    },
    commentSection("CEO / accountant observations", 6),
    signatureSection(["Prepared by (Accountant)", "Reviewed by CEO", "Approved by Board"]),
  ],
  footnote:
    "Finance module pending — wire revenue/expense models to populate live values.",
});

// ===================================================================
// 9. Payroll Report
// ===================================================================

const buildPayrollReport = async () => {
  const now = new Date();
  const summary = await staffService
    .getPayrollSummary({ month: now.getMonth() + 1, year: now.getFullYear() })
    .catch(() => ({ rows: [], totalGross: 0, totalStaff: 0 }));

  const rows = (summary.rows ?? []).map((r) => [
    r.name,
    r.role ?? "—",
    r.unit ?? "—",
    String(r.daysWorked ?? 0),
    fmtNum(r.dailyRate ?? 0),
    fmtNum(r.grossPay ?? 0),
    r.status ?? "Pending",
  ]);

  return {
    title: "Payroll Report",
    period: fmtMonth(),
    summary:
      "Monthly payroll calculation based on attendance days × daily rate.",
    kpis: [
      { label: "Total staff", value: summary.totalStaff ?? rows.length, unit: "", target: "on payroll", colorClass: "g" },
      { label: "Monthly gross", value: `KSh ${fmtNum(summary.totalGross ?? 0)}`, unit: "", target: "estimate", colorClass: "g" },
      {
        label: "Per worker avg",
        value:
          rows.length > 0
            ? `KSh ${fmtNum(Math.round((summary.totalGross ?? 0) / rows.length))}`
            : "—",
        unit: "",
        target: "mean",
        colorClass: "b",
      },
    ],
    sections: [
      {
        type: "table",
        title: "Payroll lines",
        headers: ["Name", "Role", "Unit", "Days", "Daily rate", "Gross (KSh)", "Status"],
        rows,
      },
      commentSection("Adjustments / advances / deductions", 6),
      signatureSection(["Prepared by HR", "Reviewed by CEO", "Approved for payment"]),
    ],
  };
};

// ===================================================================
// 10. 5-Year Goals Tracker
// ===================================================================

const buildGoalsReport = async () => {
  const [dairySummary, layersKpis, pigKpis] = await Promise.all([
    dairyService.getSummary().catch(() => ({})),
    layersService.getKpis().catch(() => ({})),
    piggeryService.getKpis().catch(() => ({})),
  ]);

  const milkPct = Math.round(((dairySummary.milkToday ?? 0) / 2000) * 100);
  const eggPct = Math.round(((layersKpis.traysToday ?? 0) / 700) * 100);
  const pigPct = Math.round(((pigKpis.beaconnersMonth ?? 0) / 100) * 100);
  const layerFlockPct = Math.round(
    (((layersKpis.totalBirds ?? 0) + (layersKpis.brooderCount ?? 0)) / 20000) * 100,
  );

  return {
    title: "5-Year Goals Tracker",
    period: fmtMonth(),
    summary:
      "Progress toward stated 5-year targets. Each unit has a headline metric and a path to scale.",
    kpis: [
      { label: "Milk", value: `${milkPct}%`, unit: "", target: `${fmtNum(dairySummary.milkToday ?? 0)} / 2,000 L`, colorClass: milkPct >= 80 ? "g" : "a" },
      { label: "Eggs", value: `${eggPct}%`, unit: "", target: `${fmtNum(layersKpis.traysToday ?? 0)} / 700 crates`, colorClass: eggPct >= 80 ? "g" : "a" },
      { label: "Piglets", value: `${pigPct}%`, unit: "", target: `${pigKpis.beaconnersMonth ?? 0} / 100 / month`, colorClass: pigPct >= 80 ? "g" : "a" },
      { label: "Layers flock", value: `${layerFlockPct}%`, unit: "", target: "/ 20,000 birds", colorClass: layerFlockPct >= 80 ? "g" : "a" },
    ],
    sections: [
      {
        type: "progress",
        title: "Progress against 5-year targets",
        items: [
          { label: "Milk production", pct: Math.min(100, Math.max(0, milkPct)), detail: `${fmtNum(dairySummary.milkToday ?? 0)} L/day → 2,000 L/day target` },
          { label: "Egg crates", pct: Math.min(100, Math.max(0, eggPct)), detail: `${fmtNum(layersKpis.traysToday ?? 0)}/day → 700/day target` },
          { label: "Piglets/month", pct: Math.min(100, Math.max(0, pigPct)), detail: `${pigKpis.beaconnersMonth ?? 0} → 100/month target` },
          { label: "Layers flock", pct: Math.min(100, Math.max(0, layerFlockPct)), detail: `${fmtNum((layersKpis.totalBirds ?? 0) + (layersKpis.brooderCount ?? 0))} → 20,000 birds` },
        ],
      },
      commentSection("Board / CEO observations", 8),
      signatureSection(["Prepared by CEO", "Reviewed by Board"]),
    ],
  };
};

// ===================================================================
// 11. Active Reminders Report
// ===================================================================

const buildRemindersReport = async () => {
  const all = await reminderService.listReminders().catch(() => []);
  const counts = { OVERDUE: 0, DUE: 0, UPCOMING: 0, FUTURE: 0, DONE: 0 };
  for (const r of all) counts[r.bucket] = (counts[r.bucket] ?? 0) + 1;

  const actionable = all.filter((r) =>
    ["OVERDUE", "DUE", "UPCOMING"].includes(r.bucket),
  );
  const rows = actionable.map((r) => [
    r.bucket === "OVERDUE" ? "⚠ Overdue" : r.bucket === "DUE" ? "Due now" : "Upcoming",
    r.unit ?? "—",
    r.title,
    r.effectiveDueDate
      ? new Date(r.effectiveDueDate).toLocaleDateString("en-KE", { day: "numeric", month: "short", year: "numeric" })
      : "—",
    r.sourceType,
  ]);

  return {
    title: "Active Reminders Report",
    period: fmtToday(),
    summary:
      "Auto-generated from active vet protocols, brooder cohort, piglet litters and feed inventory.",
    kpis: [
      { label: "Overdue", value: counts.OVERDUE, unit: "", target: "action needed now", colorClass: counts.OVERDUE > 0 ? "r" : "g" },
      { label: "Due now", value: counts.DUE, unit: "", target: "within 3 days", colorClass: counts.DUE > 0 ? "a" : "g" },
      { label: "Upcoming", value: counts.UPCOMING, unit: "", target: "next 14 days", colorClass: "g" },
      { label: "All active", value: counts.OVERDUE + counts.DUE + counts.UPCOMING, unit: "", target: "total", colorClass: "g" },
    ],
    sections: [
      {
        type: "table",
        title: "Items that need attention",
        headers: ["Status", "Unit / animal", "Item", "When", "Source"],
        rows,
      },
      commentSection("Vet / Manager actions taken", 8),
      signatureSection(["Reviewed by Vet", "Reviewed by Manager"]),
    ],
  };
};

// ===================================================================
// Registry
// ===================================================================

export const REPORT_REGISTRY = {
  "daily-ceo": {
    key: "daily-ceo",
    label: "Daily CEO Report",
    description: "All units summary for morning briefing",
    icon: "📋",
    iconBg: "#EAF3DE",
    category: "Daily & Production",
    formats: ["PDF"],
    roles: ["CEO", "ADMIN"],
    build: buildDailyCeoReport,
  },
  "milk-records": {
    key: "milk-records",
    label: "Milk Production",
    description: "Per-cow daily yields, 7-day averages, sessions",
    icon: "🐄",
    iconBg: "#EAF3DE",
    category: "Daily & Production",
    formats: ["PDF", "CSV"],
    roles: ["CEO", "ADMIN", "DAIRY_MANAGER", "VET"],
    build: buildMilkRecordsReport,
  },
  "egg-records": {
    key: "egg-records",
    label: "Egg Production",
    description: "Crates per house, brooder status, mortality",
    icon: "🥚",
    iconBg: "#FAEEDA",
    category: "Daily & Production",
    formats: ["PDF", "CSV"],
    roles: ["CEO", "ADMIN", "LAYERS_MANAGER", "VET"],
    build: buildEggRecordsReport,
  },
  "vacc-schedule": {
    key: "vacc-schedule",
    label: "Vaccination Schedule",
    description: "Vaccines done, due, overdue, compliance",
    icon: "💉",
    iconBg: "#E0EAF7",
    category: "Health & Animal",
    formats: ["PDF", "CSV"],
    roles: ["CEO", "ADMIN", "VET", "DAIRY_MANAGER", "LAYERS_MANAGER"],
    build: buildVaccScheduleReport,
  },
  "treatment-log": {
    key: "treatment-log",
    label: "Treatment Log",
    description: "Active and historic treatment records",
    icon: "🩺",
    iconBg: "#FBEDED",
    category: "Health & Animal",
    formats: ["PDF", "CSV"],
    roles: ["CEO", "ADMIN", "VET"],
    build: buildTreatmentLogReport,
  },
  "reminders-report": {
    key: "reminders-report",
    label: "Active Reminders",
    description: "Overdue + due-now + upcoming items per unit",
    icon: "🔔",
    iconBg: "#FBEDED",
    category: "Health & Animal",
    formats: ["PDF", "CSV"],
    roles: ["CEO", "ADMIN", "VET", "DAIRY_MANAGER", "LAYERS_MANAGER"],
    build: buildRemindersReport,
  },
  "piggery-report": {
    key: "piggery-report",
    label: "Piggery Production",
    description: "Farrowing records, beaconners vs target, mortality",
    icon: "🐷",
    iconBg: "#FBE3F0",
    category: "Inventory & Operations",
    formats: ["PDF", "CSV"],
    roles: ["CEO", "ADMIN", "PIGGERY_MANAGER", "VET"],
    build: buildPiggeryReport,
  },
  "feeds-inventory": {
    key: "feeds-inventory",
    label: "Feeds Inventory",
    description: "Stock levels, days remaining, reorder triggers",
    icon: "🌾",
    iconBg: "#EAF3DE",
    category: "Inventory & Operations",
    formats: ["PDF", "CSV"],
    roles: ["CEO", "ADMIN", "FEEDS_MANAGER"],
    build: buildFeedsReport,
  },
  "ngushish-crop-register": {
    key: "ngushish-crop-register",
    label: "Ngusishi Crop Register",
    description:
      "Master block register — status, age, due dates, notes per block",
    icon: "🌿",
    iconBg: "#EAF3DE",
    category: "Inventory & Operations",
    formats: ["PDF", "CSV"],
    roles: ["CEO", "ADMIN", "STORE_MANAGER"],
    build: buildNgushishCropRegisterReport,
  },
  "ngushish-inventory": {
    key: "ngushish-inventory",
    label: "Ngusishi Inventory",
    description: "Inputs, equipment, agrochemicals — stock & condition",
    icon: "📦",
    iconBg: "#EAF3DE",
    category: "Inventory & Operations",
    formats: ["PDF", "CSV"],
    roles: ["CEO", "ADMIN", "STORE_MANAGER"],
    build: buildNgushishInventoryReport,
  },
  "unit-pl": {
    key: "unit-pl",
    label: "Unit P&L",
    description: "Revenue, expenses, profit per unit",
    icon: "💰",
    iconBg: "#EAF3DE",
    category: "Financial & Strategic",
    formats: ["PDF", "CSV"],
    roles: ["CEO", "ADMIN"],
    build: buildUnitPLReport,
  },
  "payroll-report": {
    key: "payroll-report",
    label: "Payroll Report",
    description: "Attendance, days worked, gross pay",
    icon: "💳",
    iconBg: "#E0EAF7",
    category: "Financial & Strategic",
    formats: ["PDF", "CSV"],
    roles: ["CEO", "ADMIN"],
    build: buildPayrollReport,
  },
  "goals-report": {
    key: "goals-report",
    label: "5-Year Goals Tracker",
    description: "Progress vs targets across all units",
    icon: "🎯",
    iconBg: "#FAEEDA",
    category: "Financial & Strategic",
    formats: ["PDF"],
    roles: ["CEO", "ADMIN"],
    build: buildGoalsReport,
  },
};

// ===================================================================
// Public API
// ===================================================================

const stripBuilder = ({ build, ...rest }) => rest;

// List every report on the dashboard. The `roles` metadata is kept on
// each registry entry as a hint for future per-action enforcement
// (e.g. blocking a non-finance user from running Payroll), but the
// dashboard itself shows the catalog so users can see what reports
// exist on the farm. Strict role gating turns out to be too noisy when
// most farm staff are VETs or unit managers — they end up missing the
// CEO snapshot, feed health, and financial summaries.
export const listReports = (_role) => {
  return Object.values(REPORT_REGISTRY).map(stripBuilder);
};

export const getReport = async (key, _role) => {
  const entry = REPORT_REGISTRY[key];
  if (!entry) {
    const err = new Error(`Unknown report: ${key}`);
    err.code = "NOT_FOUND";
    throw err;
  }
  // Role-based access is intentionally permissive at v1 — re-introduce
  // the `entry.roles.includes(role)` check here when finance reports
  // need to be hidden from non-CEO/ADMIN users.
  return entry.build();
};

// Convert a report's first table section into a CSV string. Used by
// the /reports/:key.csv endpoint and by the Flutter download path.
export const reportToCsv = (report) => {
  const tableSection = (report.sections ?? []).find((s) => s.type === "table");
  if (!tableSection) return null;
  const escape = (cell) => `"${String(cell).replace(/"/g, '""')}"`;
  const headerRow = tableSection.headers.map(escape).join(",");
  const dataRows = tableSection.rows.map((r) => r.map(escape).join(","));
  return [headerRow, ...dataRows].join("\n");
};
