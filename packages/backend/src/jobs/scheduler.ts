import cron from "node-cron";
import { config } from "../config.js";
import { runRefresh } from "./refreshJob.js";
import { runSheetSync } from "./sheetSyncJob.js";
import { runCatalystSync } from "./catalystSyncJob.js";
import { isSheetsConfigured } from "../sheets/sheetsClient.js";

let started = false;

export function startScheduler(): void {
  if (started) return;
  started = true;

  console.log(`[scheduler] refresh job on cron "${config.refreshCron}"`);
  cron.schedule(config.refreshCron, () => {
    runRefresh().catch((err) => console.error("[scheduler] refresh job failed:", err));
  });

  if (isSheetsConfigured()) {
    console.log(`[scheduler] sheet sync job on cron "${config.sheetSyncCron}"`);
    cron.schedule(config.sheetSyncCron, () => {
      runSheetSync().catch((err) => console.error("[scheduler] sheet sync job failed:", err));
    });
  } else {
    console.log("[scheduler] sheet sync not configured yet — see docs/SHEETS_SETUP.md");
  }

  if (config.coinMarketCalApiKey) {
    console.log(`[scheduler] catalyst sync job on cron "${config.catalystSyncCron}"`);
    cron.schedule(config.catalystSyncCron, () => {
      runCatalystSync().catch((err) => console.error("[scheduler] catalyst sync job failed:", err));
    });
  } else {
    console.log("[scheduler] catalyst sync not configured yet — see docs/CATALYSTS_SETUP.md");
  }
}
