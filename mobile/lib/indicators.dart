// Ported from packages/backend/src/indicators.ts. Pure technical-indicator
// math, deliberately separate from any I/O. Everything here describes
// *current* indicator state -- nothing here predicts a future price. See
// indicators_test.dart, ported from packages/backend/tests/indicators.test.ts,
// including the two edge cases fixed live in the web app this session
// (computeTrendChannel's null-on-inversion and wedge-crossing clip).

/// Wilder-smoothed RSI, the standard convention (not a simple moving average
/// of gains/losses). Returns one value per input close, null until the first
/// `period` closes are available.
List<double?> computeRSI(List<double> closes, [int period = 14]) {
  final rsi = List<double?>.filled(closes.length, null);
  if (closes.length <= period) return rsi;

  double gainSum = 0;
  double lossSum = 0;
  for (var i = 1; i <= period; i++) {
    final delta = closes[i] - closes[i - 1];
    gainSum += delta > 0 ? delta : 0;
    lossSum += delta < 0 ? -delta : 0;
  }
  double avgGain = gainSum / period;
  double avgLoss = lossSum / period;
  rsi[period] = _rsiFromAverages(avgGain, avgLoss);

  for (var i = period + 1; i < closes.length; i++) {
    final delta = closes[i] - closes[i - 1];
    final gain = delta > 0 ? delta : 0.0;
    final loss = delta < 0 ? -delta : 0.0;
    avgGain = (avgGain * (period - 1) + gain) / period;
    avgLoss = (avgLoss * (period - 1) + loss) / period;
    rsi[i] = _rsiFromAverages(avgGain, avgLoss);
  }
  return rsi;
}

double _rsiFromAverages(double avgGain, double avgLoss) {
  if (avgLoss == 0) return 100;
  final rs = avgGain / avgLoss;
  return 100 - 100 / (1 + rs);
}

/// Exponential moving average. Seeded with a simple average of the first
/// `period` values, standard convention.
List<double?> computeEMA(List<double> values, int period) {
  final ema = List<double?>.filled(values.length, null);
  if (values.length < period) return ema;

  final k = 2 / (period + 1);
  final seed = values.take(period).reduce((a, b) => a + b) / period;
  ema[period - 1] = seed;

  for (var i = period; i < values.length; i++) {
    final prev = ema[i - 1]!;
    ema[i] = values[i] * k + prev * (1 - k);
  }
  return ema;
}

class MacdPoint {
  final double? macd;
  final double? signal;
  final double? histogram;
  MacdPoint({this.macd, this.signal, this.histogram});
}

List<MacdPoint> computeMACD(List<double> closes, {int fast = 12, int slow = 26, int signalPeriod = 9}) {
  final emaFast = computeEMA(closes, fast);
  final emaSlow = computeEMA(closes, slow);
  final macdLine = List<double?>.generate(
    closes.length,
    (i) => (emaFast[i] != null && emaSlow[i] != null) ? emaFast[i]! - emaSlow[i]! : null,
  );

  // EMA of the MACD line, but only over the contiguous non-null tail
  // (macdLine is null until `slow` points in).
  final firstValid = macdLine.indexWhere((v) => v != null);
  final signal = List<double?>.filled(closes.length, null);
  if (firstValid != -1) {
    final tail = macdLine.sublist(firstValid).cast<double>();
    final signalTail = computeEMA(tail, signalPeriod);
    for (var i = 0; i < signalTail.length; i++) {
      signal[firstValid + i] = signalTail[i];
    }
  }

  return List.generate(closes.length, (i) {
    final m = macdLine[i];
    final s = signal[i];
    return MacdPoint(macd: m, signal: s, histogram: (m != null && s != null) ? m - s : null);
  });
}

class StochRsiPoint {
  final double? k;
  final double? d;
  StochRsiPoint({this.k, this.d});
}

/// Stochastic applied to the RSI series (not price) -- more sensitive than
/// either alone. %D is a 3-period SMA of %K, standard convention.
List<StochRsiPoint> computeStochasticRSI(
  List<double> closes, {
  int rsiPeriod = 14,
  int stochPeriod = 14,
  int smoothD = 3,
}) {
  final rsi = computeRSI(closes, rsiPeriod);
  final k = List<double?>.filled(closes.length, null);

  for (var i = 0; i < rsi.length; i++) {
    if (i < rsiPeriod + stochPeriod - 1) continue;
    final window = rsi.sublist(i - stochPeriod + 1, i + 1).whereType<double>().toList();
    if (window.length < stochPeriod) continue;
    final minV = window.reduce((a, b) => a < b ? a : b);
    final maxV = window.reduce((a, b) => a > b ? a : b);
    final current = rsi[i]!;
    k[i] = maxV == minV ? 0 : ((current - minV) / (maxV - minV)) * 100;
  }

  final d = List<double?>.generate(k.length, (i) {
    if (i < smoothD - 1) return null;
    final window = k.sublist(i - smoothD + 1, i + 1);
    if (window.any((v) => v == null)) return null;
    return window.cast<double>().reduce((a, b) => a + b) / smoothD;
  });

  return List.generate(k.length, (i) => StochRsiPoint(k: k[i], d: d[i]));
}

/// Running total: adds today's volume on an up close, subtracts on a down
/// close. Only the slope/relationship to price carries information -- the
/// absolute level is meaningless.
List<double> computeOBV(List<double> closes, List<double> volumes) {
  final obv = List<double>.filled(closes.length, 0);
  for (var i = 1; i < closes.length; i++) {
    if (closes[i] > closes[i - 1]) {
      obv[i] = obv[i - 1] + volumes[i];
    } else if (closes[i] < closes[i - 1]) {
      obv[i] = obv[i - 1] - volumes[i];
    } else {
      obv[i] = obv[i - 1];
    }
  }
  return obv;
}

class SwingPoint {
  final int index;
  final String type; // "low" | "high"
  SwingPoint(this.index, this.type);
}

/// A point is a swing low/high if it's the min/max within `window` points on
/// either side. Deliberately simple (no smoothing) -- a mechanical scan for
/// divergence candidates, not a pattern-recognition engine.
List<SwingPoint> findSwingPoints(List<double> values, [int window = 3]) {
  final points = <SwingPoint>[];
  for (var i = window; i < values.length - window; i++) {
    final slice = values.sublist(i - window, i + window + 1);
    final minV = slice.reduce((a, b) => a < b ? a : b);
    final maxV = slice.reduce((a, b) => a > b ? a : b);
    if (values[i] == minV) {
      points.add(SwingPoint(i, "low"));
    } else if (values[i] == maxV) {
      points.add(SwingPoint(i, "high"));
    }
  }
  return points;
}

class DivergenceFlag {
  final String type; // "bullish" | "bearish"
  final int fromIndex;
  final int toIndex;
  DivergenceFlag(this.type, this.fromIndex, this.toIndex);
}

/// Flags divergence between price and an indicator across the two most
/// recent comparable swing points. Bullish: price makes a lower low while the
/// indicator makes a higher low. Bearish: price makes a higher high while the
/// indicator makes a lower high.
List<DivergenceFlag> detectDivergence(List<double> closes, List<double?> indicator, [int window = 3]) {
  final swings = findSwingPoints(closes, window);
  final flags = <DivergenceFlag>[];

  final lows = swings.where((p) => p.type == "low").toList();
  for (var i = 1; i < lows.length; i++) {
    final prev = lows[i - 1];
    final curr = lows[i];
    final prevInd = indicator[prev.index];
    final currInd = indicator[curr.index];
    if (prevInd == null || currInd == null) continue;
    if (closes[curr.index] < closes[prev.index] && currInd > prevInd) {
      flags.add(DivergenceFlag("bullish", prev.index, curr.index));
    }
  }

  final highs = swings.where((p) => p.type == "high").toList();
  for (var i = 1; i < highs.length; i++) {
    final prev = highs[i - 1];
    final curr = highs[i];
    final prevInd = indicator[prev.index];
    final currInd = indicator[curr.index];
    if (prevInd == null || currInd == null) continue;
    if (closes[curr.index] > closes[prev.index] && currInd < prevInd) {
      flags.add(DivergenceFlag("bearish", prev.index, curr.index));
    }
  }

  return flags;
}

class TrendResult {
  final String state; // "Uptrend" | "Downtrend" | "Ranging"
  final String basis;
  TrendResult(this.state, this.basis);
}

/// Deterministic, mechanical description of the *current* trend -- never a
/// forecast of where price goes next. Price-vs-SMA is the primary signal;
/// MACD histogram only adds a momentum qualifier (deliberately not required,
/// see the TS original's note on steady-trend histograms converging to zero).
TrendResult classifyTrend(List<double> closes, List<MacdPoint> macd, [int smaPeriod = 20]) {
  final last = closes.length - 1;
  final lastSma = computeSMA(closes, smaPeriod)[last];

  if (lastSma == null) {
    return TrendResult("Ranging", "not enough history yet for a $smaPeriod-period SMA");
  }

  final distFromSma = (closes[last] - lastSma) / lastSma;
  const deadband = 0.005; // 0.5%
  final histogram = last < macd.length ? macd[last].histogram : null;

  if (distFromSma > deadband) {
    return TrendResult(
      "Uptrend",
      "price ${(distFromSma * 100).toStringAsFixed(1)}% above its $smaPeriod-period SMA${_momentumNote(histogram, 1)}",
    );
  }
  if (distFromSma < -deadband) {
    return TrendResult(
      "Downtrend",
      "price ${(distFromSma.abs() * 100).toStringAsFixed(1)}% below its $smaPeriod-period SMA${_momentumNote(histogram, -1)}",
    );
  }
  return TrendResult("Ranging", "price within ${(deadband * 100).toStringAsFixed(1)}% of its $smaPeriod-period SMA");
}

String _momentumNote(double? histogram, int direction) {
  const epsilon = 1e-6;
  if (histogram == null || histogram.abs() < epsilon) return "";
  final sign = histogram > 0 ? 1 : (histogram < 0 ? -1 : 0);
  return sign == direction ? ", momentum accelerating" : ", momentum cooling";
}

List<double?> computeSMA(List<double> values, int period) {
  final sma = List<double?>.filled(values.length, null);
  for (var i = period - 1; i < values.length; i++) {
    final window = values.sublist(i - period + 1, i + 1);
    sma[i] = window.reduce((a, b) => a + b) / period;
  }
  return sma;
}

class KeyLevel {
  final double price;
  final String type; // "support" | "resistance"
  final int touches;
  KeyLevel(this.price, this.type, this.touches);
}

/// Support/resistance levels derived from actual swing highs/lows -- a
/// record of where price has already reacted, not a guess at where it's
/// going. Nearby swing points (within `tolerancePct` of each other) are
/// clustered into one level; more touches means a more significant level.
/// Support is capped at/below the current price and resistance at/above it.
List<KeyLevel> findKeyLevels(List<double> closes, [int window = 3, double tolerancePct = 0.015, int maxLevels = 3]) {
  final swings = findSwingPoints(closes, window);
  final lastPrice = closes.last;

  List<KeyLevel> cluster(List<SwingPoint> points, String type) {
    final prices = points.map((p) => closes[p.index]).toList()..sort();
    final groups = <List<double>>[];
    for (final price in prices) {
      final currentGroup = groups.isNotEmpty ? groups.last : null;
      final groupEdge = currentGroup != null && currentGroup.isNotEmpty ? currentGroup.last : null;
      if (currentGroup != null && groupEdge != null && (price - groupEdge).abs() / groupEdge <= tolerancePct) {
        currentGroup.add(price);
      } else {
        groups.add([price]);
      }
    }
    final levels = groups
        .map((group) => KeyLevel(group.reduce((a, b) => a + b) / group.length, type, group.length))
        .toList()
      ..sort((a, b) => b.touches.compareTo(a.touches));
    return levels.take(maxLevels).toList();
  }

  final support = cluster(swings.where((s) => s.type == "low" && closes[s.index] <= lastPrice).toList(), "support");
  final resistance =
      cluster(swings.where((s) => s.type == "high" && closes[s.index] >= lastPrice).toList(), "resistance");

  final all = [...resistance, ...support]..sort((a, b) => b.price.compareTo(a.price));
  return all;
}

class ChannelLine {
  final int fromIndex;
  final double fromPrice;
  final double toIndex; // may be fractional (clipped at a wedge's crossing point)
  final double toPrice;
  ChannelLine(this.fromIndex, this.fromPrice, this.toIndex, this.toPrice);
}

class TrendChannel {
  final ChannelLine upper;
  final ChannelLine lower;
  TrendChannel(this.upper, this.lower);
}

class _Line {
  final SwingPoint anchor;
  final double slope;
  final double intercept;
  _Line(this.anchor, this.slope, this.intercept);
  double priceAt(double x) => slope * x + intercept;
}

/// A trend channel: a line through the two most recent swing highs, and a
/// line through the two most recent swing lows, each extended forward a few
/// candles. A geometric extension of OBSERVED structure -- not a statistical
/// or ML prediction. Returns null when there isn't enough swing structure
/// (fewer than 2 highs or 2 lows), or when the two lines -- each fit through
/// only 2 points -- are already inverted (support above resistance) as of
/// the most recent candle: with that few anchors, the "last 2 highs" and
/// "last 2 lows" don't always agree on which side is which, and a channel
/// that's already nonsensical right now isn't worth showing at all.
TrendChannel? computeTrendChannel(List<double> closes, [int window = 3, int extendBars = 5]) {
  final swings = findSwingPoints(closes, window);
  final highsAll = swings.where((s) => s.type == "high").toList();
  final lowsAll = swings.where((s) => s.type == "low").toList();
  final highs = highsAll.length > 2 ? highsAll.sublist(highsAll.length - 2) : highsAll;
  final lows = lowsAll.length > 2 ? lowsAll.sublist(lowsAll.length - 2) : lowsAll;
  if (highs.length < 2 || lows.length < 2) return null;

  final lastIndex = closes.length - 1;

  _Line lineOf(SwingPoint a, SwingPoint b) {
    final slope = (closes[b.index] - closes[a.index]) / (b.index - a.index);
    final intercept = closes[a.index] - slope * a.index; // price at index 0
    return _Line(a, slope, intercept);
  }

  final upperLine = lineOf(highs[0], highs[1]);
  final lowerLine = lineOf(lows[0], lows[1]);

  if (upperLine.priceAt(lastIndex.toDouble()) < lowerLine.priceAt(lastIndex.toDouble())) return null;

  // A converging pair ("wedge") can cross if extended far enough -- past that
  // point, drawing the "resistance" line below the "support" line is
  // nonsensical, since the wedge has already resolved. Clip the projection
  // at the crossing point instead of drawing crossed lines past it.
  double toIndex = (lastIndex + extendBars).toDouble();
  final slopeDiff = upperLine.slope - lowerLine.slope;
  if (slopeDiff.abs() > 1e-9) {
    final crossIndex = (lowerLine.intercept - upperLine.intercept) / slopeDiff;
    if (crossIndex > lastIndex && crossIndex < toIndex) toIndex = crossIndex;
  }

  ChannelLine extend(_Line line) {
    return ChannelLine(line.anchor.index, closes[line.anchor.index], toIndex, line.priceAt(toIndex));
  }

  return TrendChannel(extend(upperLine), extend(lowerLine));
}
