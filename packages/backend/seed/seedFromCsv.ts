// One-time import of Skills/watchlist.csv into the Token / TokenDeployment
// tables. Safe to re-run: matches existing rows by ticker and updates them
// rather than duplicating. After this runs once, the database is the source
// of truth — this script does not get called again by the app itself.
//
// Run with: npm run seed --workspace packages/backend

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parse } from "csv-parse/sync";
import { prisma } from "../src/db.js";
import { collisionWarningFor } from "@crypto-analyzer/shared";
import { COINGECKO_ID_CORRECTIONS } from "../src/dataCorrections.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CSV_PATH = path.resolve(__dirname, "../../../Skills/watchlist.csv");

interface CsvRow {
  ticker: string;
  project: string;
  chain: string;
  contract: string;
  coingecko_id: string;
  defillama_slug: string;
  cluster: string;
  notes: string;
}

function readWatchlistCsv(csvPath: string): CsvRow[] {
  const raw = fs.readFileSync(csvPath, "utf-8");

  // Parsed as raw arrays (not `columns: true`) because at least one row in
  // this file has an unescaped comma inside the free-text `notes` column
  // (AERO's "ve(3,3) emissions decaying per epoch"), which a strict CSV
  // parser splits into extra columns instead of erroring. relax_column_count
  // lets rows through with a differing field count; the merge step below
  // rejoins any overflow back into `notes` rather than silently dropping it.
  const records: string[][] = parse(raw, {
    columns: false,
    skip_empty_lines: true,
    relax_column_count: true,
  });

  const [header, ...rows] = records;
  const expectedCols = header.length;

  const normalized = rows.map((row) => {
    if (row.length > expectedCols) {
      const merged = [
        ...row.slice(0, expectedCols - 1),
        row.slice(expectedCols - 1).join(","),
      ];
      return merged;
    }
    return row;
  });

  return normalized.map((row) => {
    const obj: Record<string, string> = {};
    header.forEach((key, i) => {
      obj[key] = row[i] ?? "";
    });
    return obj as unknown as CsvRow;
  });
}

// Multi-chain deployments known from Skills/data-sources.md and the CSV's own
// notes column, entered by hand rather than regex-parsed out of prose —
// auto-parsing contract addresses out of free text is exactly the kind of
// silent error this domain is designed to avoid. Tickers listed here are
// skipped by the generic single-contract fallback below, since their CSV
// `contract` column only captures one of several real deployments.
const HAND_CURATED_DEPLOYMENTS: Record<
  string,
  { chain: string; contractAddress: string; isPrimaryLiquidity: boolean; notes: string }[]
> = {
  EVAA: [
    {
      chain: "TON",
      contractAddress: "EQBKMfjX_a_dsOLm-juxyVZytFP7_KKnzGv6J01kGc72gVBp",
      isPrimaryLiquidity: false,
      notes: "Project's native chain, but not where most trading volume sits.",
    },
    {
      chain: "BNB Chain",
      contractAddress: "0xaa036928c9c0Df07d525B55ea8EE690Bb5a628C1",
      isPrimaryLiquidity: true,
      notes: "Primary trading liquidity for EVAA sits here, not on TON.",
    },
  ],
  TRADOOR: [
    {
      chain: "BNB Chain",
      contractAddress: "0x9123400446a56176eb1b6be9ee5cf703e409f492",
      isPrimaryLiquidity: true,
      notes: "Holds most trading volume for TRADOOR. No TON contract address given in watchlist.csv.",
    },
  ],
  BASED: [
    {
      chain: "Ethereum",
      contractAddress: "0x4f2b33840227ddd0e28da8d4185d6fa07adfed87",
      isPrimaryLiquidity: false,
      notes:
        "LayerZero OFT — also deployed on BSC and Hyperliquid; per-chain contract addresses for those legs are not confirmed, so they are not recorded here rather than guessed.",
    },
  ],
  // Not present in watchlist.csv's contract column at all (left blank); found
  // via CoinGecko during setup while chasing down RECALL's stale coingecko_id
  // (see dataCorrections.ts) and cross-checked against the project's own
  // homepage/categories, not just its ticker.
  RECALL: [
    {
      chain: "Base",
      contractAddress: "0x1f16e03c1a5908818f47f6ee7bb16690b40d0671",
      isPrimaryLiquidity: true,
      notes: "Resolved via CoinGecko during setup; matches Base chain and AI-agent cluster from the CSV.",
    },
  ],
  // watchlist.csv leaves APEX's contract blank, presumably because of the
  // ticker-collision risk it flags in `notes`. Resolved via CoinGecko during
  // setup (see dataCorrections.ts) by matching apex.exchange / Perpetuals-DEX
  // categories against the "ApeX Protocol" / Trading venue description here.
  APEX: [
    {
      chain: "Ethereum",
      contractAddress: "0x52a8845df664d76c69d2eea607cd793565af42b8",
      isPrimaryLiquidity: false,
      notes: "Resolved via CoinGecko during setup.",
    },
    {
      chain: "Arbitrum One",
      contractAddress: "0x61a1ff55c5216b636a294a07d77c6f4df10d3b56",
      isPrimaryLiquidity: false,
      notes: "Resolved via CoinGecko during setup; which chain holds primary liquidity is not confirmed.",
    },
  ],
};

async function main() {
  const rows = readWatchlistCsv(CSV_PATH);
  console.log(`Loaded ${rows.length} tokens from ${CSV_PATH}`);

  for (const row of rows) {
    const ticker = row.ticker.trim();
    if (!ticker) continue;

    const existing = await prisma.token.findFirst({ where: { ticker } });

    const data = {
      ticker,
      projectName: row.project || null,
      primaryChain: row.chain || null,
      coingeckoId: COINGECKO_ID_CORRECTIONS[ticker] ?? (row.coingecko_id || null),
      defillamaSlug: row.defillama_slug || null,
      cluster: row.cluster || null,
      notes: row.notes || null,
      collisionWarning: collisionWarningFor(ticker),
    };

    const token = existing
      ? await prisma.token.update({ where: { id: existing.id }, data })
      : await prisma.token.create({ data });

    console.log(`  ${existing ? "updated" : "created"} ${ticker} (id=${token.id})`);

    const deployments =
      HAND_CURATED_DEPLOYMENTS[ticker] ??
      // Generic fallback: the CSV's own single `contract` column, for tokens
      // that don't need the hand-curated multi-deployment treatment above.
      (row.contract
        ? [
            {
              chain: row.chain || "unknown",
              contractAddress: row.contract,
              isPrimaryLiquidity: true,
              notes: "Primary contract from watchlist.csv.",
            },
          ]
        : []);

    for (const dep of deployments) {
      const existingDep = await prisma.tokenDeployment.findFirst({
        where: { tokenId: token.id, chain: dep.chain, contractAddress: dep.contractAddress },
      });
      if (!existingDep) {
        await prisma.tokenDeployment.create({
          data: { tokenId: token.id, ...dep },
        });
        console.log(`    + deployment on ${dep.chain}`);
      }
    }
  }

  console.log("Seed complete.");
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
