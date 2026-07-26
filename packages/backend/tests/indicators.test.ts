import { describe, expect, it } from "vitest";
import {
  classifyTrend,
  computeEMA,
  computeMACD,
  computeOBV,
  computeRSI,
  computeSMA,
  computeStochasticRSI,
  computeTrendChannel,
  detectDivergence,
  findKeyLevels,
  findSwingPoints,
} from "../src/indicators.js";

describe("computeRSI", () => {
  it("is null before the warm-up period", () => {
    const closes = Array.from({ length: 10 }, (_, i) => 100 + i);
    const rsi = computeRSI(closes, 14);
    expect(rsi.every((v) => v === null)).toBe(true);
  });

  it("is exactly 100 for a strictly increasing series (avgLoss stays 0)", () => {
    const closes = Array.from({ length: 30 }, (_, i) => 100 + i);
    const rsi = computeRSI(closes, 14);
    expect(rsi[29]).toBe(100);
  });

  it("is exactly 0 for a strictly decreasing series (avgGain stays 0)", () => {
    const closes = Array.from({ length: 30 }, (_, i) => 200 - i);
    const rsi = computeRSI(closes, 14);
    expect(rsi[29]).toBe(0);
  });

  it("stays within [0, 100] for a noisy series", () => {
    const closes = [100, 102, 101, 105, 103, 108, 106, 110, 107, 112, 109, 115, 111, 118, 114, 120, 116, 122];
    const rsi = computeRSI(closes, 14);
    for (const v of rsi) {
      if (v !== null) {
        expect(v).toBeGreaterThanOrEqual(0);
        expect(v).toBeLessThanOrEqual(100);
      }
    }
  });
});

describe("computeEMA", () => {
  it("equals the constant for a flat series", () => {
    const values = new Array(20).fill(50);
    const ema = computeEMA(values, 12);
    expect(ema[19]).toBeCloseTo(50);
  });

  it("is null before the seed period", () => {
    const values = [1, 2, 3, 4, 5];
    const ema = computeEMA(values, 12);
    expect(ema.every((v) => v === null)).toBe(true);
  });
});

describe("computeMACD", () => {
  it("is ~0 across the board for a flat price series", () => {
    const closes = new Array(40).fill(50);
    const macd = computeMACD(closes);
    const last = macd[39];
    expect(last.macd).toBeCloseTo(0);
    expect(last.signal).toBeCloseTo(0);
    expect(last.histogram).toBeCloseTo(0);
  });

  it("goes positive for a sustained uptrend (fast EMA pulls ahead of slow)", () => {
    const closes = Array.from({ length: 60 }, (_, i) => 100 + i * 2);
    const macd = computeMACD(closes);
    expect(macd[59].macd).toBeGreaterThan(0);
  });
});

describe("computeStochasticRSI", () => {
  it("stays within [0, 100] once warmed up", () => {
    const closes = [100, 102, 101, 105, 103, 108, 106, 110, 107, 112, 109, 115, 111, 118, 114, 120, 116, 122, 119, 125, 121, 128, 124, 130, 126, 132, 128, 134, 130, 136];
    const stoch = computeStochasticRSI(closes);
    for (const point of stoch) {
      if (point.k !== null) {
        expect(point.k).toBeGreaterThanOrEqual(0);
        expect(point.k).toBeLessThanOrEqual(100);
      }
    }
  });
});

describe("computeOBV", () => {
  it("adds volume on an up close and subtracts on a down close", () => {
    const closes = [10, 11, 10, 10, 12];
    const volumes = [100, 50, 30, 20, 40];
    const obv = computeOBV(closes, volumes);
    // index0: base 0
    // index1: up (11>10) -> +50 => 50
    // index2: down (10<11) -> -30 => 20
    // index3: flat (10==10) -> unchanged => 20
    // index4: up (12>10) -> +40 => 60
    expect(obv).toEqual([0, 50, 20, 20, 60]);
  });
});

describe("findSwingPoints", () => {
  it("finds an obvious single low and high", () => {
    const values = [10, 9, 8, 5, 8, 9, 10, 13, 10, 9, 8];
    const swings = findSwingPoints(values, 2);
    expect(swings.some((s) => s.index === 3 && s.type === "low")).toBe(true);
    expect(swings.some((s) => s.index === 7 && s.type === "high")).toBe(true);
  });
});

describe("detectDivergence", () => {
  it("flags bullish divergence when price makes a lower low but the indicator makes a higher low", () => {
    // price: low at idx 3 (value 5), lower low at idx 8 (value 3)
    const closes = [10, 9, 8, 5, 8, 9, 8, 6, 3, 6, 9];
    // indicator: higher low at idx 8 (30) than idx 3 (20) -- classic bullish divergence
    const indicator = [50, 40, 30, 20, 30, 40, 35, 32, 30, 40, 50];
    const flags = detectDivergence(closes, indicator, 2);
    expect(flags.some((f) => f.type === "bullish" && f.fromIndex === 3 && f.toIndex === 8)).toBe(true);
  });

  it("finds nothing when price and indicator move together (no divergence)", () => {
    const closes = [10, 9, 8, 5, 8, 9, 10, 13, 10, 9, 8];
    const indicator = closes.map((c) => c); // perfectly correlated, same swing shape
    const flags = detectDivergence(closes, indicator, 2);
    expect(flags.length).toBe(0);
  });
});

describe("classifyTrend", () => {
  it("reads Uptrend when price is above its SMA and MACD is bullish", () => {
    const closes = Array.from({ length: 60 }, (_, i) => 100 + i * 2);
    const macd = computeMACD(closes);
    const result = classifyTrend(closes, macd, 20);
    expect(result.state).toBe("Uptrend");
  });

  it("reads Downtrend when price is below its SMA and MACD is bearish", () => {
    const closes = Array.from({ length: 60 }, (_, i) => 300 - i * 2);
    const macd = computeMACD(closes);
    const result = classifyTrend(closes, macd, 20);
    expect(result.state).toBe("Downtrend");
  });

  it("reads Ranging before there's enough history", () => {
    const closes = [100, 101, 102];
    const macd = computeMACD(closes);
    const result = classifyTrend(closes, macd, 20);
    expect(result.state).toBe("Ranging");
  });
});

describe("computeSMA", () => {
  it("matches a hand-computed average", () => {
    const values = [1, 2, 3, 4, 5];
    const sma = computeSMA(values, 3);
    expect(sma[2]).toBeCloseTo(2); // avg(1,2,3)
    expect(sma[4]).toBeCloseTo(4); // avg(3,4,5)
  });
});

describe("findKeyLevels", () => {
  it("clusters repeated swing lows/highs into support/resistance levels", () => {
    // Oscillates between ~100 (lows) and ~110 (highs) three times
    const closes = [105, 100, 106, 110, 104, 99, 107, 111, 103, 101, 108, 110, 102, 100, 106];
    const levels = findKeyLevels(closes, 2);
    const support = levels.filter((l) => l.type === "support");
    const resistance = levels.filter((l) => l.type === "resistance");
    expect(support.length).toBeGreaterThan(0);
    expect(resistance.length).toBeGreaterThan(0);
    expect(Math.max(...support.map((s) => s.price))).toBeLessThan(Math.min(...resistance.map((r) => r.price)));
  });

  it("never returns more than maxLevels per side", () => {
    const closes = Array.from({ length: 60 }, (_, i) => 100 + Math.sin(i) * 10);
    const levels = findKeyLevels(closes, 2, 0.015, 3);
    expect(levels.filter((l) => l.type === "support").length).toBeLessThanOrEqual(3);
    expect(levels.filter((l) => l.type === "resistance").length).toBeLessThanOrEqual(3);
  });
});

describe("computeTrendChannel", () => {
  it("returns null without enough swing structure", () => {
    const closes = [100, 101, 102, 103, 104];
    expect(computeTrendChannel(closes)).toBeNull();
  });

  it("extends a rising channel forward from the last two swing highs/lows", () => {
    // A clean up-channel: lows rising 100->105, highs rising 108(idx7)->118(idx12)
    const closes = [100, 104, 108, 104, 100, 105, 109, 113, 109, 105, 110, 114, 118, 114, 110];
    const channel = computeTrendChannel(closes, 2, 5);
    expect(channel).not.toBeNull();
    if (channel) {
      expect(channel.upper.toPrice).toBeGreaterThan(channel.upper.fromPrice);
      expect(channel.lower.toPrice).toBeGreaterThan(channel.lower.fromPrice);
      expect(channel.upper.toIndex).toBe(closes.length - 1 + 5);
    }
  });
});
