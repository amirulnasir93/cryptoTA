import { config } from "../config.js";
import { fetchJson } from "./base.js";

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

/** Historical daily-ish price/volume series -- separate from fetchCoingeckoMarkets
 * because indicators like RSI/MACD need a real time series, not a single
 * current-price point. CoinGecko auto-picks granularity from `days` on the
 * free tier (hourly for a few months back, daily beyond ~90 days). */
export async function fetchCoingeckoMarketChart(
  id: string,
  days = 90
): Promise<MarketChartResult | null> {
  const params = new URLSearchParams({ vs_currency: "usd", days: String(days) });
  const headers: Record<string, string> = {};
  if (config.coingeckoApiKey) headers["x-cg-demo-api-key"] = config.coingeckoApiKey;

  const data = await fetchJson<{ prices: [number, number][]; total_volumes: [number, number][] }>(
    `${CG}/coins/${id}/market_chart?${params}`,
    { headers }
  );
  if (!data) return null;

  return {
    prices: data.prices.map(([timestamp, value]) => ({ timestamp, value })),
    volumes: data.total_volumes.map(([timestamp, value]) => ({ timestamp, value })),
  };
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
