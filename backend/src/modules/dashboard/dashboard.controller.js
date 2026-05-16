// dashboard.controller.js
import * as DashboardService from "./dashboard.service.js";

export const getDashboard = async (req, res) => {
  try {
    const { date } = req.query;

    const data = await DashboardService.getDashboardOverview(
      date || new Date()
    );

    res.json({
      success: true,
      data,
    });
  } catch (error) {
    console.error("Dashboard error:", error);
    res.status(500).json({
      success: false,
      message: "Failed to load dashboard",
    });
  }
};

// GET /api/dashboard/overview — full CEO overview, aggregated from real
// data across every module. See dashboard.service.getOverview for the
// response shape.
export const getOverview = async (_req, res) => {
  try {
    const data = await DashboardService.getOverview();
    res.json(data);
  } catch (error) {
    console.error("Overview error:", error);
    res.status(500).json({
      message: "Failed to load overview",
      error: error.message,
    });
  }
};