// Ported from packages/backend/src/connectors/dexscreener.ts.
import 'http_client.dart';

const _dexscreener = "https://api.dexscreener.com/latest/dex/tokens";

class DexScreenerPrice {
  final double price;
  final double liquidityUsd;
  final String venue;
  final int pairCount;
  DexScreenerPrice(this.price, this.liquidityUsd, this.venue, this.pairCount);
}

/// Independent second price source. Keyless, no rate-limit issues.
Future<DexScreenerPrice?> fetchDexPrice(String? contract) async {
  if (contract == null || !contract.startsWith('0x')) return null;

  final data = await fetchJson('$_dexscreener/$contract');
  final pairs = (data?['pairs'] as List?) ?? [];
  if (pairs.isEmpty) return null;

  final sorted = List<Map<String, dynamic>>.from(pairs)
    ..sort((a, b) {
      final la = num.tryParse('${(a['liquidity'] as Map?)?['usd'] ?? 0}') ?? 0;
      final lb = num.tryParse('${(b['liquidity'] as Map?)?['usd'] ?? 0}') ?? 0;
      return lb.compareTo(la);
    });
  final top = sorted.first;

  final price = double.tryParse('${top['priceUsd']}');
  if (price == null || !price.isFinite) return null;

  return DexScreenerPrice(
    price,
    num.tryParse('${(top['liquidity'] as Map?)?['usd'] ?? 0}')?.toDouble() ?? 0,
    '${top['dexId'] ?? 'unknown'} on ${top['chainId'] ?? 'unknown'}',
    sorted.length,
  );
}
