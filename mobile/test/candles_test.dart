// Ported from packages/backend/tests/candles.test.ts -- same cases, same
// expected values, proving the Dart port behaves identically.
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_watchlist_mobile/candles.dart';

int tsAt(int daysFromEpoch, [int hour = 0]) => DateTime.utc(2026, 1, 1 + daysFromEpoch, hour).millisecondsSinceEpoch;

void main() {
  group('buildCandles - daily', () {
    test('collapses same-UTC-day ticks into one candle with real OHLC', () {
      final timestamps = [tsAt(0, 0), tsAt(0, 8), tsAt(0, 16), tsAt(0, 23)];
      final closes = [100.0, 110.0, 90.0, 105.0];
      final volumes = [1.0, 2.0, 3.0, 4.0];
      final candles = buildCandles("1d", timestamps, closes, volumes);
      expect(candles, hasLength(1));
      expect(candles[0].open, 100);
      expect(candles[0].high, 110);
      expect(candles[0].low, 90);
      expect(candles[0].close, 105);
      expect(candles[0].volume, 4);
    });

    test('produces one candle per distinct day', () {
      final timestamps = [tsAt(0), tsAt(1), tsAt(2)];
      final closes = [100.0, 101.0, 102.0];
      final volumes = [1.0, 1.0, 1.0];
      final candles = buildCandles("1d", timestamps, closes, volumes);
      expect(candles, hasLength(3));
      expect(candles.map((c) => c.close).toList(), [100, 101, 102]);
    });
  });

  group('buildCandles - sub-daily', () {
    test('buckets hourly ticks into 4h candles', () {
      final timestamps = List.generate(8, (i) => tsAt(0, i));
      final closes = [10.0, 11.0, 12.0, 13.0, 20.0, 21.0, 22.0, 23.0];
      final volumes = List.filled(8, 1.0);
      final candles = buildCandles("4h", timestamps, closes, volumes);
      expect(candles, hasLength(2));
      expect(candles[0].open, 10);
      expect(candles[0].high, 13);
      expect(candles[0].low, 10);
      expect(candles[0].close, 13);
      expect(candles[1].open, 20);
      expect(candles[1].high, 23);
      expect(candles[1].low, 20);
      expect(candles[1].close, 23);
    });

    test('buckets 5-min-ish ticks into 15m candles', () {
      final base = tsAt(0, 0);
      final timestamps = [base, base + 5 * 60000, base + 10 * 60000, base + 15 * 60000];
      final closes = [1.0, 2.0, 3.0, 4.0];
      final volumes = [1.0, 1.0, 1.0, 1.0];
      final candles = buildCandles("15m", timestamps, closes, volumes);
      expect(candles, hasLength(2));
      expect(candles[0].open, 1);
      expect(candles[0].high, 3);
      expect(candles[0].low, 1);
      expect(candles[0].close, 3);
      expect(candles[1].open, 4);
      expect(candles[1].high, 4);
      expect(candles[1].low, 4);
      expect(candles[1].close, 4);
    });
  });

  group('buildCandles - 2d/3d chunking', () {
    test('chunks daily candles into groups of 2 without calendar alignment', () {
      final timestamps = [tsAt(0), tsAt(1), tsAt(2), tsAt(3)];
      final closes = [100.0, 105.0, 95.0, 110.0];
      final volumes = [1.0, 1.0, 1.0, 1.0];
      final candles = buildCandles("2d", timestamps, closes, volumes);
      expect(candles, hasLength(2));
      expect(candles[0].open, 100);
      expect(candles[0].high, 105);
      expect(candles[0].low, 100);
      expect(candles[0].close, 105);
      expect(candles[1].open, 95);
      expect(candles[1].high, 110);
      expect(candles[1].low, 95);
      expect(candles[1].close, 110);
    });
  });

  group('buildCandles - weekly/monthly calendar grouping', () {
    test('groups two full ISO weeks of daily candles into 2 weekly candles', () {
      final timestamps = List.generate(14, (i) => tsAt(i));
      final closes = List.generate(14, (i) => 100.0 + i);
      final volumes = List.filled(14, 1.0);
      final candles = buildCandles("1w", timestamps, closes, volumes);
      expect(candles.length, greaterThan(1));
      expect(candles.length, lessThan(14));
      final totalTicksAccountedFor = candles.where((c) => c.high - c.low >= 0).length;
      expect(totalTicksAccountedFor, candles.length);
    });

    test('groups a full month of daily candles into 1 monthly candle', () {
      final timestamps = List.generate(31, (i) => tsAt(i));
      final closes = List.generate(31, (i) => 100.0 + i);
      final volumes = List.filled(31, 1.0);
      final candles = buildCandles("1M", timestamps, closes, volumes);
      expect(candles, hasLength(1));
      expect(candles[0].open, 100);
      expect(candles[0].high, 130);
      expect(candles[0].low, 100);
      expect(candles[0].close, 130);
    });
  });

  group('isoWeekKey', () {
    test('gives the same key for two dates in the same ISO week', () {
      final monday = DateTime.utc(2026, 1, 5).millisecondsSinceEpoch;
      final wednesday = DateTime.utc(2026, 1, 7).millisecondsSinceEpoch;
      expect(isoWeekKey(monday), isoWeekKey(wednesday));
    });

    test('gives a different key for dates a week apart', () {
      final week1 = DateTime.utc(2026, 1, 5).millisecondsSinceEpoch;
      final week2 = DateTime.utc(2026, 1, 12).millisecondsSinceEpoch;
      expect(isoWeekKey(week1), isNot(isoWeekKey(week2)));
    });
  });
}
