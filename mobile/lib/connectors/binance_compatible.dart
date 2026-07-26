// Ported from packages/backend/src/connectors/{binanceCompatibleExchange,binance,mexc}.ts.
// MEXC's spot API is intentionally Binance-API-compatible, so both venues
// share this fetch/parse logic against whichever base URL they pass in.
import 'http_client.dart';

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
