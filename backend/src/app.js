import dashboardRoutes from "./modules/dashboard/dashboard.routes.js";
import reportsRoutes from "./modules/reports/reports.routes.js";
import dairyRoutes from "./modules/dairy/dairy.routes.js";
import reproductionRoutes from "./modules/reproduction/reproduction.routes.js";
import layerRoutes from "./modules/layers/layers.routes.js";
import layersUnitRoutes from "./modules/layers/layersUnit.routes.js";
import piggeryRoutes from "./modules/piggery/piggery.routes.js";
import feedlotRoutes from "./modules/feedlot/feedlot.routes.js";
import feedsRoutes from "./modules/feeds/feeds.routes.js";
import ngushishRoutes from "./modules/ngushish/ngushish.routes.js";
import staffRoutes from "./modules/staff/staff.routes.js";
import healthRoutes from "./modules/health/health.routes.js";
import remindersRoutes from "./modules/reminders/reminders.routes.js";
import financeRoutes from "./modules/finance/finance.routes.js";
import authRoutes from "./modules/auth/auth.routes.js";
import uploadsRoutes from "./modules/uploads/uploads.routes.js";
import activityLogRoutes from "./modules/activity_log/activity_log.routes.js";
import cors from "cors";
import express from "express";

const app = express();
app.use(express.json());
app.use(cors());

app.use("/api/dashboard", dashboardRoutes);
app.use("/api/reports", reportsRoutes);
app.use("/api/dairy", dairyRoutes);
app.use("/api/reproduction", reproductionRoutes);
app.use("/api/feedlot", feedlotRoutes);
app.use("/api/feeds", feedsRoutes);
app.use("/api/ngushish", ngushishRoutes);
app.use("/api/layers", layerRoutes);
app.use("/api/layers-unit", layersUnitRoutes);
app.use("/api/piggery", piggeryRoutes);
app.use("/api/staff", staffRoutes);
app.use("/api/health", healthRoutes);
app.use("/api/reminders", remindersRoutes);
app.use("/api/finance", financeRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/uploads", uploadsRoutes);
app.use("/api/activity-log", activityLogRoutes);

app.get("/", (req, res) => {
  res.json({ message: "Mwirigi Farm API is running" });
});

export default app;

