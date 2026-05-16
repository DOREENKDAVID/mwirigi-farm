import puppeteer from "puppeteer";

export const generateDailyReportPDF = async (summary) => {
  const browser = await puppeteer.launch({
    headless: "new", // important for newer versions
  });

  const page = await browser.newPage();

  const html = `
    <html>
      <head>
        <style>
          body {
            font-family: Arial, sans-serif;
            padding: 40px;
            color: #333;
          }

          h1 {
            text-align: center;
            color: #2E7D32;
          }

          h2 {
            text-align: center;
            color: #555;
            margin-top: -10px;
          }

          .date {
            text-align: right;
            font-size: 12px;
            color: #777;
          }

          .section {
            margin-top: 30px;
          }

          .card {
            display: flex;
            justify-content: space-between;
            padding: 12px 20px;
            border-bottom: 1px solid #eee;
            font-size: 14px;
          }

          .label {
            color: #555;
          }

          .value {
            font-weight: bold;
          }

          .highlight {
            margin-top: 30px;
            padding: 15px;
            background: #E8F5E9;
            border-left: 5px solid #2E7D32;
          }

          .footer {
            position: absolute;
            bottom: 30px;
            width: 100%;
            text-align: center;
            font-size: 10px;
            color: #999;
          }
        </style>
      </head>

      <body>

        <h1>MWIRIGI FARM</h1>
        <h2>Daily CEO Report</h2>

        <div class="date">
          ${new Date(summary.date).toDateString()}
        </div>

        <div class="section">
          <div class="card">
            <span class="label">Milk Produced</span>
            <span class="value">${summary.milk} L</span>
          </div>

          <div class="card">
            <span class="label">Eggs Collected</span>
            <span class="value">${summary.eggs}</span>
          </div>

          <div class="card">
            <span class="label">Trays</span>
            <span class="value">${summary.trays}</span>
          </div>

          <div class="card">
            <span class="label">Mortality</span>
            <span class="value">${summary.mortality}</span>
          </div>
        </div>

        <div class="highlight">
          ✔ Farm performance is within expected range.
        </div>

        <div class="footer">
          Generated automatically by MFIMS V2
        </div>

      </body>
    </html>
  `;

  await page.setContent(html, { waitUntil: "domcontentloaded" });

  const pdfBuffer = await page.pdf({
    format: "A4",
    printBackground: true,
  });

  await browser.close();

  return pdfBuffer;
};