// Shared API contract types, imported by both the backend (Fastify) and the
// frontend (React) so the two can't silently drift apart. All dates are ISO
// strings, matching what actually travels over JSON.

export type TokenStatus = "active" | "archived" | "removed";
export type DataQuality = "Good" | "Degraded" | "Poor" | null;
export type Horizon = "4h_scalp" | "1d_scalp" | "1d_hold" | "1w_hold" | "1m_hold";
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

// Technical analysis: describes CURRENT indicator state and flags divergence.
// Never a price forecast -- see Skills/SKILL.md's own "this skill does not
// predict prices" principle, which this app deliberately mirrors.
export type TrendState = "Uptrend" | "Downtrend" | "Ranging";

// Candle interval, CEX-style. Changes what each candle *represents* (and what
// period RSI/MACD/StochRSI/OBV are computed over) -- not just how many
// candles are shown.
export type ChartInterval = "15m" | "1h" | "2h" | "4h" | "1d" | "2d" | "3d" | "1w" | "1M";

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

// Support/resistance from actual swing structure -- a record of where price
// has already reacted, not a guess at where it's going next.
export interface KeyLevel {
  price: number;
  type: "support" | "resistance";
  touches: number;
}

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

export interface CoingeckoSearchResult {
  id: string;
  name: string;
  symbol: string;
}

export interface SyncResult {
  ranAt: string;
  pushed: string[];
  pulled: string[];
  created: string[];
  archived: string[];
  conflicts: ConflictLogEntry[];
}
