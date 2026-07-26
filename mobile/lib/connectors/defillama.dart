// Ported from packages/backend/src/connectors/defillama.ts.
import 'http_client.dart';

const _llama = "https://api.llama.fi";

class ProtocolMetrics {
  final double? tvl;
  final double? tvlChange30dPct;
  ProtocolMetrics(this.tvl, this.tvlChange30dPct);
}

Future<ProtocolMetrics?> fetchProtocol(String? slug) async {
  if (slug == null || slug.isEmpty) return null;

  final data = await fetchJson('$_llama/protocol/$slug');
  if (data == null) return null;

  final tvlSeries = (data['tvl'] as List?) ?? [];
  final current = tvlSeries.isNotEmpty ? (tvlSeries.last['totalLiquidityUSD'] as num?)?.toDouble() : null;

  double? change30d;
  if (tvlSeries.length > 30 && current != null) {
    final prior = (tvlSeries[tvlSeries.length - 31]['totalLiquidityUSD'] as num?)?.toDouble();
    if (prior != null && prior != 0) change30d = ((current - prior) / prior) * 100;
  }

  return ProtocolMetrics(current, change30d);
}
