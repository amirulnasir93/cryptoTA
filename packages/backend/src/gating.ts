// Ported from Skills/fetch.py (divergence / GATES / horizons_for). Kept as a
// direct port rather than an import so the Claude Skill in Skills/ stays a
// standalone, dependency-free unit — see packages/backend/tests/gating.test.ts
// for a test that keeps this in lockstep with fetch.py's documented thresholds.

export type Horizon = "4h_scalp" | "1d_scalp" | "1d_hold" | "1w_hold" | "1m_hold";
export type DataQuality = "Good" | "Degraded" | "Poor";

// Divergence thresholds gating each horizon. See Skills/references/timeframes.md.
const GATES: [threshold: number, horizons: Horizon[]][] = [
  [0.01, ["4h_scalp", "1d_scalp", "1d_hold", "1w_hold", "1m_hold"]],
  [0.05, ["1d_scalp", "1d_hold", "1w_hold", "1m_hold"]],
  [0.2, ["1d_hold", "1w_hold", "1m_hold"]],
  [Infinity, ["1w_hold", "1m_hold"]],
];

export const MIN_VOLUME_FOR_SHORT_HORIZONS = 100_000;

/** Cross-source divergence: (max - min) / min across whatever prices are present. */
export function divergence(prices: (number | null | undefined)[]): number | null {
  const valid = prices.filter((p): p is number => typeof p === "number" && p > 0);
  if (valid.length < 2) return null;
  const max = Math.max(...valid);
  const min = Math.min(...valid);
  return (max - min) / min;
}

export interface HorizonGateResult {
  allowed: Horizon[];
  reason: string;
}

/** Applies the gating table. Absent a second source, stay conservative. */
export function horizonsFor(
  div: number | null,
  volume24h: number | null | undefined
): HorizonGateResult {
  let allowed: Horizon[];
  let reason: string;

  if (div === null) {
    allowed = ["1d_hold", "1w_hold", "1m_hold"];
    reason = "single source only - short horizons need corroboration";
  } else {
    const gate = GATES.find(([threshold]) => div <= threshold)!;
    allowed = [...gate[1]];
    reason = `cross-source divergence ${(div * 100).toFixed(1)}%`;
  }

  if (volume24h != null && volume24h < MIN_VOLUME_FOR_SHORT_HORIZONS) {
    allowed = allowed.filter((h) => h !== "4h_scalp" && h !== "1d_scalp");
    reason += `; 24h volume $${Math.round(volume24h).toLocaleString()} below liquidity floor`;
  }

  return { allowed, reason };
}

/** Single top-level badge for the dashboard, derived from the same divergence buckets. */
export function dataQualityFor(div: number | null): DataQuality | null {
  if (div === null) return null;
  if (div <= 0.05) return "Good";
  if (div <= 0.2) return "Degraded";
  return "Poor";
}
