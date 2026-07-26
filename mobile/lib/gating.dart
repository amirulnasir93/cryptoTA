// Ported from packages/backend/src/gating.ts (itself ported from
// Skills/fetch.py's divergence/GATES/horizons_for). Keep this in lockstep
// with the backend version if either changes -- see gating_test.dart, ported
// from packages/backend/tests/gating.test.ts.

typedef Horizon = String; // "4h_scalp" | "1d_scalp" | "1d_hold" | "1w_hold" | "1m_hold"
typedef DataQuality = String; // "Good" | "Degraded" | "Poor"

const List<(double, List<Horizon>)> _gates = [
  (0.01, ["4h_scalp", "1d_scalp", "1d_hold", "1w_hold", "1m_hold"]),
  (0.05, ["1d_scalp", "1d_hold", "1w_hold", "1m_hold"]),
  (0.2, ["1d_hold", "1w_hold", "1m_hold"]),
  (double.infinity, ["1w_hold", "1m_hold"]),
];

const double minVolumeForShortHorizons = 100000;

/// Cross-source divergence: (max - min) / min across whatever prices are present.
double? divergence(List<double?> prices) {
  final valid = prices.whereType<double>().where((p) => p > 0).toList();
  if (valid.length < 2) return null;
  final maxV = valid.reduce((a, b) => a > b ? a : b);
  final minV = valid.reduce((a, b) => a < b ? a : b);
  return (maxV - minV) / minV;
}

class HorizonGateResult {
  final List<Horizon> allowed;
  final String reason;
  HorizonGateResult(this.allowed, this.reason);
}

/// Applies the gating table. Absent a second source, stay conservative.
HorizonGateResult horizonsFor(double? div, double? volume24h) {
  List<Horizon> allowed;
  String reason;

  if (div == null) {
    allowed = ["1d_hold", "1w_hold", "1m_hold"];
    reason = "single source only - short horizons need corroboration";
  } else {
    final gate = _gates.firstWhere((g) => div <= g.$1);
    allowed = List.of(gate.$2);
    reason = "cross-source divergence ${(div * 100).toStringAsFixed(1)}%";
  }

  if (volume24h != null && volume24h < minVolumeForShortHorizons) {
    allowed = allowed.where((h) => h != "4h_scalp" && h != "1d_scalp").toList();
    reason += "; 24h volume \$${volume24h.round()} below liquidity floor";
  }

  return HorizonGateResult(allowed, reason);
}

/// Single top-level badge for the dashboard, derived from the same divergence buckets.
DataQuality? dataQualityFor(double? div) {
  if (div == null) return null;
  if (div <= 0.05) return "Good";
  if (div <= 0.2) return "Degraded";
  return "Poor";
}
