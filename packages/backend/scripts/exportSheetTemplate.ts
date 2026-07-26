// Exports the current watchlist as a CSV in exactly the column layout the
// two-way Sheets sync expects (see sheets/sheetsClient.ts's SHEET_HEADERS).
// Useful to pre-populate a Google Sheet by hand before ever running a sync,
// rather than starting from a blank header row.
//
// Run with: npm run export-sheet-template --workspace packages/backend
//           (optionally pass an output path as an extra arg)

import fs from "node:fs";
import path from "node:path";
import { prisma } from "../src/db.js";
import { SHEET_HEADERS } from "../src/sheets/sheetsClient.js";
import { fieldsFromToken } from "../src/jobs/sheetSyncJob.js";

function csvEscape(value: string): string {
  if (/[",\n]/.test(value)) return `"${value.replace(/"/g, '""')}"`;
  return value;
}

async function main() {
  const outPath = process.argv[2]
    ? path.resolve(process.argv[2])
    : path.resolve(process.cwd(), "watchlist-sheet-template.csv");

  const tokens = await prisma.token.findMany({
    where: { status: { not: "removed" } },
    include: { deployments: true, labels: { include: { label: true } } },
    orderBy: { ticker: "asc" },
  });

  const lines = [SHEET_HEADERS.join(",")];
  for (const token of tokens) {
    const fields = fieldsFromToken(token);
    const row = [
      token.ticker,
      fields.Project,
      fields.Chain,
      fields.Contract,
      fields["CoinGecko ID"],
      fields["DefiLlama Slug"],
      fields["Binance Symbol"],
      fields["MEXC Symbol"],
      fields.Cluster,
      fields.Notes,
      fields.Labels,
      fields.Status,
    ];
    lines.push(row.map(csvEscape).join(","));
  }

  fs.writeFileSync(outPath, lines.join("\n") + "\n", "utf-8");
  console.log(`Wrote ${tokens.length} rows to ${outPath}`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
