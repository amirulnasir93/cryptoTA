// Mirrors packages/shared/src/connectors/coinmarketcal.ts -- see that file's
// own comment for the collision-caution reasoning behind why matching is
// left entirely to the caller (this connector just fetches the raw feed).
import 'http_client.dart';

const _cmcCal = 'https://api.coinmarketcal.com/v2';

class CoinMarketCalCoin {
  final String symbol;
  final String name;
  CoinMarketCalCoin({required this.symbol, required this.name});
}

class CoinMarketCalEvent {
  final String title;
  final String date;
  final List<CoinMarketCalCoin> coins;
  final List<String> categoryNames;
  final String? sourceUrl;

  CoinMarketCalEvent({
    required this.title,
    required this.date,
    required this.coins,
    required this.categoryNames,
    this.sourceUrl,
  });

  String get eventTitle => title.isNotEmpty ? title : 'Untitled event';
}

String _dateRangeParam(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$mm/$dd/${d.year}';
}

Future<List<CoinMarketCalEvent>?> fetchCoinMarketCalEvents(
  String? apiKey, {
  int daysAhead = 90,
  int max = 300,
}) async {
  if (apiKey == null || apiKey.isEmpty) return null;

  final now = DateTime.now();
  final until = now.add(Duration(days: daysAhead));

  final params = {
    'dateRangeStart': _dateRangeParam(now),
    'dateRangeEnd': _dateRangeParam(until),
    'max': '$max',
    'sortBy': 'created_desc',
  };
  final uri = Uri.parse('$_cmcCal/events').replace(queryParameters: params);

  final data = await fetchJson(uri.toString(), headers: {'x-api-key': apiKey});
  if (data == null) return null;
  final events = (data['data'] as List?) ?? [];
  return events.map((e) {
    final json = e as Map<String, dynamic>;
    final coins = (json['coins'] as List? ?? [])
        .map((c) => CoinMarketCalCoin(symbol: (c['symbol'] as String? ?? '').toUpperCase(), name: c['name'] as String? ?? ''))
        .toList();
    final categories = (json['categories'] as List? ?? [])
        .map((c) => ((c as Map<String, dynamic>)['name'] as String? ?? '').toLowerCase())
        .toList();
    return CoinMarketCalEvent(
      title: json['title'] as String? ?? '',
      date: json['date'] as String? ?? '',
      coins: coins,
      categoryNames: categories.cast<String>(),
      sourceUrl: json['sourceUrl'] as String?,
    );
  }).toList();
}
