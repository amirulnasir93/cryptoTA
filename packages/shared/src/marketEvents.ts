import { eventTitle, type CoinMarketCalEvent } from "./connectors/coinmarketcal.js";

export type MarketEventType = "unlock" | "listing" | "governance" | "launch" | "other";

const CATEGORY_TO_EVENT_TYPE: { patterns: string[]; eventType: MarketEventType }[] = [
  { patterns: ["unlock", "vesting", "cliff"], eventType: "unlock" },
  { patterns: ["listing", "exchange"], eventType: "listing" },
  { patterns: ["governance", "vote", "proposal"], eventType: "governance" },
  { patterns: ["mainnet", "launch", "upgrade", "fork", "release"], eventType: "launch" },
];

export function classifyEventType(event: CoinMarketCalEvent): MarketEventType {
  const categoryNames = (event.categories ?? []).map((c) => c.name.toLowerCase());
  const title = eventTitle(event).toLowerCase();
  for (const { patterns, eventType } of CATEGORY_TO_EVENT_TYPE) {
    if (categoryNames.some((c) => patterns.some((p) => c.includes(p))) || patterns.some((p) => title.includes(p))) {
      return eventType;
    }
  }
  return "other";
}

function normalize(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]/g, "");
}

export interface MarketEvent {
  ticker: string;
  description: string;
  eventDate: string;
  eventType: MarketEventType;
  sourceUrl: string | null;
  daysUntil: number;
}

/**
 * Matches CoinMarketCal's uncurated, all-coins event feed against a
 * watchlist, read-only (no Sheet/DB write -- this is the standalone web/
 * mobile clients' path; the self-hosted backend's own catalystSyncJob.ts
 * does the write side, sharing this exact matching logic).
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
export function matchWatchlistEvents(
  events: CoinMarketCalEvent[],
  tokens: { ticker: string; projectName: string | null }[],
  daysAhead = 90
): MarketEvent[] {
  const now = new Date();
  const out: MarketEvent[] = [];

  for (const event of events) {
    const description = eventTitle(event);
    const eventDate = new Date(event.date);
    if (Number.isNaN(eventDate.getTime())) continue;
    const daysUntil = Math.ceil((eventDate.getTime() - now.getTime()) / (24 * 60 * 60 * 1000));
    if (daysUntil < 0 || daysUntil > daysAhead) continue;

    for (const coin of event.coins ?? []) {
      const symbol = (coin.symbol ?? "").toUpperCase();
      const token = tokens.find((t) => t.ticker === symbol);
      if (!token) continue;

      const projectFragment = token.projectName ? normalize(token.projectName).slice(0, 6) : "";
      const nameMatches = projectFragment.length > 0 && normalize(coin.name ?? "").includes(projectFragment);
      if (!nameMatches) continue;

      out.push({
        ticker: token.ticker,
        description,
        eventDate: eventDate.toISOString(),
        eventType: classifyEventType(event),
        sourceUrl: event.sourceUrl ?? null,
        daysUntil,
      });
    }
  }

  out.sort((a, b) => a.eventDate.localeCompare(b.eventDate));
  return out;
}
