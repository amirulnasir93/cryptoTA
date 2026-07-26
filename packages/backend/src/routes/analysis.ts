import type { FastifyInstance } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import {
  type ChartInterval,
  type TokenAnalysisResult,
  type MarketChartPoint,
  fetchCoingeckoMarketChart,
  buildCandles,
  INTERVAL_FETCH_DAYS,
  classifyTrend,
  computeMACD,
  computeOBV,
  computeRSI,
  computeStochasticRSI,
  computeTrendChannel,
  detectDivergence,
  findKeyLevels,
} from "@crypto-analyzer/shared";
import { prisma } from "../db.js";
import { config } from "../config.js";

const idParam = z.object({ id: z.coerce.number() });
const CHART_INTERVALS = ["15m", "1h", "2h", "4h", "1d", "2d", "3d", "1w", "1M"] as const;
const analysisQuery = z.object({ interval: z.enum(CHART_INTERVALS).optional() });

// RSI-14 / MACD-12-26-9 / a 14-period StochRSI are conventional periods that
// apply at whatever interval is selected -- a 14-period RSI on 1h candles and
// a 14-period RSI on daily candles are both "correct," just describing
// different horizons, exactly like a CEX/TradingView chart. What matters is
// that the candles match the requested interval, not raw ticks straight from
// the source (CoinGecko's own granularity by days-requested would otherwise
// leak through unpredictably).
const MIN_CANDLES_FOR_ANALYSIS = 40;

function averageSpacing(timestamps: number[]): number {
  if (timestamps.length < 2) return 0;
  let total = 0;
  for (let i = 1; i < timestamps.length; i++) total += timestamps[i] - timestamps[i - 1];
  return total / (timestamps.length - 1);
}

/** The trend channel's "to" point is a projection a few candles past the end
 * of the fetched data -- there's no real timestamp for it, so one is
 * extrapolated from the series' own average candle spacing. */
function indexToTimestamp(index: number, timestamps: number[], spacing: number): string {
  if (index < timestamps.length) return new Date(timestamps[index]).toISOString();
  const overshoot = index - (timestamps.length - 1);
  return new Date(timestamps[timestamps.length - 1] + overshoot * spacing).toISOString();
}

function alignVolumes(prices: MarketChartPoint[], volumes: MarketChartPoint[]): number[] {
  if (prices.length === volumes.length) return volumes.map((v) => v.value);
  // Defensive fallback for the rare case CoinGecko's two series don't line
  // up 1:1 -- nearest-timestamp match instead of assuming index alignment.
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

export async function analysisRoutes(appRaw: FastifyInstance) {
  const app = appRaw.withTypeProvider<ZodTypeProvider>();

  app.get(
    "/tokens/:id/analysis",
    { schema: { params: idParam, querystring: analysisQuery } },
    async (request, reply): Promise<TokenAnalysisResult> => {
      const interval: ChartInterval = request.query.interval ?? "1d";

      const token = await prisma.token.findUnique({ where: { id: request.params.id } });
      if (!token) {
        reply.code(404);
        return { available: false, reason: "Token not found." };
      }

      if (!token.coingeckoId) {
        return {
          available: false,
          reason: "No CoinGecko id on this token, so there's no historical price series to compute indicators from.",
        };
      }

      const chartOutcome = await fetchCoingeckoMarketChart(
        token.coingeckoId,
        INTERVAL_FETCH_DAYS[interval],
        config.coingeckoApiKey
      );
      if (!chartOutcome.ok) {
        const reason =
          chartOutcome.reason === "rate_limited"
            ? "CoinGecko rate-limited this request (the free public tier's limit is low and shared across everyone hitting it). Wait a few seconds and try again -- this isn't a real data gap."
            : "CoinGecko did not return historical data for this token.";
        return { available: false, reason };
      }
      const chart = chartOutcome.data;

      const rawTimestamps = chart.prices.map((p) => p.timestamp);
      const rawCloses = chart.prices.map((p) => p.value);
      const rawVolumes = alignVolumes(chart.prices, chart.volumes);

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

      const points = candles.map((c, i) => ({
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

      // Divergence is meant to flag what's happening *now*, not narrate the
      // whole fetched history -- keep only those whose most recent leg
      // landed in the last 14 candles. That recency window scales with the
      // chosen interval (14 candles = ~3.5 hours at 15m, ~14 weeks at 1w),
      // which is the correct behaviour: "recent" is relative to how zoomed
      // in you are.
      const recentCutoff = closes.length - 14;
      const rsiDivergence = detectDivergence(closes, rsi).map((f) => ({ indicator: "RSI" as const, ...f }));
      const obvDivergence = detectDivergence(closes, obv).map((f) => ({ indicator: "OBV" as const, ...f }));
      const divergences = [...rsiDivergence, ...obvDivergence]
        .filter((f) => f.toIndex >= recentCutoff)
        .map((f) => ({
          indicator: f.indicator,
          type: f.type,
          fromDate: points[f.fromIndex].timestamp,
          toDate: points[f.toIndex].timestamp,
        }));

      const keyLevels = findKeyLevels(closes);
      const rawChannel = computeTrendChannel(closes);
      const timestamps = candles.map((c) => c.timestamp);
      const spacing = averageSpacing(timestamps);
      const trendChannel = rawChannel
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
  );
}
