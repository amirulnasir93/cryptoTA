// Replaces api/client.ts as the frontend's data layer: talks directly to the
// Google Sheet (via sheetsClient.ts) and the price/market-data APIs (via
// @crypto-analyzer/shared's connectors), computing indicators locally -- no
// backend involved at all. Mirrors mobile/lib/repository.dart's design
// closely (same synthetic "id = Sheet row number" scheme, same labels-are-
// just-a-column simplification), adapted to reuse the shared TS types
// directly instead of redeclaring them, since there's no Dart-style language
// boundary here.
import type {
  Token,
  TokenDetail,
  TokenDeployment,
  Label,
  Catalyst,
  MetricSnapshot,
  DashboardSummary,
  ClusterExposure,
  TokenAnalysisResult,
  TokenInsightResult,
  ChartInterval,
  AnalysisPoint,
  DivergenceFlag,
  KeyLevel,
  TrendChannel,
  CreateTokenInput,
  CoingeckoSearchResult,
} from "@crypto-analyzer/shared";
import {
  divergence,
  horizonsFor,
  dataQualityFor,
  collisionWarningFor,
  buildCandles,
  INTERVAL_FETCH_DAYS,
  computeRSI,
  computeStochasticRSI,
  computeMACD,
  computeOBV,
  classifyTrend,
  detectDivergence,
  findKeyLevels,
  computeTrendChannel,
  fetchCoingeckoMarkets,
  fetchCoingeckoMarketChart,
  fetchCoingeckoCoinDetail,
  fetchDexPrice,
  fetchProtocol,
  fetchBinanceTicker,
  fetchFearGreedIndex,
  searchCoingecko as searchCoingeckoConnector,
} from "@crypto-analyzer/shared";
import { SheetsClient, watchlistTab, catalystsTab } from "./sheetsClient";

const VALID_STATUSES = ["active", "archived", "removed"];
const MIN_CANDLES_FOR_ANALYSIS = 40;

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Omit (not just intersect) Token's own `labels: Label[]` -- `Partial<Token> &
// { labels?: string[] }` would otherwise intersect the two labels types
// instead of replacing one with the other, collapsing to the unusable
// `Label[] & string[]`.
type TokenPatch = Omit<Partial<Token>, "labels"> & { labels?: string[] };

/** Mirrors packages/backend/src/jobs/syncDecision.ts's parseLabelList/
 * formatLabelList -- same comma-separated, alphabetically-sorted format, so
 * this client and the web backend's own Sheet sync agree on how the
 * "Labels" column is written. */
export function parseLabelList(value: string): string[] {
  return value.split(",").map((s) => s.trim()).filter(Boolean);
}

export function formatLabelList(names: string[]): string {
  return [...names].sort((a, b) => a.localeCompare(b)).join(", ");
}

// Deterministic string hash for a synthetic Label.id -- labels have no real
// numeric primary key anymore (a label is just a distinct value of the
// Sheet's "Labels" column), but the shared Label type still wants a number.
function hashString(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (h << 5) - h + s.charCodeAt(i);
    h |= 0;
  }
  return h;
}

export class Repository {
  private snapshots = new Map<string, MetricSnapshot>();
  private sheets: SheetsClient;
  private coingeckoApiKey?: string;

  constructor(sheets: SheetsClient, coingeckoApiKey?: string) {
    this.sheets = sheets;
    this.coingeckoApiKey = coingeckoApiKey;
  }

  private tokenFromRow(rowNumber: number, row: string[]): Token {
    const ticker = row[0].trim().toUpperCase();
    const contract = row[3];
    const chain = row[2];
    const deployments: TokenDeployment[] = contract
      ? [{ id: 0, chain, contractAddress: contract, isPrimaryLiquidity: true, notes: null }]
      : [];
    return {
      id: rowNumber,
      ticker,
      projectName: row[1] || null,
      primaryChain: chain || null,
      coingeckoId: row[4] || null,
      defillamaSlug: row[5] || null,
      binanceSymbol: row[6] || null,
      mexcSymbol: row[7] || null,
      cluster: row[8] || null,
      notes: row[9] || null,
      collisionWarning: collisionWarningFor(ticker),
      status: (VALID_STATUSES.includes(row[11]) ? row[11] : "active") as Token["status"],
      createdAt: "",
      updatedAt: "",
      deployments,
      labels: parseLabelList(row[10]).map((n) => ({ id: hashString(n), name: n, color: null })),
      latestSnapshot: this.snapshots.get(ticker) ?? null,
    };
  }

  private rowFromToken(t: Token): string[] {
    const contract = t.deployments[0]?.contractAddress ?? "";
    return [
      t.ticker,
      t.projectName ?? "",
      t.primaryChain ?? "",
      contract,
      t.coingeckoId ?? "",
      t.defillamaSlug ?? "",
      t.binanceSymbol ?? "",
      t.mexcSymbol ?? "",
      t.cluster ?? "",
      t.notes ?? "",
      formatLabelList(t.labels.map((l) => l.name)),
      t.status,
    ];
  }

  private async allTokenRows(): Promise<Token[]> {
    const rows = await this.sheets.readRows(watchlistTab);
    return rows.map((row, i) => this.tokenFromRow(i + 2, row));
  }

  async listTokens(status?: string): Promise<Token[]> {
    const all = await this.allTokenRows();
    if (status === "all") return all;
    if (status) return all.filter((t) => t.status === status);
    return all.filter((t) => t.status !== "removed");
  }

  // Reads the whole Catalysts tab once -- getDashboard() needs catalysts for
  // every active token, and re-reading the same tab per-token in a loop would
  // multiply Sheets API calls by the watchlist size for no reason (real risk
  // against Google's per-minute read quota on a larger watchlist).
  private async allCatalystRows(): Promise<{ ticker: string; catalyst: Catalyst }[]> {
    const rows = await this.sheets.readRows(catalystsTab);
    return rows.map((row, i) => ({
      ticker: row[0].trim().toUpperCase(),
      catalyst: {
        id: i + 2,
        tokenId: 0,
        eventDate: row[1],
        eventType: (row[2] || "other") as Catalyst["eventType"],
        description: row[3],
        sizePctOfSupply: row[4] ? Number(row[4]) : null,
        sourceUrl: row[5] || null,
      },
    }));
  }

  private async catalystsFor(ticker: string): Promise<Catalyst[]> {
    const all = await this.allCatalystRows();
    return all
      .filter((r) => r.ticker === ticker)
      .map((r) => r.catalyst)
      .sort((a, b) => a.eventDate.localeCompare(b.eventDate));
  }

  async getToken(rowNumber: number): Promise<TokenDetail> {
    const all = await this.allTokenRows();
    const token = all.find((t) => t.id === rowNumber);
    if (!token) throw new Error(`Token row ${rowNumber} not found`);
    const catalysts = await this.catalystsFor(token.ticker);
    const clusterSiblings: TokenDetail["clusterSiblings"] = token.cluster
      ? all
          .filter((t) => t.cluster === token.cluster && t.id !== token.id && t.status !== "removed")
          .map((t) => ({ id: t.id, ticker: t.ticker, projectName: t.projectName, latestSnapshot: t.latestSnapshot }))
      : [];
    return { ...token, history: [], catalysts, clusterSiblings };
  }

  // labelNames is resolved from CreateTokenInput.labelIds by the caller (the
  // hashed numeric ids only mean something against the currently-known
  // labels list, which lives in the UI layer, not here).
  async createToken(input: CreateTokenInput, labelNames: string[] = []): Promise<Token> {
    const ticker = input.ticker.trim().toUpperCase();
    const token: Token = {
      id: 0,
      ticker,
      projectName: input.projectName ?? null,
      primaryChain: input.primaryChain ?? null,
      coingeckoId: input.coingeckoId ?? null,
      defillamaSlug: input.defillamaSlug ?? null,
      binanceSymbol: null,
      mexcSymbol: null,
      cluster: input.cluster ?? null,
      notes: input.notes ?? null,
      collisionWarning: collisionWarningFor(ticker),
      status: "active",
      createdAt: "",
      updatedAt: "",
      deployments: [],
      labels: labelNames.map((n) => ({ id: hashString(n), name: n, color: null })),
      latestSnapshot: null,
    };
    const rowNumber = await this.sheets.appendRow(watchlistTab, this.rowFromToken(token));
    return { ...token, id: rowNumber };
  }

  private async patchToken(rowNumber: number, patch: TokenPatch): Promise<void> {
    const all = await this.allTokenRows();
    const current = all.find((t) => t.id === rowNumber);
    if (!current) throw new Error(`Token row ${rowNumber} not found`);
    const merged: Token = {
      ...current,
      ...patch,
      labels: patch.labels ? patch.labels.map((n) => ({ id: hashString(n), name: n, color: null })) : current.labels,
    };
    await this.sheets.updateRow(watchlistTab, rowNumber, this.rowFromToken(merged));
  }

  updateToken(rowNumber: number, patch: TokenPatch): Promise<void> {
    return this.patchToken(rowNumber, patch);
  }
  archiveToken(rowNumber: number): Promise<void> {
    return this.patchToken(rowNumber, { status: "archived" });
  }
  restoreToken(rowNumber: number): Promise<void> {
    return this.patchToken(rowNumber, { status: "active" });
  }
  // Soft delete only, matching the web backend's DELETE /tokens/:id -- never
  // a real row removal, so catalyst history for this ticker survives.
  removeToken(rowNumber: number): Promise<void> {
    return this.patchToken(rowNumber, { status: "removed" });
  }

  async createCatalyst(input: {
    ticker: string;
    eventDate: string;
    eventType: string;
    description: string;
    sizePctOfSupply?: number;
    sourceUrl?: string;
  }): Promise<void> {
    await this.sheets.appendRow(catalystsTab, [
      input.ticker.toUpperCase(),
      input.eventDate,
      input.eventType,
      input.description,
      input.sizePctOfSupply?.toString() ?? "",
      input.sourceUrl ?? "",
    ]);
  }

  deleteCatalyst(rowNumber: number): Promise<void> {
    return this.sheets.deleteRow(catalystsTab, rowNumber);
  }

  /** Distinct label names seen across every (non-removed) token row -- there
   * is no separate Labels table now that the Sheet's own "Labels" column is
   * the source of truth. */
  async listLabels(): Promise<Label[]> {
    const all = await this.allTokenRows();
    const names = new Set<string>();
    for (const t of all) {
      if (t.status === "removed") continue;
      for (const l of t.labels) names.add(l.name);
    }
    return [...names].sort().map((n) => ({ id: hashString(n), name: n, color: null }));
  }

  async deleteLabelEverywhere(name: string): Promise<void> {
    const all = await this.allTokenRows();
    for (const t of all) {
      if (t.labels.some((l) => l.name === name)) {
        const remaining = t.labels.map((l) => l.name).filter((n) => n !== name);
        await this.patchToken(t.id, { labels: remaining });
      }
    }
  }

  /** Refreshes live price/market data for the given tokens. Not a background
   * cron -- called on app open and via a "Refresh now" button; browsers
   * can't run anything while the tab is closed anyway. MEXC is skipped here
   * (unlike the backend/mobile): its API sends no CORS headers, so a
   * browser blocks it outright -- verified live before building this,
   * not assumed. divergence()/dataQualityFor() already operate on whatever
   * prices are present, so losing one of four sources doesn't break
   * anything. */
  async refreshPrices(tokens: Token[]): Promise<void> {
    const ids = tokens.map((t) => t.coingeckoId).filter((id): id is string => !!id);
    const markets = await fetchCoingeckoMarkets(ids, this.coingeckoApiKey);

    for (const token of tokens) {
      const market = token.coingeckoId ? markets[token.coingeckoId] : undefined;
      const contract = token.deployments[0]?.contractAddress ?? null;

      const [dex, binance, protocol] = await Promise.all([
        fetchDexPrice(contract),
        fetchBinanceTicker(token.binanceSymbol),
        fetchProtocol(token.defillamaSlug),
      ]);

      const cgPrice = market?.current_price ?? null;
      const div = divergence([cgPrice, dex?.price ?? null, binance?.price ?? null]);
      const volume24h = market?.total_volume ?? dex?.liquidityUsd ?? null;
      const gate = horizonsFor(div, volume24h);
      const quality = dataQualityFor(div);

      const circulating = market?.circulating_supply ?? null;
      const total = market?.total_supply ?? null;
      const marketCap = market?.market_cap ?? null;

      this.snapshots.set(token.ticker, {
        id: 0,
        tokenId: token.id,
        fetchedAt: new Date().toISOString(),
        imageUrl: market?.image ?? null,
        priceCoingecko: cgPrice,
        priceDexscreener: dex?.price ?? null,
        priceBinance: binance?.price ?? null,
        priceMexc: null,
        divergencePct: div,
        marketCap,
        fdv: market?.fully_diluted_valuation ?? null,
        volume24h,
        volumeToMcap: volume24h != null && marketCap ? volume24h / marketCap : null,
        change1hPct: market?.price_change_percentage_1h_in_currency ?? null,
        change24hPct: market?.price_change_percentage_24h_in_currency ?? null,
        change7dPct: market?.price_change_percentage_7d_in_currency ?? null,
        change30dPct: market?.price_change_percentage_30d_in_currency ?? null,
        ath: market?.ath ?? null,
        drawdownFromAthPct: market?.ath_change_percentage ?? null,
        atl: market?.atl ?? null,
        aboveAtlPct: market?.atl_change_percentage ?? null,
        circulatingSupply: circulating,
        totalSupply: total,
        floatPct: circulating != null && total ? (circulating / total) * 100 : null,
        tvl: protocol?.tvl ?? null,
        tvlChange30dPct: protocol?.tvlChange30dPct ?? null,
        dataQuality: quality,
        assessableHorizons: gate.allowed,
        gatingReason: gate.reason,
      });

      await sleep(1200);
    }
  }

  async refreshAndGetDashboard(): Promise<DashboardSummary> {
    const tokens = await this.listTokens("active");
    await this.refreshPrices(tokens);
    return this.getDashboard();
  }

  async getDashboard(): Promise<DashboardSummary> {
    const tokens = await this.listTokens("active");

    const dataQualityCounts = { Good: 0, Degraded: 0, Poor: 0, Unknown: 0 };
    for (const t of tokens) {
      const q = t.latestSnapshot?.dataQuality;
      if (q === "Good" || q === "Degraded" || q === "Poor") dataQualityCounts[q]++;
      else dataQualityCounts.Unknown++;
    }

    const clusterMap = new Map<string, string[]>();
    for (const t of tokens) {
      const key = t.cluster ?? "Uncategorized";
      if (!clusterMap.has(key)) clusterMap.set(key, []);
      clusterMap.get(key)!.push(t.ticker);
    }
    const clusterExposure: ClusterExposure[] = [...clusterMap.entries()]
      .map(([cluster, tickers]) => ({ cluster, tokenCount: tickers.length, tickers }))
      .sort((a, b) => b.tokenCount - a.tokenCount);

    const now = new Date();
    const tickers = new Set(tokens.map((t) => t.ticker));
    const allCatalysts = await this.allCatalystRows();
    const upcoming: DashboardSummary["upcomingCatalysts"] = [];
    for (const { ticker, catalyst: c } of allCatalysts) {
      if (!tickers.has(ticker)) continue;
      const eventDate = new Date(c.eventDate);
      if (isNaN(eventDate.getTime())) continue;
      const daysUntil = Math.ceil((eventDate.getTime() - now.getTime()) / (24 * 60 * 60 * 1000));
      if (daysUntil < 0 || daysUntil > 90) continue;
      upcoming.push({ ...c, ticker, daysUntil });
    }
    upcoming.sort((a, b) => a.eventDate.localeCompare(b.eventDate));

    const movers = tokens
      .filter((t) => t.latestSnapshot?.change24hPct != null)
      .sort((a, b) => Math.abs(b.latestSnapshot!.change24hPct!) - Math.abs(a.latestSnapshot!.change24hPct!))
      .slice(0, 5)
      .map((t) => ({ ticker: t.ticker, tokenId: t.id, change24hPct: t.latestSnapshot!.change24hPct }));

    // A single, cheap, keyless call (market-wide, not per-token) -- fetched
    // fresh on every dashboard load rather than cached, unlike the per-token
    // refresh loop's pacing concerns.
    const fearGreed = await fetchFearGreedIndex();

    return {
      generatedAt: now.toISOString(),
      tokenCount: tokens.length,
      dataQualityCounts,
      clusterExposure,
      upcomingCatalysts: upcoming,
      movers,
      tokens,
      fearGreed,
    };
  }

  async getTokenAnalysis(rowNumber: number, interval: ChartInterval): Promise<TokenAnalysisResult> {
    const token = await this.getToken(rowNumber);
    if (!token.coingeckoId) {
      return {
        available: false,
        reason: "No CoinGecko id on this token, so there's no historical price series to compute indicators from.",
      };
    }

    const outcome = await fetchCoingeckoMarketChart(token.coingeckoId, INTERVAL_FETCH_DAYS[interval], this.coingeckoApiKey);
    if (!outcome.ok) {
      const reason =
        outcome.reason === "rate_limited"
          ? "CoinGecko rate-limited this request (the free public tier's limit is low and shared across everyone hitting it). Wait a few seconds and try again -- this isn't a real data gap."
          : "CoinGecko did not return historical data for this token.";
      return { available: false, reason };
    }

    const rawTimestamps = outcome.data.prices.map((p) => p.timestamp);
    const rawCloses = outcome.data.prices.map((p) => p.value);
    const rawVolumes = alignVolumes(outcome.data.prices, outcome.data.volumes);

    const candles = buildCandles(interval, rawTimestamps, rawCloses, rawVolumes);
    const closes = candles.map((c) => c.close);
    const volumes = candles.map((c) => c.volume);

    if (closes.length < MIN_CANDLES_FOR_ANALYSIS) {
      const reason =
        interval === "1M"
          ? `Only ${closes.length} monthly candle(s) available -- CoinGecko's free tier caps historical queries at 365 days (~12 months), which isn't enough for MACD/RSI to warm up (need ~${MIN_CANDLES_FOR_ANALYSIS}). Try 1w or 1d instead.`
          : `Only ${closes.length} candle(s) of history available at ${interval} -- need at least ${MIN_CANDLES_FOR_ANALYSIS} for MACD/RSI to mean anything. Try a coarser interval.`;
      return { available: false, reason };
    }

    const rsi = computeRSI(closes);
    const stochRsi = computeStochasticRSI(closes);
    const macd = computeMACD(closes);
    const obv = computeOBV(closes, volumes);
    const trend = classifyTrend(closes, macd);

    const points: AnalysisPoint[] = candles.map((c, i) => ({
      timestamp: new Date(c.timestamp).toISOString(),
      open: c.open,
      high: c.high,
      low: c.low,
      close: c.close,
      volume: c.volume,
      rsi: rsi[i],
      stochRsiK: stochRsi[i]?.k ?? null,
      stochRsiD: stochRsi[i]?.d ?? null,
      macd: macd[i]?.macd ?? null,
      macdSignal: macd[i]?.signal ?? null,
      macdHistogram: macd[i]?.histogram ?? null,
      obv: obv[i],
    }));

    const recentCutoff = closes.length - 14;
    const rsiDivergence = detectDivergence(closes, rsi).map((f) => ({ indicator: "RSI" as const, ...f }));
    const obvDivergence = detectDivergence(closes, obv).map((f) => ({ indicator: "OBV" as const, ...f }));
    const divergences: DivergenceFlag[] = [...rsiDivergence, ...obvDivergence]
      .filter((f) => f.toIndex >= recentCutoff)
      .map((f) => ({
        indicator: f.indicator,
        type: f.type,
        fromDate: points[f.fromIndex].timestamp,
        toDate: points[f.toIndex].timestamp,
      }));

    const keyLevels: KeyLevel[] = findKeyLevels(closes);
    const rawChannel = computeTrendChannel(closes);
    const timestamps = candles.map((c) => c.timestamp);
    const spacing = averageSpacing(timestamps);
    const trendChannel: TrendChannel | null = rawChannel
      ? {
          upper: {
            fromTimestamp: indexToTimestamp(rawChannel.upper.fromIndex, timestamps, spacing),
            fromPrice: rawChannel.upper.fromPrice,
            toTimestamp: indexToTimestamp(rawChannel.upper.toIndex, timestamps, spacing),
            toPrice: rawChannel.upper.toPrice,
          },
          lower: {
            fromTimestamp: indexToTimestamp(rawChannel.lower.fromIndex, timestamps, spacing),
            fromPrice: rawChannel.lower.fromPrice,
            toTimestamp: indexToTimestamp(rawChannel.lower.toIndex, timestamps, spacing),
            toPrice: rawChannel.lower.toPrice,
          },
        }
      : null;

    return {
      available: true,
      tokenId: token.id,
      ticker: token.ticker,
      asOf: new Date().toISOString(),
      interval,
      points,
      divergences,
      trend,
      keyLevels,
      trendChannel,
    };
  }

  async getTokenInsight(rowNumber: number): Promise<TokenInsightResult> {
    const token = await this.getToken(rowNumber);
    if (!token.coingeckoId) {
      return { available: false, reason: "No CoinGecko id on this token, so there's no project data to show." };
    }
    const detail = await fetchCoingeckoCoinDetail(token.coingeckoId, this.coingeckoApiKey);
    if (!detail) {
      return {
        available: false,
        reason: "CoinGecko did not return project details for this token (may just be rate-limited -- try again shortly).",
      };
    }
    const twitterHandle = detail.links?.twitter_screen_name;
    const telegramHandle = detail.links?.telegram_channel_identifier;
    return {
      available: true,
      description: detail.description?.en?.trim() || null,
      categories: detail.categories ?? [],
      genesisDate: detail.genesis_date,
      marketCapRank: detail.market_cap_rank,
      sentimentUpPct: detail.sentiment_votes_up_percentage,
      sentimentDownPct: detail.sentiment_votes_down_percentage,
      watchlistPortfolioUsers: detail.watchlist_portfolio_users ?? null,
      links: {
        homepage: (detail.links?.homepage ?? []).filter(Boolean),
        twitter: twitterHandle ? `https://twitter.com/${twitterHandle}` : null,
        telegram: telegramHandle ? `https://t.me/${telegramHandle}` : null,
        subreddit: detail.links?.subreddit_url || null,
        github: (detail.links?.repos_url?.github ?? []).filter(Boolean),
        chat: (detail.links?.chat_url ?? []).filter(Boolean),
      },
      community: {
        redditSubscribers: detail.community_data?.reddit_subscribers ?? null,
        telegramUserCount: detail.community_data?.telegram_channel_user_count ?? null,
        redditAveragePosts48h: detail.community_data?.reddit_average_posts_48h ?? null,
        redditAverageComments48h: detail.community_data?.reddit_average_comments_48h ?? null,
        redditAccountsActive48h: detail.community_data?.reddit_accounts_active_48h ?? null,
      },
      developer: {
        stars: detail.developer_data?.stars ?? null,
        forks: detail.developer_data?.forks ?? null,
        subscribers: detail.developer_data?.subscribers ?? null,
        totalIssues: detail.developer_data?.total_issues ?? null,
        closedIssues: detail.developer_data?.closed_issues ?? null,
        pullRequestsMerged: detail.developer_data?.pull_requests_merged ?? null,
        pullRequestContributors: detail.developer_data?.pull_request_contributors ?? null,
        commitCount4Weeks: detail.developer_data?.commit_count_4_weeks ?? null,
      },
    };
  }

  searchCoingecko(query: string): Promise<CoingeckoSearchResult[]> {
    return searchCoingeckoConnector(query);
  }
}

function alignVolumes(
  prices: { timestamp: number; value: number }[],
  volumes: { timestamp: number; value: number }[]
): number[] {
  if (prices.length === volumes.length) return volumes.map((v) => v.value);
  return prices.map((p) => {
    let closest = volumes[0]?.value ?? 0;
    let bestDelta = Infinity;
    for (const v of volumes) {
      const delta = Math.abs(v.timestamp - p.timestamp);
      if (delta < bestDelta) {
        bestDelta = delta;
        closest = v.value;
      }
    }
    return closest;
  });
}

function averageSpacing(timestamps: number[]): number {
  if (timestamps.length < 2) return 0;
  let total = 0;
  for (let i = 1; i < timestamps.length; i++) total += timestamps[i] - timestamps[i - 1];
  return total / (timestamps.length - 1);
}

function indexToTimestamp(index: number, timestamps: number[], spacing: number): string {
  if (index < timestamps.length) return new Date(timestamps[Math.round(index)]).toISOString();
  const overshoot = index - (timestamps.length - 1);
  return new Date(timestamps[timestamps.length - 1] + overshoot * spacing).toISOString();
}
