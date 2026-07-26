// Thin wrapper around google-spreadsheet, authenticated with a service
// account (no OAuth consent screen needed for a single-user tool) — share the
// target Sheet with the service account's email as Editor. See
// docs/SHEETS_SETUP.md for the one-time manual steps.

import fs from "node:fs";
import path from "node:path";
import { GoogleSpreadsheet, type GoogleSpreadsheetWorksheet } from "google-spreadsheet";
import { JWT } from "google-auth-library";
import { config } from "../config.js";

const SHEET_TITLE = "Watchlist";

export const SHEET_HEADERS = [
  "Ticker",
  "Project",
  "Chain",
  "Contract",
  "CoinGecko ID",
  "DefiLlama Slug",
  "Binance Symbol",
  "MEXC Symbol",
  "Cluster",
  "Notes",
  "Labels",
  "Status",
] as const;

export function isSheetsConfigured(): boolean {
  if (!config.googleSheetId) return false;
  try {
    return fs.existsSync(path.resolve(config.googleServiceAccountFile));
  } catch {
    return false;
  }
}

let cachedDoc: GoogleSpreadsheet | null = null;

async function getDoc(): Promise<GoogleSpreadsheet> {
  if (cachedDoc) return cachedDoc;
  if (!config.googleSheetId) {
    throw new Error("GOOGLE_SHEET_ID is not configured");
  }

  const keyPath = path.resolve(config.googleServiceAccountFile);
  const key = JSON.parse(fs.readFileSync(keyPath, "utf-8")) as {
    client_email: string;
    private_key: string;
  };

  const auth = new JWT({
    email: key.client_email,
    key: key.private_key,
    scopes: ["https://www.googleapis.com/auth/spreadsheets"],
  });

  const doc = new GoogleSpreadsheet(config.googleSheetId, auth);
  await doc.loadInfo();
  cachedDoc = doc;
  return doc;
}

export async function getWatchlistSheet(): Promise<GoogleSpreadsheetWorksheet> {
  const doc = await getDoc();
  const existing = doc.sheetsByTitle[SHEET_TITLE];
  if (existing) return existing;
  return doc.addSheet({ title: SHEET_TITLE, headerValues: [...SHEET_HEADERS] });
}
