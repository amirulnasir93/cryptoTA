import { config } from "../config.js";
import { fetchJson, fetchJsonWithReason, type FetchFailureReason } from "./base.js";

const CG = "https://api.coingecko.com/api/v3";

export interface CoingeckoMarket {
  id: string;
  current_price: number | null;
  market_cap: number | null;
  fully_diluted_valuation: number | null;
  total_volume: number | null;
  price_change_percentage_24h_in_currency?: number | null;
  price_change_percentage_7d_in_currency?: number | null;
  price_change_percentage_30d_in_currency?: number | null;
  ath: number | null;
  ath_change_percentage: number | null;
  circulating_supply: number | null;
  total_supply: number | null;
}

/** Batched lookup: N tokens in one call, not N. */
export async function fetchCoingeckoMarkets(
  ids: string[]
): Promise<Record<string, CoingeckoMarket>> {
  if (ids.length === 0) return {};

  const params = new URLSearchParams({
    vs_currency: "usd",
    ids: ids.join(","),
    price_change_percentage: "24h,7d,30d",
    sparkline: "false",
  });

  const headers: Record<string, string> = {};
  if (config.coingeckoApiKey) headers["x-cg-demo-api-key"] = config.coingeckoApiKey;

  const data = await fetchJson<CoingeckoMarket[]>(`${CG}/coins/markets?${params}`, { headers });
  if (!data) return {};
  return Object.fromEntries(data.map((c) => [c.id, c]));
}

export interface MarketChartPoint {
  timestamp: number;
  value: number;
}

export interface MarketChartResult {
  prices: MarketChartPoint[];
  volumes: MarketChartPoint[];
}

export type MarketChartOutcome =
  | { ok: true; data: MarketChartResult }
  | { ok: false; reason: FetchFailureReason };

/** Historical daily-ish price/volume series -- separate from fetchCoingeckoMarkets
 * because indicators like RSI/MACD need a real time series, not a single
 * current-price point. CoinGecko auto-picks granularity from `days` on the
 * free tier (hourly for a few months back, daily beyond ~90 days).
 *
 * Returns the failure reason (not just null) because "CoinGecko rate-limited
 * us" and "this token genuinely has no chart data" are very different
 * problems for the caller to explain to a user -- the keyless public tier's
 * rate limit is low enough that the former happens routinely under normal
 * use (switching intervals a few times in a row is enough to trip it). */
export async function fetchCoingeckoMarketChart(id: string, days = 90): Promise<MarketChartOutcome> {
  const params = new URLSearchParams({ vs_currency: "usd", days: String(days) });
  const headers: Record<string, string> = {};
  if (config.coingeckoApiKey) headers["x-cg-demo-api-key"] = config.coingeckoApiKey;

  const result = await fetchJsonWithReason<{ prices: [number, number][]; total_volumes: [number, number][] }>(
    `${CG}/coins/${id}/market_chart?${params}`,
    { headers }
  );
  if (!result.ok) return result;

  return {
    ok: true,
    data: {
      prices: result.data.prices.map(([timestamp, value]) => ({ timestamp, value })),
      volumes: result.data.total_volumes.map(([timestamp, value]) => ({ timestamp, value })),
    },
  };
}

export interface CoingeckoCoinDetail {
  description: { en?: string } | null;
  categories: string[] | null;
  genesis_date: string | null;
  market_cap_rank: number | null;
  sentiment_votes_up_percentage: number | null;
  sentiment_votes_down_percentage: number | null;
  links: {
    homepage: string[];
    chat_url: string[];
    twitter_screen_name: string | null;
    telegram_channel_identifier: string | null;
    subreddit_url: string | null;
    repos_url: { github: string[] };
  } | null;
  community_data: {
    reddit_subscribers: number | null;
    telegram_channel_user_count: number | null;
  } | null;
  developer_data: {
    forks: number | null;
    stars: number | null;
    subscribers: number | null;
    total_issues: number | null;
    closed_issues: number | null;
    pull_requests_merged: number | null;
    pull_request_contributors: number | null;
    commit_count_4_weeks: number | null;
  } | null;
}

/** Project background (description/links/community/dev activity) -- a
 * separate, much heavier payload than fetchCoingeckoMarkets, so only fetched
 * on demand for the Insight tab, not on every refresh cycle. Confirmed
 * against a live response before use: CoinGecko dropped twitter-follower
 * counts from community_data a while back (not just undocumented -- genuinely
 * absent from the payload), so that field is deliberately not modeled here. */
export async function fetchCoingeckoCoinDetail(id: string): Promise<CoingeckoCoinDetail | null> {
  const params = new URLSearchParams({
    localization: "false",
    tickers: "false",
    market_data: "false",
    community_data: "true",
    developer_data: "true",
    sparkline: "false",
  });
  const headers: Record<string, string> = {};
  if (config.coingeckoApiKey) headers["x-cg-demo-api-key"] = config.coingeckoApiKey;

  return fetchJson<CoingeckoCoinDetail>(`${CG}/coins/${id}?${params}`, { headers });
}

export interface CoingeckoSearchResult {
  id: string;
  name: string;
  symbol: string;
}

/** Used by the Add Token form's CoinGecko-id typeahead -- picking a search
 * result instead of hand-typing an id is exactly how the APEX/RECALL stale-id
 * bug (see dataCorrections.ts) would have been avoided in the first place. */
export async function searchCoingecko(query: string): Promise<CoingeckoSearchResult[]> {
  if (!query.trim()) return [];
  const params = new URLSearchParams({ query });
  const data = await fetchJson<{ coins: { id: string; name: string; symbol: string }[] }>(
    `${CG}/search?${params}`
  );
  return (data?.coins ?? []).slice(0, 10).map((c) => ({ id: c.id, name: c.name, symbol: c.symbol }));
}
