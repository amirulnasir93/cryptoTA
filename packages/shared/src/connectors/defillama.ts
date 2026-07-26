import { fetchJson } from "./base.js";

const LLAMA = "https://api.llama.fi";

export interface ProtocolMetrics {
  tvl: number | null;
  tvlChange30dPct: number | null;
  chains: string[];
}

interface DefiLlamaProtocol {
  tvl?: { date: number; totalLiquidityUSD: number }[];
  chains?: string[];
}

export async function fetchProtocol(
  slug: string | null | undefined
): Promise<ProtocolMetrics | null> {
  if (!slug) return null;

  const data = await fetchJson<DefiLlamaProtocol>(`${LLAMA}/protocol/${slug}`);
  if (!data) return null;

  const tvlSeries = data.tvl ?? [];
  const current = tvlSeries.length ? tvlSeries[tvlSeries.length - 1].totalLiquidityUSD : null;

  let change30d: number | null = null;
  if (tvlSeries.length > 30 && current) {
    const prior = tvlSeries[tvlSeries.length - 31].totalLiquidityUSD;
    if (prior) change30d = ((current - prior) / prior) * 100;
  }

  return {
    tvl: current ?? null,
    tvlChange30dPct: change30d,
    chains: data.chains ?? [],
  };
}
