import "dotenv/config";

function required(name: string, fallback?: string): string {
  const value = process.env[name] ?? fallback;
  if (value === undefined) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

export const config = {
  port: Number(process.env.PORT ?? 3001),
  webOrigin: process.env.WEB_ORIGIN ?? "http://localhost:5173",
  refreshSecret: required("REFRESH_SECRET", "change-me"),
  coingeckoApiKey: process.env.COINGECKO_API_KEY || undefined,
  googleServiceAccountFile:
    process.env.GOOGLE_SERVICE_ACCOUNT_FILE ?? "./secrets/service-account.json",
  googleSheetId: process.env.GOOGLE_SHEET_ID || undefined,
  refreshCron: process.env.REFRESH_CRON ?? "*/5 * * * *",
  sheetSyncCron: process.env.SHEET_SYNC_CRON ?? "*/5 * * * *",
  coinMarketCalApiKey: process.env.COINMARKETCAL_API_KEY || undefined,
  catalystSyncCron: process.env.CATALYST_SYNC_CRON ?? "0 */6 * * *",
};
