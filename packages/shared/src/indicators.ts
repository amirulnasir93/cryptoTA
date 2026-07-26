// Pure technical-indicator math, deliberately separate from any I/O so it can
// be unit tested against known reference values. Everything here describes
// *current* indicator state -- nothing here predicts a future price. See
// Skills/indicators.md for the domain reasoning behind each indicator's
// weighting and caveats; this module implements the mechanics only.

export type Num = number | null;

/** Wilder-smoothed RSI, the standard convention (not a simple moving average
 * of gains/losses). Returns one value per input close, null until the first
 * `period` closes are available. */
export function computeRSI(closes: number[], period = 14): Num[] {
  const rsi: Num[] = new Array(closes.length).fill(null);
  if (closes.length <= period) return rsi;

  let gainSum = 0;
  let lossSum = 0;
  for (let i = 1; i <= period; i++) {
    const delta = closes[i] - closes[i - 1];
    gainSum += Math.max(delta, 0);
    lossSum += Math.max(-delta, 0);
  }
  let avgGain = gainSum / period;
  let avgLoss = lossSum / period;
  rsi[period] = rsiFromAverages(avgGain, avgLoss);

  for (let i = period + 1; i < closes.length; i++) {
    const delta = closes[i] - closes[i - 1];
    const gain = Math.max(delta, 0);
    const loss = Math.max(-delta, 0);
    avgGain = (avgGain * (period - 1) + gain) / period;
    avgLoss = (avgLoss * (period - 1) + loss) / period;
    rsi[i] = rsiFromAverages(avgGain, avgLoss);
  }
  return rsi;
}

function rsiFromAverages(avgGain: number, avgLoss: number): number {
  if (avgLoss === 0) return 100;
  const rs = avgGain / avgLoss;
  return 100 - 100 / (1 + rs);
}

/** Exponential moving average. Seeded with a simple average of the first
 * `period` values, standard convention. */
export function computeEMA(values: number[], period: number): Num[] {
  const ema: Num[] = new Array(values.length).fill(null);
  if (values.length < period) return ema;

  const k = 2 / (period + 1);
  const seed = values.slice(0, period).reduce((a, b) => a + b, 0) / period;
  ema[period - 1] = seed;

  for (let i = period; i < values.length; i++) {
    const prev = ema[i - 1] as number;
    ema[i] = values[i] * k + prev * (1 - k);
  }
  return ema;
}

export interface MacdPoint {
  macd: Num;
  signal: Num;
  histogram: Num;
}

export function computeMACD(closes: number[], fast = 12, slow = 26, signalPeriod = 9): MacdPoint[] {
  const emaFast = computeEMA(closes, fast);
  const emaSlow = computeEMA(closes, slow);
  const macdLine: Num[] = closes.map((_, i) =>
    emaFast[i] != null && emaSlow[i] != null ? (emaFast[i] as number) - (emaSlow[i] as number) : null
  );

  // EMA of the MACD line, but only over the contiguous non-null tail (macdLine
  // is null until `slow` points in).
  const firstValid = macdLine.findIndex((v) => v !== null);
  const signal: Num[] = new Array(closes.length).fill(null);
  if (firstValid !== -1) {
    const tail = macdLine.slice(firstValid) as number[];
    const signalTail = computeEMA(tail, signalPeriod);
    signalTail.forEach((v, i) => (signal[firstValid + i] = v));
  }

  return closes.map((_, i) => ({
    macd: macdLine[i],
    signal: signal[i],
    histogram: macdLine[i] != null && signal[i] != null ? (macdLine[i] as number) - (signal[i] as number) : null,
  }));
}

export interface StochRsiPoint {
  k: Num;
  d: Num;
}

/** Stochastic applied to the RSI series (not price) -- more sensitive than
 * either alone, per Skills/indicators.md's caveat that it's the noisiest of
 * the price-derived class. %D is a 3-period SMA of %K, standard convention. */
export function computeStochasticRSI(
  closes: number[],
  rsiPeriod = 14,
  stochPeriod = 14,
  smoothD = 3
): StochRsiPoint[] {
  const rsi = computeRSI(closes, rsiPeriod);
  const k: Num[] = new Array(closes.length).fill(null);

  for (let i = 0; i < rsi.length; i++) {
    if (i < rsiPeriod + stochPeriod - 1) continue;
    const window = rsi.slice(i - stochPeriod + 1, i + 1).filter((v): v is number => v !== null);
    if (window.length < stochPeriod) continue;
    const min = Math.min(...window);
    const max = Math.max(...window);
    const current = rsi[i] as number;
    k[i] = max === min ? 0 : ((current - min) / (max - min)) * 100;
  }

  const d: Num[] = k.map((_, i) => {
    if (i < smoothD - 1) return null;
    const window = k.slice(i - smoothD + 1, i + 1);
    if (window.some((v) => v === null)) return null;
    return (window as number[]).reduce((a, b) => a + b, 0) / smoothD;
  });

  return k.map((kVal, i) => ({ k: kVal, d: d[i] }));
}

/** Running total: adds today's volume on an up close, subtracts on a down
 * close. Only the slope/relationship to price carries information -- the
 * absolute level is meaningless (see Skills/indicators.md). */
export function computeOBV(closes: number[], volumes: number[]): number[] {
  const obv: number[] = new Array(closes.length).fill(0);
  for (let i = 1; i < closes.length; i++) {
    if (closes[i] > closes[i - 1]) obv[i] = obv[i - 1] + volumes[i];
    else if (closes[i] < closes[i - 1]) obv[i] = obv[i - 1] - volumes[i];
    else obv[i] = obv[i - 1];
  }
  return obv;
}

export interface SwingPoint {
  index: number;
  type: "low" | "high";
}

/** A point is a swing low/high if it's the min/max within `window` points on
 * either side. Deliberately simple (no smoothing) -- this is a mechanical
 * scan for divergence candidates, not a pattern-recognition engine. */
export function findSwingPoints(values: number[], window = 3): SwingPoint[] {
  const points: SwingPoint[] = [];
  for (let i = window; i < values.length - window; i++) {
    const slice = values.slice(i - window, i + window + 1);
    if (values[i] === Math.min(...slice)) points.push({ index: i, type: "low" });
    else if (values[i] === Math.max(...slice)) points.push({ index: i, type: "high" });
  }
  return points;
}

// Prefixed "Raw" because index.ts's own DivergenceFlag (the wire-format
// shape sent to clients: indicator/type/fromDate/toDate) is a different type
// with the same natural name -- this one is index-based and internal to the
// computation pipeline, converted to timestamps before it ever leaves
// routes/analysis.ts (or the frontend/mobile equivalent).
export interface RawDivergenceFlag {
  type: "bullish" | "bearish";
  fromIndex: number;
  toIndex: number;
}

/**
 * Flags divergence between price and an indicator across the two most recent
 * comparable swing points -- the one pattern Skills/indicators.md calls
 * genuinely high-value ("the higher-value use is divergence... absolute
 * level rarely is on its own"). Bullish: price makes a lower low while the
 * indicator makes a higher low (selling pressure decelerating). Bearish:
 * price makes a higher high while the indicator makes a lower high.
 */
export function detectDivergence(closes: number[], indicator: Num[], window = 3): RawDivergenceFlag[] {
  const swings = findSwingPoints(closes, window);
  const flags: RawDivergenceFlag[] = [];

  const lows = swings.filter((p) => p.type === "low");
  for (let i = 1; i < lows.length; i++) {
    const prev = lows[i - 1];
    const curr = lows[i];
    const prevInd = indicator[prev.index];
    const currInd = indicator[curr.index];
    if (prevInd === null || currInd === null) continue;
    if (closes[curr.index] < closes[prev.index] && currInd > prevInd) {
      flags.push({ type: "bullish", fromIndex: prev.index, toIndex: curr.index });
    }
  }

  const highs = swings.filter((p) => p.type === "high");
  for (let i = 1; i < highs.length; i++) {
    const prev = highs[i - 1];
    const curr = highs[i];
    const prevInd = indicator[prev.index];
    const currInd = indicator[curr.index];
    if (prevInd === null || currInd === null) continue;
    if (closes[curr.index] > closes[prev.index] && currInd < prevInd) {
      flags.push({ type: "bearish", fromIndex: prev.index, toIndex: curr.index });
    }
  }

  return flags;
}

export type TrendState = "Uptrend" | "Downtrend" | "Ranging";

export interface TrendResult {
  state: TrendState;
  basis: string;
}

/**
 * Deterministic, mechanical description of the *current* trend -- never a
 * forecast of where price goes next. Price-vs-SMA is the primary signal
 * (standard trend-following convention); MACD histogram only adds a momentum
 * qualifier. MACD histogram is deliberately NOT a required condition: on a
 * perfectly steady (constant-slope) trend its histogram converges toward
 * zero -- zero acceleration is mathematically correct there, but it would
 * make a strict "MACD must also agree" rule misclassify a real, steady trend
 * as Ranging. A small deadband around the SMA avoids calling noise a trend.
 */
export function classifyTrend(closes: number[], macd: MacdPoint[], smaPeriod = 20): TrendResult {
  const last = closes.length - 1;
  const lastSma = computeSMA(closes, smaPeriod)[last];

  if (lastSma == null) {
    return { state: "Ranging", basis: `not enough history yet for a ${smaPeriod}-period SMA` };
  }

  const distFromSma = (closes[last] - lastSma) / lastSma;
  const deadband = 0.005; // 0.5%
  const histogram = macd[last]?.histogram ?? null;

  if (distFromSma > deadband) {
    return {
      state: "Uptrend",
      basis: `price ${(distFromSma * 100).toFixed(1)}% above its ${smaPeriod}-period SMA${momentumNote(histogram, 1)}`,
    };
  }
  if (distFromSma < -deadband) {
    return {
      state: "Downtrend",
      basis: `price ${(Math.abs(distFromSma) * 100).toFixed(1)}% below its ${smaPeriod}-period SMA${momentumNote(histogram, -1)}`,
    };
  }
  return { state: "Ranging", basis: `price within ${(deadband * 100).toFixed(1)}% of its ${smaPeriod}-period SMA` };
}

function momentumNote(histogram: number | null, direction: 1 | -1): string {
  const epsilon = 1e-6;
  if (histogram == null || Math.abs(histogram) < epsilon) return "";
  return Math.sign(histogram) === direction ? ", momentum accelerating" : ", momentum cooling";
}

export function computeSMA(values: number[], period: number): Num[] {
  const sma: Num[] = new Array(values.length).fill(null);
  for (let i = period - 1; i < values.length; i++) {
    const window = values.slice(i - period + 1, i + 1);
    sma[i] = window.reduce((a, b) => a + b, 0) / period;
  }
  return sma;
}

export interface KeyLevel {
  price: number;
  type: "support" | "resistance";
  touches: number;
}

/**
 * Support/resistance levels derived from actual swing highs/lows -- a record
 * of where price has already reacted, not a guess at where it's going.
 * Legitimate per Skills/assessment.md's own "Deriving levels" section (prior
 * swing highs/lows, range boundaries). Nearby swing points (within
 * `tolerancePct` of each other) are clustered into one level; more touches in
 * a cluster means a more significant level. Support is capped at/below the
 * current price and resistance at/above it -- this intentionally doesn't
 * model "role reversal" (a broken resistance acting as new support), which
 * would need more history than a single swing scan to establish reliably.
 */
export function findKeyLevels(closes: number[], window = 3, tolerancePct = 0.015, maxLevels = 3): KeyLevel[] {
  const swings = findSwingPoints(closes, window);
  const lastPrice = closes[closes.length - 1];

  function cluster(points: SwingPoint[], type: "support" | "resistance"): KeyLevel[] {
    const prices = points.map((p) => closes[p.index]).sort((a, b) => a - b);
    const groups: number[][] = [];
    for (const price of prices) {
      const currentGroup = groups[groups.length - 1];
      const groupEdge = currentGroup?.[currentGroup.length - 1];
      if (currentGroup && groupEdge !== undefined && Math.abs(price - groupEdge) / groupEdge <= tolerancePct) {
        currentGroup.push(price);
      } else {
        groups.push([price]);
      }
    }
    return groups
      .map((group) => ({
        price: group.reduce((a, b) => a + b, 0) / group.length,
        type,
        touches: group.length,
      }))
      .sort((a, b) => b.touches - a.touches)
      .slice(0, maxLevels);
  }

  const support = cluster(
    swings.filter((s) => s.type === "low" && closes[s.index] <= lastPrice),
    "support"
  );
  const resistance = cluster(
    swings.filter((s) => s.type === "high" && closes[s.index] >= lastPrice),
    "resistance"
  );

  return [...resistance, ...support].sort((a, b) => b.price - a.price);
}

// "Raw" for the same reason as RawDivergenceFlag above -- index.ts's own
// ChannelLine/TrendChannel (fromTimestamp/toTimestamp) are the wire-format
// versions; these are index-based and internal, converted to timestamps in
// routes/analysis.ts (or the frontend/mobile equivalent) before being sent
// anywhere.
export interface RawChannelLine {
  fromIndex: number;
  fromPrice: number;
  toIndex: number;
  toPrice: number;
}

export interface RawTrendChannel {
  upper: RawChannelLine;
  lower: RawChannelLine;
}

/**
 * A trend channel: a line through the two most recent swing highs, and a
 * line through the two most recent swing lows, each extended forward a few
 * candles. This is a geometric extension of OBSERVED structure -- literally
 * just the equation of a line through two real points -- not a statistical
 * or ML prediction. It describes "if the current channel holds, these are
 * its boundaries," and is invalidated the moment price closes outside
 * either line. Returns null when there isn't enough swing structure (fewer
 * than 2 highs or 2 lows) to define a channel at all, or when the two lines
 * -- each fit through only 2 points -- are already inverted (support above
 * resistance) as of the most recent candle: with that few anchors, the
 * "last 2 highs" and "last 2 lows" don't always agree on which side is
 * which, and a channel that's already nonsensical right now isn't worth
 * showing at all.
 */
export function computeTrendChannel(closes: number[], window = 3, extendBars = 5): RawTrendChannel | null {
  const swings = findSwingPoints(closes, window);
  const highs = swings.filter((s) => s.type === "high").slice(-2);
  const lows = swings.filter((s) => s.type === "low").slice(-2);
  if (highs.length < 2 || lows.length < 2) return null;

  const lastIndex = closes.length - 1;

  function lineOf(a: SwingPoint, b: SwingPoint) {
    const slope = (closes[b.index] - closes[a.index]) / (b.index - a.index);
    const intercept = closes[a.index] - slope * a.index; // price at index 0
    return { anchor: a, slope, priceAt: (x: number) => slope * x + intercept, intercept };
  }

  const upperLine = lineOf(highs[0], highs[1]);
  const lowerLine = lineOf(lows[0], lows[1]);

  if (upperLine.priceAt(lastIndex) < lowerLine.priceAt(lastIndex)) return null;

  // A converging pair ("wedge") can cross if extended far enough -- past that
  // point, drawing the "resistance" line below the "support" line is
  // nonsensical, since the wedge has already resolved. Clip the projection
  // at the crossing point instead of drawing crossed lines past it.
  let toIndex = lastIndex + extendBars;
  const slopeDiff = upperLine.slope - lowerLine.slope;
  if (Math.abs(slopeDiff) > 1e-9) {
    const crossIndex = (lowerLine.intercept - upperLine.intercept) / slopeDiff;
    if (crossIndex > lastIndex && crossIndex < toIndex) toIndex = crossIndex;
  }

  function extend(line: ReturnType<typeof lineOf>): RawChannelLine {
    return {
      fromIndex: line.anchor.index,
      fromPrice: closes[line.anchor.index],
      toIndex,
      toPrice: line.priceAt(toIndex),
    };
  }

  return { upper: extend(upperLine), lower: extend(lowerLine) };
}
