import { config } from "../config.js";
import { fetchJson } from "./base.js";

const CMC_CAL = "https://api.coinmarketcal.com/v2";

export interface CoinMarketCalCoin {
  slug: string;
  symbol: string;
  name: string;
}

// Confirmed against a live response (2026-07-26) -- CoinMarketCal's docs
// 403'd while this was first built, so this shape replaces an earlier
// best-guess version that had two wrong field names (date_event -> date,
// source -> sourceUrl). No `categories` field is present on real events
// despite being documented in third-party client libraries; event-type
// classification falls back to the title alone.
export interface CoinMarketCalEvent {
  id: string;
  slug: string;
  title: string;
  description: string | null;
  date: string;
  dateEnd?: string;
  coins: CoinMarketCalCoin[];
  categories?: { name: string }[];
  sourceUrl: string | null;
}

function toDateRangeParam(date: Date): string {
  const mm = String(date.getMonth() + 1).padStart(2, "0");
  const dd = String(date.getDate()).padStart(2, "0");
  return `${mm}/${dd}/${date.getFullYear()}`;
}

/**
 * Fetches upcoming events across ALL coins (not filtered server-side by our
 * watchlist) for a date window, and lets the caller match events to our
 * tokens itself. CoinMarketCal's own coin identifiers aren't guaranteed to
 * line up with our coingeckoId values, so matching client-side by
 * ticker/name -- with the same collision caution used everywhere else in
 * this app -- is safer than trusting a server-side `coins=` filter to
 * resolve the right asset.
 */
export async function fetchCoinMarketCalEvents(daysAhead = 90, max = 300): Promise<CoinMarketCalEvent[] | null> {
  if (!config.coinMarketCalApiKey) return null;

  const now = new Date();
  const until = new Date(now.getTime() + daysAhead * 24 * 60 * 60 * 1000);

  const params = new URLSearchParams({
    dateRangeStart: toDateRangeParam(now),
    dateRangeEnd: toDateRangeParam(until),
    max: String(max),
    sortBy: "created_desc",
  });

  const data = await fetchJson<{ data?: CoinMarketCalEvent[] }>(`${CMC_CAL}/events?${params}`, {
    headers: { "x-api-key": config.coinMarketCalApiKey },
  });
  return data?.data ?? null;
}

export function eventTitle(event: CoinMarketCalEvent): string {
  return event.title || "Untitled event";
}
