// Orchestrates the two-way sync between the local DB and the Google Sheet,
// using the shadow-copy 3-way diff in syncDecision.ts. See docs/SHEETS_SETUP.md
// for the one-time Google Cloud steps this depends on.

import type { GoogleSpreadsheetRow } from "google-spreadsheet";
import { prisma } from "../db.js";
import { getWatchlistSheet, isSheetsConfigured, SHEET_HEADERS } from "../sheets/sheetsClient.js";
import { decideSyncAction, formatLabelList, hashRowFields, parseLabelList } from "./syncDecision.js";
import { collisionWarningFor, type TokenStatus } from "@crypto-analyzer/shared";

// google-spreadsheet v4 rows are read/written via .get()/.set()/.assign(),
// never direct property access (e.g. `row.Ticker` is always undefined) --
// that mismatch was the cause of the "everything looks deleted" bug below.
type WatchlistRowData = Record<(typeof SHEET_HEADERS)[number], string>;
type SheetRow = GoogleSpreadsheetRow<WatchlistRowData>;

const VALID_STATUSES: TokenStatus[] = ["active", "archived", "removed"];

export interface SyncSummary {
  ranAt: string;
  pushed: string[];
  pulled: string[];
  created: string[];
  archived: string[];
  conflicts: { ticker: string; field: string }[];
  skipped?: string;
}

function tokenPrimaryContract(deployments: { contractAddress: string | null; isPrimaryLiquidity: boolean }[]): string {
  const primary = deployments.find((d) => d.isPrimaryLiquidity);
  return primary?.contractAddress ?? deployments[0]?.contractAddress ?? "";
}

export function fieldsFromToken(t: {
  projectName: string | null;
  primaryChain: string | null;
  coingeckoId: string | null;
  defillamaSlug: string | null;
  binanceSymbol: string | null;
  mexcSymbol: string | null;
  cluster: string | null;
  notes: string | null;
  status: string;
  deployments: { contractAddress: string | null; isPrimaryLiquidity: boolean }[];
  labels: { label: { name: string } }[];
}): Record<string, string> {
  return {
    Project: t.projectName ?? "",
    Chain: t.primaryChain ?? "",
    Contract: tokenPrimaryContract(t.deployments),
    "CoinGecko ID": t.coingeckoId ?? "",
    "DefiLlama Slug": t.defillamaSlug ?? "",
    "Binance Symbol": t.binanceSymbol ?? "",
    "MEXC Symbol": t.mexcSymbol ?? "",
    Cluster: t.cluster ?? "",
    Notes: t.notes ?? "",
    Labels: formatLabelList(t.labels.map((l) => l.label.name)),
    Status: t.status,
  };
}

function fieldsFromSheetRow(row: SheetRow): Record<string, string> {
  return {
    Project: row.get("Project") ?? "",
    Chain: row.get("Chain") ?? "",
    Contract: row.get("Contract") ?? "",
    "CoinGecko ID": row.get("CoinGecko ID") ?? "",
    "DefiLlama Slug": row.get("DefiLlama Slug") ?? "",
    "Binance Symbol": row.get("Binance Symbol") ?? "",
    "MEXC Symbol": row.get("MEXC Symbol") ?? "",
    Cluster: row.get("Cluster") ?? "",
    Notes: row.get("Notes") ?? "",
    Labels: formatLabelList(parseLabelList(row.get("Labels") ?? "")),
    Status: row.get("Status") ?? "",
  };
}

function sheetRowTicker(row: SheetRow): string {
  return (row.get("Ticker") ?? "").trim().toUpperCase();
}

async function resolveLabelIds(names: string[]): Promise<number[]> {
  const ids: number[] = [];
  for (const name of names) {
    const label =
      (await prisma.label.findUnique({ where: { name } })) ??
      (await prisma.label.create({ data: { name } }));
    ids.push(label.id);
  }
  return ids;
}

async function writeTokenToRow(row: SheetRow, ticker: string, fields: Record<string, string>) {
  row.assign({
    Ticker: ticker,
    Project: fields.Project,
    Chain: fields.Chain,
    Contract: fields.Contract,
    "CoinGecko ID": fields["CoinGecko ID"],
    "DefiLlama Slug": fields["DefiLlama Slug"],
    "Binance Symbol": fields["Binance Symbol"],
    "MEXC Symbol": fields["MEXC Symbol"],
    Cluster: fields.Cluster,
    Notes: fields.Notes,
    Labels: fields.Labels,
    Status: fields.Status,
  });
  await row.save();
}

async function applySheetFieldsToToken(tokenId: number, fields: Record<string, string>) {
  const labelIds = await resolveLabelIds(parseLabelList(fields.Labels));
  const status = VALID_STATUSES.includes(fields.Status as TokenStatus)
    ? (fields.Status as TokenStatus)
    : undefined;

  await prisma.token.update({
    where: { id: tokenId },
    data: {
      projectName: fields.Project || null,
      primaryChain: fields.Chain || null,
      coingeckoId: fields["CoinGecko ID"] || null,
      defillamaSlug: fields["DefiLlama Slug"] || null,
      binanceSymbol: fields["Binance Symbol"] || null,
      mexcSymbol: fields["MEXC Symbol"] || null,
      cluster: fields.Cluster || null,
      notes: fields.Notes || null,
      ...(status ? { status } : {}),
      localVersion: { increment: 1 },
      labels: { deleteMany: {}, create: labelIds.map((labelId) => ({ labelId })) },
    },
  });

  if (fields.Contract) {
    const existing = await prisma.tokenDeployment.findFirst({ where: { tokenId } });
    if (existing) {
      if (existing.contractAddress !== fields.Contract) {
        await prisma.tokenDeployment.update({
          where: { id: existing.id },
          data: { contractAddress: fields.Contract },
        });
      }
    } else {
      await prisma.tokenDeployment.create({
        data: {
          tokenId,
          chain: fields.Chain || "unknown",
          contractAddress: fields.Contract,
          isPrimaryLiquidity: true,
        },
      });
    }
  }
}

export async function runSheetSync(): Promise<SyncSummary> {
  const summary: SyncSummary = { ranAt: new Date().toISOString(), pushed: [], pulled: [], created: [], archived: [], conflicts: [] };

  if (!isSheetsConfigured()) {
    summary.skipped = "GOOGLE_SHEET_ID / service-account.json not configured yet — see docs/SHEETS_SETUP.md";
    return summary;
  }

  const sheet = await getWatchlistSheet();
  const rows = await sheet.getRows<WatchlistRowData>();
  const rowsByTicker = new Map(rows.map((r) => [sheetRowTicker(r), r]));

  const tokens = await prisma.token.findMany({
    where: { status: { not: "removed" } },
    include: {
      deployments: true,
      labels: { include: { label: true } },
      sheetSyncState: true,
    },
  });
  const tokenTickers = new Set(tokens.map((t) => t.ticker));

  // --- Pass 1: every local (non-removed) token against its sheet counterpart ---
  for (const token of tokens) {
    const localFields = fieldsFromToken(token);
    const localHash = hashRowFields(localFields);
    const row = rowsByTicker.get(token.ticker);

    if (!row) {
      if (!token.sheetSyncState) {
        // Brand new local token, never synced: append it.
        const newRow = (await sheet.addRow({ Ticker: token.ticker, ...localFields })) as unknown as SheetRow;
        await prisma.sheetSyncState.create({
          data: { tokenId: token.id, sheetRow: newRow.rowNumber, baseContentHash: localHash, lastSyncedAt: new Date() },
        });
        summary.pushed.push(token.ticker);
      } else {
        // Previously synced, now missing from the sheet: treat as a
        // Sheet-side deletion. Soft-delete only — never a hard delete
        // triggered by an external edit.
        await prisma.token.update({ where: { id: token.id }, data: { status: "archived" } });
        summary.archived.push(token.ticker);
      }
      continue;
    }

    const sheetFields = fieldsFromSheetRow(row);
    const sheetHash = hashRowFields(sheetFields);
    const baseHash = token.sheetSyncState?.baseContentHash;

    if (!baseHash) {
      // Row exists on both sides but they've never been reconciled (e.g. the
      // sheet was pre-populated by hand) — sheet wins as the more deliberate
      // recent edit, same as a genuine conflict.
      await applySheetFieldsToToken(token.id, sheetFields);
      await prisma.sheetSyncState.upsert({
        where: { tokenId: token.id },
        create: { tokenId: token.id, sheetRow: row.rowNumber, baseContentHash: sheetHash, lastSyncedAt: new Date() },
        update: { sheetRow: row.rowNumber, baseContentHash: sheetHash, lastSyncedAt: new Date() },
      });
      summary.pulled.push(token.ticker);
      continue;
    }

    const action = decideSyncAction(localHash, sheetHash, baseHash);

    switch (action) {
      case "noop":
        break;
      case "push":
        await writeTokenToRow(row, token.ticker, localFields);
        await prisma.sheetSyncState.update({
          where: { tokenId: token.id },
          data: { baseContentHash: localHash, sheetRow: row.rowNumber, lastSyncedAt: new Date() },
        });
        summary.pushed.push(token.ticker);
        break;
      case "pull":
        await applySheetFieldsToToken(token.id, sheetFields);
        await prisma.sheetSyncState.update({
          where: { tokenId: token.id },
          data: { baseContentHash: sheetHash, sheetRow: row.rowNumber, lastSyncedAt: new Date() },
        });
        summary.pulled.push(token.ticker);
        break;
      case "converge":
        await prisma.sheetSyncState.update({
          where: { tokenId: token.id },
          data: { baseContentHash: localHash, sheetRow: row.rowNumber, lastSyncedAt: new Date() },
        });
        break;
      case "conflict": {
        for (const key of Object.keys(localFields)) {
          if (localFields[key] !== sheetFields[key]) {
            await prisma.conflictLog.create({
              data: {
                tokenId: token.id,
                field: key,
                localValue: localFields[key],
                sheetValue: sheetFields[key],
                resolution: "sheet_won",
              },
            });
            summary.conflicts.push({ ticker: token.ticker, field: key });
          }
        }
        await applySheetFieldsToToken(token.id, sheetFields);
        await prisma.sheetSyncState.update({
          where: { tokenId: token.id },
          data: { baseContentHash: sheetHash, sheetRow: row.rowNumber, lastSyncedAt: new Date() },
        });
        break;
      }
    }
  }

  // --- Pass 2: sheet rows whose ticker has no local token at all ---
  for (const row of rows) {
    const ticker = sheetRowTicker(row);
    if (!ticker || tokenTickers.has(ticker)) continue;

    const fields = fieldsFromSheetRow(row);
    const labelIds = await resolveLabelIds(parseLabelList(fields.Labels));
    const status = VALID_STATUSES.includes(fields.Status as TokenStatus) ? (fields.Status as TokenStatus) : "active";

    const created = await prisma.token.create({
      data: {
        ticker,
        projectName: fields.Project || null,
        primaryChain: fields.Chain || null,
        coingeckoId: fields["CoinGecko ID"] || null,
        defillamaSlug: fields["DefiLlama Slug"] || null,
        binanceSymbol: fields["Binance Symbol"] || null,
        mexcSymbol: fields["MEXC Symbol"] || null,
        cluster: fields.Cluster || null,
        notes: fields.Notes || null,
        status,
        collisionWarning: collisionWarningFor(ticker),
        labels: { create: labelIds.map((labelId) => ({ labelId })) },
        ...(fields.Contract
          ? { deployments: { create: [{ chain: fields.Chain || "unknown", contractAddress: fields.Contract, isPrimaryLiquidity: true }] } }
          : {}),
      },
    });

    await prisma.sheetSyncState.create({
      data: {
        tokenId: created.id,
        sheetRow: row.rowNumber,
        baseContentHash: hashRowFields(fields),
        lastSyncedAt: new Date(),
      },
    });
    summary.created.push(ticker);
  }

  return summary;
}
