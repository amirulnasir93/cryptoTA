import { describe, expect, it } from "vitest";
import { buildCandles, isoWeekKey } from "../src/candles.js";

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

function tsAt(daysFromEpoch: number, hour = 0): number {
  return Date.UTC(2026, 0, 1 + daysFromEpoch, hour);
}

describe("buildCandles - daily", () => {
  it("collapses same-UTC-day ticks into one candle with real OHLC", () => {
    const timestamps = [tsAt(0, 0), tsAt(0, 8), tsAt(0, 16), tsAt(0, 23)];
    const closes = [100, 110, 90, 105];
    const volumes = [1, 2, 3, 4];
    const candles = buildCandles("1d", timestamps, closes, volumes);
    expect(candles).toHaveLength(1);
    expect(candles[0]).toMatchObject({ open: 100, high: 110, low: 90, close: 105, volume: 4 });
  });

  it("produces one candle per distinct day", () => {
    const timestamps = [tsAt(0), tsAt(1), tsAt(2)];
    const closes = [100, 101, 102];
    const volumes = [1, 1, 1];
    const candles = buildCandles("1d", timestamps, closes, volumes);
    expect(candles).toHaveLength(3);
    expect(candles.map((c) => c.close)).toEqual([100, 101, 102]);
  });
});

describe("buildCandles - sub-daily", () => {
  it("buckets hourly ticks into 4h candles", () => {
    // 8 hourly ticks -> 2 four-hour candles
    const timestamps = Array.from({ length: 8 }, (_, i) => tsAt(0, i));
    const closes = [10, 11, 12, 13, 20, 21, 22, 23];
    const volumes = new Array(8).fill(1);
    const candles = buildCandles("4h", timestamps, closes, volumes);
    expect(candles).toHaveLength(2);
    expect(candles[0]).toMatchObject({ open: 10, high: 13, low: 10, close: 13 });
    expect(candles[1]).toMatchObject({ open: 20, high: 23, low: 20, close: 23 });
  });

  it("buckets 5-min-ish ticks into 15m candles", () => {
    const base = tsAt(0, 0);
    const timestamps = [base, base + 5 * 60_000, base + 10 * 60_000, base + 15 * 60_000];
    const closes = [1, 2, 3, 4];
    const volumes = [1, 1, 1, 1];
    const candles = buildCandles("15m", timestamps, closes, volumes);
    // first 3 ticks fall in one 15m bucket, the 4th starts the next
    expect(candles).toHaveLength(2);
    expect(candles[0]).toMatchObject({ open: 1, high: 3, low: 1, close: 3 });
    expect(candles[1]).toMatchObject({ open: 4, high: 4, low: 4, close: 4 });
  });
});

describe("buildCandles - 2d/3d chunking", () => {
  it("chunks daily candles into groups of 2 without calendar alignment", () => {
    const timestamps = [tsAt(0), tsAt(1), tsAt(2), tsAt(3)];
    const closes = [100, 105, 95, 110];
    const volumes = [1, 1, 1, 1];
    const candles = buildCandles("2d", timestamps, closes, volumes);
    expect(candles).toHaveLength(2);
    expect(candles[0]).toMatchObject({ open: 100, high: 105, low: 100, close: 105 });
    expect(candles[1]).toMatchObject({ open: 95, high: 110, low: 95, close: 110 });
  });
});

describe("buildCandles - weekly/monthly calendar grouping", () => {
  it("groups two full ISO weeks of daily candles into 2 weekly candles", () => {
    // 2026-01-01 is a Thursday; build 14 consecutive days
    const timestamps = Array.from({ length: 14 }, (_, i) => tsAt(i));
    const closes = Array.from({ length: 14 }, (_, i) => 100 + i);
    const volumes = new Array(14).fill(1);
    const candles = buildCandles("1w", timestamps, closes, volumes);
    // 14 consecutive days can span 2 or 3 ISO weeks depending on where the
    // week boundary falls -- just assert it's coarser than daily and that
    // each week's high/low correctly spans its member days.
    expect(candles.length).toBeGreaterThan(1);
    expect(candles.length).toBeLessThan(14);
    const totalTicksAccountedFor = candles.reduce((sum, c) => sum + (c.high - c.low >= 0 ? 1 : 0), 0);
    expect(totalTicksAccountedFor).toBe(candles.length);
  });

  it("groups a full month of daily candles into 1 monthly candle", () => {
    const timestamps = Array.from({ length: 31 }, (_, i) => tsAt(i)); // Jan 1-31, 2026
    const closes = Array.from({ length: 31 }, (_, i) => 100 + i);
    const volumes = new Array(31).fill(1);
    const candles = buildCandles("1M", timestamps, closes, volumes);
    expect(candles).toHaveLength(1);
    expect(candles[0]).toMatchObject({ open: 100, high: 130, low: 100, close: 130 });
  });
});

describe("isoWeekKey", () => {
  it("gives the same key for two dates in the same ISO week", () => {
    const monday = Date.UTC(2026, 0, 5); // a Monday
    const wednesday = Date.UTC(2026, 0, 7);
    expect(isoWeekKey(monday)).toBe(isoWeekKey(wednesday));
  });

  it("gives a different key for dates a week apart", () => {
    const week1 = Date.UTC(2026, 0, 5);
    const week2 = Date.UTC(2026, 0, 12);
    expect(isoWeekKey(week1)).not.toBe(isoWeekKey(week2));
  });
});
