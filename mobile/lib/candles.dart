// Ported from packages/backend/src/candles.ts. Generic OHLC candle bucketing:
// turns a raw (timestamp, close, volume) tick series into candles at a
// requested CEX-style interval. See candles_test.dart, ported from
// packages/backend/tests/candles.test.ts.

typedef ChartInterval = String; // "15m"|"1h"|"2h"|"4h"|"1d"|"2d"|"3d"|"1w"|"1M"

class Candle {
  final int timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  Candle({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}

const int _minuteMs = 60000;
const int _hourMs = 60 * _minuteMs;

/// How much raw history to request from the source per interval -- see the
/// TS original for the full rationale (CoinGecko's free-tier 365-day cap on
/// historical `market_chart` queries, error_code 10012).
const Map<ChartInterval, int> intervalFetchDays = {
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

int _floorToBucket(int ts, int bucketMs) => (ts ~/ bucketMs) * bucketMs;

String _dayKey(int ts) => DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true).toIso8601String().substring(0, 10);

String _monthKey(int ts) => DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true).toIso8601String().substring(0, 7);

DateTime _atDayOffset(DateTime t, int days) => DateTime.utc(t.year, t.month, t.day + days);

/// ISO week key (Monday-start, week 1 contains the year's first Thursday).
String isoWeekKey(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
  var target = DateTime.utc(d.year, d.month, d.day);
  final dayNr = target.weekday - 1; // Dart weekday: Mon=1..Sun=7 -> 0..6
  target = _atDayOffset(target, 3 - dayNr);
  var firstThursday = DateTime.utc(target.year, 1, 4);
  final firstThursdayDayNr = firstThursday.weekday - 1;
  firstThursday = _atDayOffset(firstThursday, 3 - firstThursdayDayNr);
  final week = 1 + (target.difference(firstThursday).inMilliseconds / (7 * 24 * 60 * 60 * 1000)).round();
  return "${target.year}-W${week.toString().padLeft(2, '0')}";
}

/// Groups raw ticks into candles by an arbitrary key -- the shared mechanics
/// behind every bucketing strategy. Assumes chronological input.
List<Candle> _groupTicksByKey(
  List<int> timestamps,
  List<double> closes,
  List<double> volumes,
  Object Function(int ts) keyFn,
) {
  final indicesByKey = <Object, List<int>>{};
  for (var i = 0; i < timestamps.length; i++) {
    final key = keyFn(timestamps[i]);
    (indicesByKey[key] ??= []).add(i);
  }

  return indicesByKey.values.map((indices) {
    final groupCloses = indices.map((i) => closes[i]).toList();
    final lastIndex = indices.last;
    return Candle(
      timestamp: timestamps[lastIndex],
      open: groupCloses.first,
      high: groupCloses.reduce((a, b) => a > b ? a : b),
      low: groupCloses.reduce((a, b) => a < b ? a : b),
      close: groupCloses.last,
      volume: volumes[lastIndex],
    );
  }).toList();
}

/// Regroups already-formed candles into coarser ones by calendar key.
List<Candle> _regroupCandles(List<Candle> candles, Object Function(int ts) keyFn) {
  final byKey = <Object, List<Candle>>{};
  for (final c in candles) {
    (byKey[keyFn(c.timestamp)] ??= []).add(c);
  }
  return byKey.values.map((group) {
    return Candle(
      timestamp: group.last.timestamp,
      open: group.first.open,
      high: group.map((c) => c.high).reduce((a, b) => a > b ? a : b),
      low: group.map((c) => c.low).reduce((a, b) => a < b ? a : b),
      close: group.last.close,
      volume: group.last.volume,
    );
  }).toList();
}

/// Chunks consecutive candles into groups of `size` -- for 2d/3d, which have
/// no natural calendar alignment, unlike week/month. Also reused directly by
/// the Binance klines path (connectors/binance_compatible.dart) for "2d",
/// the one interval Binance has no native granularity for.
List<Candle> chunkCandles(List<Candle> candles, int size) {
  final out = <Candle>[];
  for (var i = 0; i < candles.length; i += size) {
    final chunk = candles.sublist(i, (i + size).clamp(0, candles.length));
    out.add(Candle(
      timestamp: chunk.last.timestamp,
      open: chunk.first.open,
      high: chunk.map((c) => c.high).reduce((a, b) => a > b ? a : b),
      low: chunk.map((c) => c.low).reduce((a, b) => a < b ? a : b),
      close: chunk.last.close,
      volume: chunk.last.volume,
    ));
  }
  return out;
}

List<Candle> buildCandles(
  ChartInterval interval,
  List<int> timestamps,
  List<double> closes,
  List<double> volumes,
) {
  switch (interval) {
    case "15m":
      return _groupTicksByKey(timestamps, closes, volumes, (ts) => _floorToBucket(ts, 15 * _minuteMs));
    case "1h":
      return _groupTicksByKey(timestamps, closes, volumes, (ts) => _floorToBucket(ts, _hourMs));
    case "2h":
      return _groupTicksByKey(timestamps, closes, volumes, (ts) => _floorToBucket(ts, 2 * _hourMs));
    case "4h":
      return _groupTicksByKey(timestamps, closes, volumes, (ts) => _floorToBucket(ts, 4 * _hourMs));
    case "1d":
      return _groupTicksByKey(timestamps, closes, volumes, _dayKey);
    case "2d":
      return chunkCandles(_groupTicksByKey(timestamps, closes, volumes, _dayKey), 2);
    case "3d":
      return chunkCandles(_groupTicksByKey(timestamps, closes, volumes, _dayKey), 3);
    case "1w":
      return _regroupCandles(_groupTicksByKey(timestamps, closes, volumes, _dayKey), isoWeekKey);
    case "1M":
      return _regroupCandles(_groupTicksByKey(timestamps, closes, volumes, _dayKey), _monthKey);
    default:
      throw ArgumentError("Unhandled interval: $interval");
  }
}
