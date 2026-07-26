import { fetchJson } from "./base.js";

// alternative.me's Fear & Greed Index -- free, keyless, no rate-limit
// concerns observed. Confirmed live before use (curl, no API key needed).
// Market-wide, not per-token: blends volatility, momentum/volume, social
// volume, surveys, dominance, and trends into one daily 0-100 number, per
// their own published methodology. This is NOT itself a prediction -- it's
// a real-time snapshot of aggregate market mood, same category as
// CoinGecko's own sentiment_votes_up/down_percentage already used elsewhere
// in this app.
const FNG_URL = "https://api.alternative.me/fng/?limit=1";

export interface FearGreedIndex {
  value: number;
  classification: string;
  updatedAt: string;
}

interface FearGreedResponse {
  data: { value: string; value_classification: string; timestamp: string }[];
}

export async function fetchFearGreedIndex(): Promise<FearGreedIndex | null> {
  const data = await fetchJson<FearGreedResponse>(FNG_URL);
  const entry = data?.data?.[0];
  if (!entry) return null;
  return {
    value: Number(entry.value),
    classification: entry.value_classification,
    updatedAt: new Date(Number(entry.timestamp) * 1000).toISOString(),
  };
}
