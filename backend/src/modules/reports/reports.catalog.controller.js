import * as service from "./reports.catalog.service.js";

export const list = async (req, res) => {
  try {
    const role = req.user?.role ?? null;
    res.json(service.listReports(role));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const get = async (req, res) => {
  try {
    const role = req.user?.role ?? null;
    const report = await service.getReport(req.params.key, role);
    res.json(report);
  } catch (err) {
    if (err.code === "NOT_FOUND") return res.status(404).json({ error: err.message });
    if (err.code === "FORBIDDEN") return res.status(403).json({ error: err.message });
    res.status(500).json({ error: err.message });
  }
};

export const downloadCsv = async (req, res) => {
  try {
    const role = req.user?.role ?? null;
    const report = await service.getReport(req.params.key, role);
    const csv = service.reportToCsv(report);
    if (!csv) {
      return res.status(400).json({ error: "This report has no tabular data for CSV export" });
    }
    const filename = `${(report.title + "_" + report.period).replace(/[^a-z0-9]+/gi, "_")}.csv`;
    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", `attachment; filename="${filename}"`);
    res.send(csv);
  } catch (err) {
    if (err.code === "NOT_FOUND") return res.status(404).json({ error: err.message });
    if (err.code === "FORBIDDEN") return res.status(403).json({ error: err.message });
    res.status(500).json({ error: err.message });
  }
};
