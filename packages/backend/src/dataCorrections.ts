// Corrections to Skills/watchlist.csv's own coingecko_id column, discovered
// while wiring up the refresh job in 2026-07: these ids 404 against
// CoinGecko's API. Each was re-resolved via /search and confirmed by matching
// name, homepage, categories and (where available) on-chain contract against
// the project described in watchlist.csv's own notes/cluster columns — not by
// ticker string alone, which is exactly the failure mode Skills/data-sources.md
// warns about.
//
// Skills/watchlist.csv itself is left untouched (the Claude Skill's data stays
// standalone); this correction only applies to the app's seeded Token rows.
export const COINGECKO_ID_CORRECTIONS: Record<string, string> = {
  // CSV had "apex-token" (404). apex-token-2: homepage apex.exchange,
  // categories Perpetuals/DEX/Derivatives — matches "ApeX Protocol" / Trading
  // venue cluster from the CSV.
  APEX: "apex-token-2",
  // CSV had "recall-network" (404). recall: homepage recall.network,
  // categories AI Agents/Base Native, Base contract
  // 0x1f16e03c1a5908818f47f6ee7bb16690b40d0671 — matches Recall Network /
  // AI-agent cluster and Base chain from the CSV.
  RECALL: "recall",
};
