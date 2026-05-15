import cron from "node-cron";
import prisma from "../prisma/client.js";
import { getDailySummary } from "../modules/reports/reports.service.js";

export const startDailyReportJob = () => {
  cron.schedule("30 7 * * *", async () => {
    const summary = await getDailySummary(new Date());

    await prisma.reportLog.create({
      data: {
        type: "daily_ceo_summary",
        data: summary,
      },
    });

    console.log("✅ Daily CEO report generated");
  });
};