// Hardcoded from Skills/data-sources.md's "Known traps on the current list" section.
// Used both by the one-time CSV seed and by the add-token API route, so a new
// token typed in later gets the same warning a seeded one does.

export const KNOWN_TICKER_COLLISIONS: Record<string, string> = {
  BASED:
    "Coinbase lists this asset as BASED1, not BASED. Two unrelated micro-cap tokens on Base also use the BASED ticker (coingecko ids based-2, based-coin) and are effectively illiquid. Verify chain + contract before trusting a feed.",
  GENIUS:
    "Distinct from Genius (GENI) on Polygon and Genius Token (GNUS). Verify the CoinGecko id resolves to genius-3.",
  APEX: "Ticker collides with other, unrelated APEX tokens. Match on chain and contract before trusting a feed.",
  ZEST: "Ticker collides with other, unrelated ZEST tokens. Match on chain and contract before trusting a feed.",
  UAI: "Ticker collides with other, unrelated UAI tokens. Match on chain and contract before trusting a feed.",
};

// TON-native protocols whose primary *trading* liquidity sits on BNB Chain — a
// price feed keyed only to the TON contract under-reports volume badly.
export const DUAL_DEPLOYMENT_NOTES: Record<string, string> = {
  EVAA: "TON-native but primary trading liquidity sits on BNB Chain — fetch both deployments.",
  TRADOOR: "TON-native but the BNB deployment holds most trading volume — fetch both deployments.",
};

export function collisionWarningFor(ticker: string): string | null {
  return KNOWN_TICKER_COLLISIONS[ticker.toUpperCase()] ?? null;
}
