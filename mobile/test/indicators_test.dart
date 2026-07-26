// Ported from packages/backend/tests/indicators.test.ts -- same cases, same
// expected values, proving the Dart port behaves identically. Includes the
// two computeTrendChannel edge cases fixed live in the web app this session.
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_watchlist_mobile/indicators.dart';

void main() {
  group('computeRSI', () {
    test('is null before the warm-up period', () {
      final closes = List.generate(10, (i) => 100.0 + i);
      final rsi = computeRSI(closes, 14);
      expect(rsi.every((v) => v == null), isTrue);
    });

    test('is exactly 100 for a strictly increasing series (avgLoss stays 0)', () {
      final closes = List.generate(30, (i) => 100.0 + i);
      final rsi = computeRSI(closes, 14);
      expect(rsi[29], 100);
    });

    test('is exactly 0 for a strictly decreasing series (avgGain stays 0)', () {
      final closes = List.generate(30, (i) => 200.0 - i);
      final rsi = computeRSI(closes, 14);
      expect(rsi[29], 0);
    });

    test('stays within [0, 100] for a noisy series', () {
      final List<double> closes = [100.0, 102, 101, 105, 103, 108, 106, 110, 107, 112, 109, 115, 111, 118, 114, 120, 116, 122];
      final rsi = computeRSI(closes, 14);
      for (final v in rsi) {
        if (v != null) {
          expect(v, greaterThanOrEqualTo(0));
          expect(v, lessThanOrEqualTo(100));
        }
      }
    });
  });

  group('computeEMA', () {
    test('equals the constant for a flat series', () {
      final values = List.filled(20, 50.0);
      final ema = computeEMA(values, 12);
      expect(ema[19], closeTo(50, 1e-9));
    });

    test('is null before the seed period', () {
      final List<double> values = [1.0, 2, 3, 4, 5];
      final ema = computeEMA(values, 12);
      expect(ema.every((v) => v == null), isTrue);
    });
  });

  group('computeMACD', () {
    test('is ~0 across the board for a flat price series', () {
      final closes = List.filled(40, 50.0);
      final macd = computeMACD(closes);
      final last = macd[39];
      expect(last.macd, closeTo(0, 1e-9));
      expect(last.signal, closeTo(0, 1e-9));
      expect(last.histogram, closeTo(0, 1e-9));
    });

    test('goes positive for a sustained uptrend (fast EMA pulls ahead of slow)', () {
      final closes = List.generate(60, (i) => 100.0 + i * 2);
      final macd = computeMACD(closes);
      expect(macd[59].macd, greaterThan(0));
    });
  });

  group('computeStochasticRSI', () {
    test('stays within [0, 100] once warmed up', () {
      final List<double> closes = [
        100.0, 102, 101, 105, 103, 108, 106, 110, 107, 112, 109, 115, 111, 118, 114,
        120, 116, 122, 119, 125, 121, 128, 124, 130, 126, 132, 128, 134, 130, 136,
      ];
      final stoch = computeStochasticRSI(closes);
      for (final point in stoch) {
        if (point.k != null) {
          expect(point.k, greaterThanOrEqualTo(0));
          expect(point.k, lessThanOrEqualTo(100));
        }
      }
    });
  });

  group('computeOBV', () {
    test('adds volume on an up close and subtracts on a down close', () {
      final List<double> closes = [10.0, 11, 10, 10, 12];
      final List<double> volumes = [100.0, 50, 30, 20, 40];
      final obv = computeOBV(closes, volumes);
      expect(obv, [0, 50, 20, 20, 60]);
    });
  });

  group('findSwingPoints', () {
    test('finds an obvious single low and high', () {
      final List<double> values = [10.0, 9, 8, 5, 8, 9, 10, 13, 10, 9, 8];
      final swings = findSwingPoints(values, 2);
      expect(swings.any((s) => s.index == 3 && s.type == "low"), isTrue);
      expect(swings.any((s) => s.index == 7 && s.type == "high"), isTrue);
    });
  });

  group('detectDivergence', () {
    test('flags bullish divergence when price makes a lower low but the indicator makes a higher low', () {
      final List<double> closes = [10.0, 9, 8, 5, 8, 9, 8, 6, 3, 6, 9];
      final List<double> indicator = [50.0, 40, 30, 20, 30, 40, 35, 32, 30, 40, 50];
      final flags = detectDivergence(closes, indicator, 2);
      expect(flags.any((f) => f.type == "bullish" && f.fromIndex == 3 && f.toIndex == 8), isTrue);
    });

    test('finds nothing when price and indicator move together (no divergence)', () {
      final List<double> closes = [10.0, 9, 8, 5, 8, 9, 10, 13, 10, 9, 8];
      final List<double> indicator = closes.map((c) => c).toList();
      final flags = detectDivergence(closes, indicator, 2);
      expect(flags.length, 0);
    });
  });

  group('classifyTrend', () {
    test('reads Uptrend when price is above its SMA and MACD is bullish', () {
      final closes = List.generate(60, (i) => 100.0 + i * 2);
      final macd = computeMACD(closes);
      final result = classifyTrend(closes, macd, 20);
      expect(result.state, "Uptrend");
    });

    test('reads Downtrend when price is below its SMA and MACD is bearish', () {
      final closes = List.generate(60, (i) => 300.0 - i * 2);
      final macd = computeMACD(closes);
      final result = classifyTrend(closes, macd, 20);
      expect(result.state, "Downtrend");
    });

    test('reads Ranging before there\'s enough history', () {
      final List<double> closes = [100.0, 101, 102];
      final macd = computeMACD(closes);
      final result = classifyTrend(closes, macd, 20);
      expect(result.state, "Ranging");
    });
  });

  group('computeSMA', () {
    test('matches a hand-computed average', () {
      final List<double> values = [1.0, 2, 3, 4, 5];
      final sma = computeSMA(values, 3);
      expect(sma[2], closeTo(2, 1e-9));
      expect(sma[4], closeTo(4, 1e-9));
    });
  });

  group('findKeyLevels', () {
    test('clusters repeated swing lows/highs into support/resistance levels', () {
      final List<double> closes = [105.0, 100, 106, 110, 104, 99, 107, 111, 103, 101, 108, 110, 102, 100, 106];
      final levels = findKeyLevels(closes, 2);
      final support = levels.where((l) => l.type == "support").toList();
      final resistance = levels.where((l) => l.type == "resistance").toList();
      expect(support.length, greaterThan(0));
      expect(resistance.length, greaterThan(0));
      final maxSupport = support.map((s) => s.price).reduce(math.max);
      final minResistance = resistance.map((r) => r.price).reduce(math.min);
      expect(maxSupport, lessThan(minResistance));
    });

    test('never returns more than maxLevels per side', () {
      final closes = List.generate(60, (i) => 100.0 + math.sin(i.toDouble()) * 10);
      final levels = findKeyLevels(closes, 2, 0.015, 3);
      expect(levels.where((l) => l.type == "support").length, lessThanOrEqualTo(3));
      expect(levels.where((l) => l.type == "resistance").length, lessThanOrEqualTo(3));
    });
  });

  group('computeTrendChannel', () {
    test('returns null without enough swing structure', () {
      final List<double> closes = [100.0, 101, 102, 103, 104];
      expect(computeTrendChannel(closes), isNull);
    });

    test('extends a rising channel forward from the last two swing highs/lows', () {
      final List<double> closes = [100.0, 104, 108, 104, 100, 105, 109, 113, 109, 105, 110, 114, 118, 114, 110];
      final channel = computeTrendChannel(closes, 2, 5);
      expect(channel, isNotNull);
      expect(channel!.upper.toPrice, greaterThan(channel.upper.fromPrice));
      expect(channel.lower.toPrice, greaterThan(channel.lower.fromPrice));
      expect(channel.upper.toIndex, (closes.length - 1 + 5).toDouble());
    });

    test('returns null when the last-2-highs and last-2-lows lines are already inverted at the last bar', () {
      // With only 2 anchor points per line, a sharply falling pair of highs
      // and a sharply rising pair of lows can cross before "now" -- the
      // exact case hit live against real AERO data this session.
      final List<double> closes = [134.0, 96, 115, 180, 81, 51, 101, 25, 103, 97, 40, 47, 81, 70];
      expect(computeTrendChannel(closes, 2, 5), isNull);
    });
  });
}
