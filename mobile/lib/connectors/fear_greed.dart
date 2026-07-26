// Mirrors packages/shared/src/connectors/fearGreed.ts -- alternative.me's
// Fear & Greed Index, free and keyless, confirmed live before use. Market-
// wide, not per-token; see the web connector's own comment for the "this
// isn't a prediction" reasoning (same category as CoinGecko's own
// sentiment_votes_up/down_percentage, already used elsewhere in this app).
import 'http_client.dart';

const _fngUrl = 'https://api.alternative.me/fng/?limit=1';

class FearGreedIndex {
  final int value;
  final String classification;
  final String updatedAt;

  FearGreedIndex({required this.value, required this.classification, required this.updatedAt});
}

Future<FearGreedIndex?> fetchFearGreedIndex() async {
  final data = await fetchJson(_fngUrl);
  if (data == null) return null;
  final entries = data['data'] as List?;
  if (entries == null || entries.isEmpty) return null;
  final entry = entries.first as Map<String, dynamic>;
  final timestampSeconds = int.tryParse(entry['timestamp'] as String? ?? '');
  return FearGreedIndex(
    value: int.tryParse(entry['value'] as String? ?? '') ?? 0,
    classification: entry['value_classification'] as String? ?? 'Unknown',
    updatedAt: timestampSeconds != null
        ? DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000).toIso8601String()
        : DateTime.now().toIso8601String(),
  );
}
