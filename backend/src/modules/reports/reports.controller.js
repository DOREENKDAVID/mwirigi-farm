import * as ReportsService from "./reports.service.js";
import { generateDailyReportPDF } from "./reports.pdf.service.js";

/* =========================================================
   📄 DAILY SUMMARY
========================================================= */
export const getDailySummary = async (req, res) => {
  try {
    const { date } = req.query;

    const summary = await ReportsService.getDailySummary(
      date || new Date()
    );

    res.json(summary);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to fetch report" });
  }
};

/* =========================================================
   📊 TODAY METRICS (Dashboard cards)
========================================================= */
export const getTodayMetrics = async (req, res) => {
  try {
    const metrics = await ReportsService.getTodayMetrics();
    res.json(metrics);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to fetch today metrics" });
  }
};

/* =========================================================
   📈 ANALYTICS DASHBOARD
========================================================= */
export const getAnalyticsDashboard = async (req, res) => {
  try {
    const days = Number(req.query.days) || 7;

    const [milkTrend, eggTrend, kpis] = await Promise.all([
      ReportsService.getMilkTrend(days),
      ReportsService.getEggTrend(days),
      ReportsService.getKPIs(),
    ]);

    res.json({
      milkTrend,
      eggTrend,
      kpis,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Analytics failed" });
  }
};

/* =========================================================
   📄 EXPORT MONTHLY DAIRY CSV
========================================================= */
export const exportDairyCSV = async (req, res) => {
  try {
    const { month } = req.query;

    if (!month) {
      return res.status(400).json({ error: "Month is required" });
    }

    const data = await ReportsService.getMonthlyDairy(month);
    const csv = ReportsService.exportCSV(data);

    res.header("Content-Type", "text/csv");
    res.attachment(`dairy-${month}.csv`);
    res.send(csv);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "CSV export failed" });
  }
};
export const exportDailyPDF = async (req, res) => {
  try {
    const summary = await ReportsService.getDailySummary(new Date());

    const pdfBuffer = await generateDailyReportPDF(summary);

    res.set({
      "Content-Type": "application/pdf",
      "Content-Disposition": "attachment; filename=daily-report.pdf",
    });

    res.send(pdfBuffer);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "PDF generation failed" });
  }
};
