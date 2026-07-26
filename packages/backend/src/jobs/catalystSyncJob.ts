import { prisma } from "../db.js";
import { config } from "../config.js";
import { eventTitle, fetchCoinMarketCalEvents, classifyEventType } from "@crypto-analyzer/shared";

export interface CatalystSyncSummary {
  ranAt: string;
  created: string[];
  skippedCollisionRisk: string[];
  eventsScanned: number;
  skipped?: string;
}

function normalize(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]/g, "");
}

/**
 * Pulls upcoming CoinMarketCal events and auto-creates Catalyst rows for any
 * that match a watchlist token. Idempotent (dedupes on tokenId+eventDate+
 * description) so it's safe to run on a schedule.
 *
 * Every match requires the event's coin *name* to also plausibly match the
 * token's project name, not just the ticker symbol -- not only for the
 * tickers Skills/data-sources.md already flags as collision-prone, but for
 * every token. A live test run surfaced exactly why this matters: an event
 * literally titled "Ethereum Mainnet Launch" matched AERO purely by symbol,
 * and only checking the event's own coin name (which turned out to say
 * "Aerodrome Finance", confirming it was correct) made that verifiable
 * instead of a guess. CoinMarketCal is an external, uncurated calendar --
 * matching on ticker symbol alone against it is exactly the "confident
 * analysis of the wrong asset" failure mode this whole app is designed
 * around, even for tickers not currently known to collide.
 */
export async function runCatalystSync(): Promise<CatalystSyncSummary> {
  const summary: CatalystSyncSummary = {
    ranAt: new Date().toISOString(),
    created: [],
    skippedCollisionRisk: [],
    eventsScanned: 0,
  };

  const events = await fetchCoinMarketCalEvents(config.coinMarketCalApiKey, 90);
  if (!events) {
    summary.skipped =
      "COINMARKETCAL_API_KEY not configured, or CoinMarketCal returned no data -- see docs/CATALYSTS_SETUP.md";
    return summary;
  }
  summary.eventsScanned = events.length;

  const tokens = await prisma.token.findMany({ where: { status: { not: "removed" } } });

  for (const event of events) {
    const description = eventTitle(event);
    const eventDate = new Date(event.date);
    if (Number.isNaN(eventDate.getTime())) continue;

    for (const coin of event.coins ?? []) {
      const symbol = (coin.symbol ?? "").toUpperCase();
      const token = tokens.find((t) => t.ticker === symbol);
      if (!token) continue;

      const projectFragment = token.projectName ? normalize(token.projectName).slice(0, 6) : "";
      const nameMatches = projectFragment.length > 0 && normalize(coin.name ?? "").includes(projectFragment);
      if (!nameMatches) {
        summary.skippedCollisionRisk.push(
          `${token.ticker}: "${description}" (coin name "${coin.name}" didn't clearly match "${token.projectName}")`
        );
        continue;
      }

      const existing = await prisma.catalyst.findFirst({
        where: { tokenId: token.id, eventDate, description },
      });
      if (existing) continue;

      await prisma.catalyst.create({
        data: {
          tokenId: token.id,
          eventDate,
          eventType: classifyEventType(event),
          description,
          sourceUrl: event.sourceUrl ?? null,
        },
      });
      summary.created.push(`${token.ticker}: ${description}`);
    }
  }

  return summary;
}
