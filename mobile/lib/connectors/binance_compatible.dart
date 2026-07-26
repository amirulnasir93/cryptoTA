// Ported from packages/backend/src/connectors/{binanceCompatibleExchange,binance,mexc}.ts.
// MEXC's spot API is intentionally Binance-API-compatible, so both venues
// share this fetch/parse logic against whichever base URL they pass in.
import 'http_client.dart';
import '../candles.dart' show Candle;

class ExchangeTicker {
  final double? price;
  final double? volume24hUsd;
  ExchangeTicker(this.price, this.volume24hUsd);
}

Future<ExchangeTicker?> fetchTicker24hr(String baseUrl, String? symbol) async {
  if (symbol == null || symbol.isEmpty) return null;
  final data = await fetchJson('$baseUrl/ticker/24hr?symbol=$symbol');
  if (data == null) return null;
  final price = double.tryParse('${data['lastPrice']}');
  final volume = double.tryParse('${data['quoteVolume']}');
  return ExchangeTicker(
    price != null && price.isFinite ? price : null,
    volume != null && volume.isFinite ? volume : null,
  );
}

// Binance's dedicated public-market-data domain -- no key, no signing.
// Falls back to the main domain if it's unreachable (e.g. some regions
// restrict it).
const _binancePrimary = "https://data-api.binance.vision/api/v3";
const _binanceFallback = "https://api.binance.com/api/v3";

Future<ExchangeTicker?> fetchBinanceTicker(String? symbol) async {
  return await fetchTicker24hr(_binancePrimary, symbol) ?? fetchTicker24hr(_binanceFallback, symbol);
}

const _mexcBase = "https://api.mexc.com/api/v3";

Future<ExchangeTicker?> fetchMexcTicker(String? symbol) async {
  return fetchTicker24hr(_mexcBase, symbol);
}

/// Binance's own klines interval strings match this app's ChartInterval for
/// every value except "2d" (Binance has no 2-day granularity) -- callers
/// fetch "1d" and chunk pairs locally (candles.dart's chunkCandles) instead.
const binanceNativeIntervals = {
  '15m': '15m',
  '1h': '1h',
  '2h': '2h',
  '4h': '4h',
  '1d': '1d',
  '3d': '3d',
  '1w': '1w',
  '1M': '1M',
};

/// Fetches real OHLCV candles directly from Binance's public klines endpoint
/// -- unlike CoinGecko's market_chart (tick-level close prices only, and
/// capped at 365 days of history on the free tier), Binance returns actual
/// per-candle open/high/low/close and has no such history-depth limit, so
/// this exists purely to give the chart a "see further back" option for
/// tokens that trade on Binance. Returns chronological order (oldest first),
/// matching candles.dart's buildCandles output -- opposite of the raw API's
/// own newest-first-when-using-endTime-pagination ordering (it's actually
/// oldest-first already for a plain limit-only call, but sorted explicitly
/// here so callers never have to care which case they're in).
Future<List<Candle>?> fetchBinanceKlines(
  String symbol,
  String binanceInterval, {
  int limit = 1000,
  int? endTime,
}) async {
  final params = {
    'symbol': symbol,
    'interval': binanceInterval,
    'limit': '$limit',
    if (endTime != null) 'endTime': '$endTime',
  };
  final uri = Uri.parse('$_binancePrimary/klines').replace(queryParameters: params);
  var data = await fetchJson(uri.toString());
  if (data == null) {
    final fallbackUri = Uri.parse('$_binanceFallback/klines').replace(queryParameters: params);
    data = await fetchJson(fallbackUri.toString());
  }
  if (data is! List) return null;

  final out = data.map((row) {
    final r = row as List;
    return Candle(
      timestamp: r[0] as int,
      open: double.parse(r[1] as String),
      high: double.parse(r[2] as String),
      low: double.parse(r[3] as String),
      close: double.parse(r[4] as String),
      volume: double.parse(r[5] as String),
    );
  }).toList();
  out.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return out;
}
