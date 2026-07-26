// Generic OHLC candle bucketing: turns a raw (timestamp, close, volume) tick
// series into candles at a requested CEX-style interval. Pure and I/O-free so
// it's unit testable without live API access.
//
// Two bucketing strategies:
//  - sub-daily intervals (15m/1h/2h/4h): round each raw tick's timestamp down
//    to a fixed-width time bucket.
//  - daily+ intervals (1d/2d/3d/1w/1M): first collapse to one candle per UTC
//    day, then optionally regroup that daily series into 2/3-day chunks (no
//    natural calendar alignment, so just chunked) or calendar week/month
//    buckets (which do have a natural alignment).

export type ChartInterval = "15m" | "1h" | "2h" | "4h" | "1d" | "2d" | "3d" | "1w" | "1M";

export interface Candle {
  timestamp: number;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

const MINUTE_MS = 60_000;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;

/**
 * How much raw history to request from the source per interval. Sub-daily
 * intervals need finer source granularity and necessarily cover a shorter
 * span -- nobody expects 6 months of 15m candles, and CoinGecko's free tier
 * doesn't return intraday ticks beyond ~90 days anyway. Daily+ intervals
 * fetch a long span and derive coarser candles from daily bars.
 *
 * 365 is a hard ceiling here, not a stylistic choice: CoinGecko's free/Demo
 * tier rejects any `days` beyond 365 outright (error_code 10012, "Public API
 * users are limited to querying historical data within the past 365 days").
 * That means "1M" candles are capped at ~12 candles even for a token with
 * years of history -- well under what MACD/RSI need to warm up (~40) -- so
 * monthly analysis will usually report "not enough data" on this tier. That's
 * an honest reflection of the free tier's limit, not a bug; see the
 * dedicated message for it in routes/analysis.ts.
 */
export const INTERVAL_FETCH_DAYS: Record<ChartInterval, number> = {
  "15m": 1,
  "1h": 7,
  "2h": 14,
  "4h": 30,
  "1d": 365,
  "2d": 365,
  "3d": 365,
  "1w": 365,
  "1M": 365,
};

function floorToBucket(ts: number, bucketMs: number): number {
  return Math.floor(ts / bucketMs) * bucketMs;
}

function dayKey(ts: number): string {
  return new Date(ts).toISOString().slice(0, 10);
}

function monthKey(ts: number): string {
  return new Date(ts).toISOString().slice(0, 7);
}

/** ISO week key (Monday-start, week 1 contains the year's first Thursday). */
export function isoWeekKey(ts: number): string {
  const d = new Date(ts);
  const target = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dayNr = (target.getUTCDay() + 6) % 7;
  target.setUTCDate(target.getUTCDate() - dayNr + 3);
  const firstThursday = new Date(Date.UTC(target.getUTCFullYear(), 0, 4));
  const firstThursdayDayNr = (firstThursday.getUTCDay() + 6) % 7;
  firstThursday.setUTCDate(firstThursday.getUTCDate() - firstThursdayDayNr + 3);
  const week = 1 + Math.round((target.getTime() - firstThursday.getTime()) / (7 * DAY_MS));
  return `${target.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

/** Groups raw ticks into candles by an arbitrary string key -- the shared
 * mechanics behind every bucketing strategy. Assumes chronological input. */
function groupTicksByKey(
  timestamps: number[],
  closes: number[],
  volumes: number[],
  keyFn: (ts: number) => string
): Candle[] {
  const indicesByKey = new Map<string, number[]>();
  timestamps.forEach((ts, i) => {
    const key = keyFn(ts);
    if (!indicesByKey.has(key)) indicesByKey.set(key, []);
    indicesByKey.get(key)!.push(i);
  });

  return [...indicesByKey.values()].map((indices) => {
    const groupCloses = indices.map((i) => closes[i]);
    const lastIndex = indices[indices.length - 1];
    return {
      timestamp: timestamps[lastIndex],
      open: groupCloses[0],
      high: Math.max(...groupCloses),
      low: Math.min(...groupCloses),
      close: groupCloses[groupCloses.length - 1],
      volume: volumes[lastIndex],
    };
  });
}

/** Regroups already-formed candles into coarser ones by calendar key. */
function regroupCandles(candles: Candle[], keyFn: (ts: number) => string): Candle[] {
  const byKey = new Map<string, Candle[]>();
  for (const c of candles) {
    const key = keyFn(c.timestamp);
    if (!byKey.has(key)) byKey.set(key, []);
    byKey.get(key)!.push(c);
  }
  return [...byKey.values()].map((group) => ({
    timestamp: group[group.length - 1].timestamp,
    open: group[0].open,
    high: Math.max(...group.map((c) => c.high)),
    low: Math.min(...group.map((c) => c.low)),
    close: group[group.length - 1].close,
    volume: group[group.length - 1].volume,
  }));
}

/** Chunks consecutive candles into groups of `size` -- for 2d/3d, which have
 * no natural calendar alignment, unlike week/month. */
function chunkCandles(candles: Candle[], size: number): Candle[] {
  const out: Candle[] = [];
  for (let i = 0; i < candles.length; i += size) {
    const chunk = candles.slice(i, i + size);
    out.push({
      timestamp: chunk[chunk.length - 1].timestamp,
      open: chunk[0].open,
      high: Math.max(...chunk.map((c) => c.high)),
      low: Math.min(...chunk.map((c) => c.low)),
      close: chunk[chunk.length - 1].close,
      volume: chunk[chunk.length - 1].volume,
    });
  }
  return out;
}

export function buildCandles(
  interval: ChartInterval,
  timestamps: number[],
  closes: number[],
  volumes: number[]
): Candle[] {
  switch (interval) {
    case "15m":
      return groupTicksByKey(timestamps, closes, volumes, (ts) => String(floorToBucket(ts, 15 * MINUTE_MS)));
    case "1h":
      return groupTicksByKey(timestamps, closes, volumes, (ts) => String(floorToBucket(ts, HOUR_MS)));
    case "2h":
      return groupTicksByKey(timestamps, closes, volumes, (ts) => String(floorToBucket(ts, 2 * HOUR_MS)));
    case "4h":
      return groupTicksByKey(timestamps, closes, volumes, (ts) => String(floorToBucket(ts, 4 * HOUR_MS)));
    case "1d":
      return groupTicksByKey(timestamps, closes, volumes, dayKey);
    case "2d":
      return chunkCandles(groupTicksByKey(timestamps, closes, volumes, dayKey), 2);
    case "3d":
      return chunkCandles(groupTicksByKey(timestamps, closes, volumes, dayKey), 3);
    case "1w":
      return regroupCandles(groupTicksByKey(timestamps, closes, volumes, dayKey), isoWeekKey);
    case "1M":
      return regroupCandles(groupTicksByKey(timestamps, closes, volumes, dayKey), monthKey);
    default: {
      const exhaustive: never = interval;
      throw new Error(`Unhandled interval: ${exhaustive}`);
    }
  }
}
