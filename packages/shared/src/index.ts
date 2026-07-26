// Shared API contract types, imported by both the backend (Fastify) and the
// frontend (React) so the two can't silently drift apart. All dates are ISO
// strings, matching what actually travels over JSON.

// Pure business logic (gating/candles/indicators/collision warnings) and the
// keyless-API connectors live here too now, not just types -- both the
// backend and the standalone frontend need the exact same math and fetch
// logic, and there's no language boundary between them (unlike the Flutter
// mobile app, which needed a real Dart port instead of a shared import).
export * from "./gating.js";
export * from "./candles.js";
export * from "./indicators.js";
export * from "./knownCollisions.js";
export * from "./connectors/base.js";
export * from "./connectors/coingecko.js";
export * from "./connectors/dexscreener.js";
export * from "./connectors/defillama.js";
export * from "./connectors/binanceCompatibleExchange.js";
export * from "./connectors/binance.js";

// `export * from` re-exports these for external consumers but doesn't bind
// them locally -- imported here too since the API-contract types below
// reference them directly (e.g. MetricSnapshot.dataQuality: DataQuality).
import type { DataQuality, Horizon } from "./gating.js";
import type { ChartInterval } from "./candles.js";
import type { TrendState, KeyLevel } from "./indicators.js";

export type TokenStatus = "active" | "archived" | "removed";
// DataQuality and Horizon now come from gating.js (re-exported above) --
// identical shapes, no need for a second declaration here.
export type CatalystType = "unlock" | "listing" | "governance" | "launch" | "other";
export type ConflictResolution = "sheet_won" | "local_won";

export interface TokenDeployment {
  id: number;
  chain: string;
  contractAddress: string | null;
  isPrimaryLiquidity: boolean;
  notes: string | null;
}

export interface Label {
  id: number;
  name: string;
  color: string | null;
}

export interface Catalyst {
  id: number;
  tokenId: number;
  eventDate: string;
  eventType: CatalystType;
  description: string;
  sizePctOfSupply: number | null;
  sourceUrl: string | null;
}

export interface MetricSnapshot {
  id: number;
  tokenId: number;
  fetchedAt: string;
  priceCoingecko: number | null;
  priceDexscreener: number | null;
  priceBinance: number | null;
  priceMexc: number | null;
  divergencePct: number | null;
  marketCap: number | null;
  fdv: number | null;
  volume24h: number | null;
  volumeToMcap: number | null;
  change24hPct: number | null;
  change7dPct: number | null;
  change30dPct: number | null;
  ath: number | null;
  drawdownFromAthPct: number | null;
  circulatingSupply: number | null;
  totalSupply: number | null;
  floatPct: number | null;
  tvl: number | null;
  tvlChange30dPct: number | null;
  dataQuality: DataQuality;
  assessableHorizons: Horizon[];
  gatingReason: string | null;
}

export interface Token {
  id: number;
  ticker: string;
  projectName: string | null;
  primaryChain: string | null;
  coingeckoId: string | null;
  defillamaSlug: string | null;
  binanceSymbol: string | null;
  mexcSymbol: string | null;
  cluster: string | null;
  notes: string | null;
  collisionWarning: string | null;
  status: TokenStatus;
  createdAt: string;
  updatedAt: string;
  deployments: TokenDeployment[];
  labels: Label[];
  latestSnapshot: MetricSnapshot | null;
}

export interface TokenDetail extends Token {
  history: MetricSnapshot[];
  catalysts: Catalyst[];
  clusterSiblings: Pick<Token, "id" | "ticker" | "projectName" | "latestSnapshot">[];
}

export interface CreateTokenInput {
  ticker: string;
  projectName?: string;
  primaryChain?: string;
  coingeckoId?: string;
  defillamaSlug?: string;
  cluster?: string;
  notes?: string;
  labelIds?: number[];
}

export interface ClusterExposure {
  cluster: string;
  tokenCount: number;
  tickers: string[];
}

export interface DashboardSummary {
  generatedAt: string;
  tokenCount: number;
  dataQualityCounts: Record<"Good" | "Degraded" | "Poor" | "Unknown", number>;
  clusterExposure: ClusterExposure[];
  upcomingCatalysts: (Catalyst & { ticker: string; daysUntil: number })[];
  movers: {
    ticker: string;
    tokenId: number;
    change24hPct: number | null;
  }[];
  tokens: Token[];
}

export interface ConflictLogEntry {
  id: number;
  tokenId: number;
  ticker: string;
  detectedAt: string;
  field: string;
  localValue: string | null;
  sheetValue: string | null;
  resolution: ConflictResolution;
}

// TrendState now comes from indicators.js and ChartInterval from candles.js
// (both re-exported above) -- identical shapes to what used to be declared
// here, no need for a second declaration.

export interface AnalysisPoint {
  timestamp: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
  rsi: number | null;
  stochRsiK: number | null;
  stochRsiD: number | null;
  macd: number | null;
  macdSignal: number | null;
  macdHistogram: number | null;
  obv: number;
}

export interface DivergenceFlag {
  indicator: "RSI" | "OBV";
  type: "bullish" | "bearish";
  fromDate: string;
  toDate: string;
}

// KeyLevel now comes from indicators.js (re-exported above) -- identical
// shape, no need for a second declaration.

// A line through two real swing points, extended forward -- a geometric read
// of observed structure, never a statistical/ML price prediction. Timestamps
// (not indices) so the frontend can plot it directly against the time axis.
export interface ChannelLine {
  fromTimestamp: string;
  fromPrice: number;
  toTimestamp: string;
  toPrice: number;
}

export interface TrendChannel {
  upper: ChannelLine;
  lower: ChannelLine;
}

export interface TokenAnalysis {
  available: true;
  tokenId: number;
  ticker: string;
  asOf: string;
  interval: ChartInterval;
  points: AnalysisPoint[];
  divergences: DivergenceFlag[];
  trend: { state: TrendState; basis: string };
  keyLevels: KeyLevel[];
  trendChannel: TrendChannel | null;
}

export interface TokenAnalysisUnavailable {
  available: false;
  reason: string;
}

export type TokenAnalysisResult = TokenAnalysis | TokenAnalysisUnavailable;

// Project background, not price/TA data -- sourced from CoinGecko's free,
// keyless /coins/{id} endpoint (description, official links, community and
// developer activity). This is the "grab info from the web" panel; it's
// deliberately NOT a news feed -- there's no free, keyless crypto news API
// (CoinGecko's own News API and DefiLlama's unlock data are paid-tier only,
// confirmed while researching catalyst sources for this same app).
export interface TokenInsightLinks {
  homepage: string[];
  twitter: string | null;
  telegram: string | null;
  subreddit: string | null;
  github: string[];
  chat: string[];
}

export interface TokenInsightCommunity {
  redditSubscribers: number | null;
  telegramUserCount: number | null;
}

export interface TokenInsightDeveloper {
  stars: number | null;
  forks: number | null;
  subscribers: number | null;
  totalIssues: number | null;
  closedIssues: number | null;
  pullRequestsMerged: number | null;
  pullRequestContributors: number | null;
  commitCount4Weeks: number | null;
}

export interface TokenInsight {
  available: true;
  description: string | null;
  categories: string[];
  genesisDate: string | null;
  marketCapRank: number | null;
  sentimentUpPct: number | null;
  sentimentDownPct: number | null;
  links: TokenInsightLinks;
  community: TokenInsightCommunity;
  developer: TokenInsightDeveloper;
}

export interface TokenInsightUnavailable {
  available: false;
  reason: string;
}

export type TokenInsightResult = TokenInsight | TokenInsightUnavailable;

// CoingeckoSearchResult now comes from connectors/coingecko.js (re-exported
// above) -- identical shape, no need for a second declaration.

export interface SyncResult {
  ranAt: string;
  pushed: string[];
  pulled: string[];
  created: string[];
  archived: string[];
  conflicts: ConflictLogEntry[];
}
