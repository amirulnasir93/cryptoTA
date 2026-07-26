// Raw Sheets API v4 REST calls -- mirrors mobile/lib/sheets_client.dart
// exactly (same column layout, same tab names), so the phone, the web app,
// and the original backend's own sync job can all read/write the same
// "Watchlist" tab without stepping on each other.
import { googleAuth } from "./googleAuth";

const SHEETS_API = "https://sheets.googleapis.com/v4/spreadsheets";

export interface SheetTab {
  title: string;
  headers: string[];
}

export const watchlistTab: SheetTab = {
  title: "Watchlist",
  headers: [
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
  ],
};

export const catalystsTab: SheetTab = {
  title: "Catalysts",
  headers: ["Ticker", "Date", "Type", "Description", "SizePct", "SourceUrl"],
};

function columnLetter(zeroBasedIndex: number): string {
  return String.fromCharCode(0x41 + zeroBasedIndex); // single-letter only, fine up to column Z
}

export class SheetsApiException extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SheetsApiException";
  }
}

export class SheetsClient {
  private spreadsheetId: string;
  private clientId: string;

  constructor(spreadsheetId: string, clientId: string) {
    this.spreadsheetId = spreadsheetId;
    this.clientId = clientId;
  }

  private async headers(): Promise<Record<string, string>> {
    const token = await googleAuth.getAccessToken(this.clientId);
    return { Authorization: `Bearer ${token}`, "Content-Type": "application/json" };
  }

  private async check(res: Response): Promise<void> {
    if (!res.ok) {
      const body = await res.text();
      throw new SheetsApiException(`Sheets API ${res.status}: ${body}`);
    }
  }

  /** Maps existing tab titles to their sheetId (gid) -- needed for row
   * deletion, which operates on gid + a 0-based row index, not a title. */
  private async tabIds(): Promise<Record<string, number>> {
    const headers = await this.headers();
    const uri = new URL(`${SHEETS_API}/${this.spreadsheetId}`);
    uri.searchParams.set("fields", "sheets.properties");
    const res = await fetch(uri, { headers });
    await this.check(res);
    const body = (await res.json()) as { sheets?: { properties: { title: string; sheetId: number } }[] };
    const out: Record<string, number> = {};
    for (const s of body.sheets ?? []) out[s.properties.title] = s.properties.sheetId;
    return out;
  }

  /** Creates the tab with its header row if it doesn't exist yet -- mirrors
   * getWatchlistSheet()'s auto-create behavior in the web backend. */
  async ensureTab(tab: SheetTab): Promise<number> {
    const ids = await this.tabIds();
    if (tab.title in ids) return ids[tab.title];

    const headers = await this.headers();
    const addRes = await fetch(`${SHEETS_API}/${this.spreadsheetId}:batchUpdate`, {
      method: "POST",
      headers,
      body: JSON.stringify({ requests: [{ addSheet: { properties: { title: tab.title } } }] }),
    });
    await this.check(addRes);
    const addBody = (await addRes.json()) as { replies: { addSheet: { properties: { sheetId: number } } }[] };
    const sheetId = addBody.replies[0].addSheet.properties.sheetId;

    const lastCol = columnLetter(tab.headers.length - 1);
    await this.rawUpdate(`${tab.title}!A1:${lastCol}1`, [tab.headers]);
    return sheetId;
  }

  private async rawUpdate(range: string, values: string[][]): Promise<void> {
    const headers = await this.headers();
    const uri = new URL(`${SHEETS_API}/${this.spreadsheetId}/values/${encodeURIComponent(range)}`);
    uri.searchParams.set("valueInputOption", "USER_ENTERED");
    const res = await fetch(uri, { method: "PUT", headers, body: JSON.stringify({ values }) });
    await this.check(res);
  }

  /** Reads every data row (header excluded) for a tab. Short rows (trailing
   * empty cells Sheets doesn't bother returning) are padded to the full
   * column count so callers can always index by column position. */
  async readRows(tab: SheetTab): Promise<string[][]> {
    await this.ensureTab(tab);
    const headers = await this.headers();
    const lastCol = columnLetter(tab.headers.length - 1);
    const range = `${tab.title}!A2:${lastCol}`;
    const res = await fetch(`${SHEETS_API}/${this.spreadsheetId}/values/${encodeURIComponent(range)}`, { headers });
    await this.check(res);
    const body = (await res.json()) as { values?: string[][] };
    return (body.values ?? []).map((row) => {
      const cells = row.map((c) => `${c}`);
      while (cells.length < tab.headers.length) cells.push("");
      return cells;
    });
  }

  /** Appends one row. Returns the 1-based sheet row number it landed on. */
  async appendRow(tab: SheetTab, values: string[]): Promise<number> {
    await this.ensureTab(tab);
    const headers = await this.headers();
    const lastCol = columnLetter(tab.headers.length - 1);
    const uri = new URL(`${SHEETS_API}/${this.spreadsheetId}/values/${encodeURIComponent(`${tab.title}!A1:${lastCol}`)}:append`);
    uri.searchParams.set("valueInputOption", "USER_ENTERED");
    uri.searchParams.set("insertDataOption", "INSERT_ROWS");
    const res = await fetch(uri, { method: "POST", headers, body: JSON.stringify({ values: [values] }) });
    await this.check(res);
    const body = (await res.json()) as { updates: { updatedRange: string } };
    const match = /![A-Z]+(\d+)/.exec(body.updates.updatedRange);
    if (!match) throw new SheetsApiException(`Could not parse updated range: ${body.updates.updatedRange}`);
    return Number(match[1]);
  }

  /** Overwrites row [rowNumber] (1-based, header is row 1) with [values]. */
  async updateRow(tab: SheetTab, rowNumber: number, values: string[]): Promise<void> {
    const lastCol = columnLetter(tab.headers.length - 1);
    await this.rawUpdate(`${tab.title}!A${rowNumber}:${lastCol}${rowNumber}`, [values]);
  }

  /** Deletes row [rowNumber] (1-based, header is row 1) entirely, shifting
   * rows below it up -- used for removing a catalyst. */
  async deleteRow(tab: SheetTab, rowNumber: number): Promise<void> {
    const ids = await this.tabIds();
    const sheetId = ids[tab.title];
    if (sheetId == null) return;
    const headers = await this.headers();
    const res = await fetch(`${SHEETS_API}/${this.spreadsheetId}:batchUpdate`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        requests: [
          {
            deleteDimension: {
              range: { sheetId, dimension: "ROWS", startIndex: rowNumber - 1, endIndex: rowNumber },
            },
          },
        ],
      }),
    });
    await this.check(res);
  }
}
