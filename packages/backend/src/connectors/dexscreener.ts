import { fetchJson } from "./base.js";

const DEXSCREENER = "https://api.dexscreener.com/latest/dex/tokens";

export interface DexScreenerPrice {
  price: number;
  liquidityUsd: number;
  venue: string;
  pairCount: number;
}

interface DexScreenerPair {
  priceUsd?: string;
  liquidity?: { usd?: number | string };
  dexId?: string;
  chainId?: string;
}

/** Independent second price source. Keyless, no rate-limit issues. */
export async function fetchDexPrice(
  contract: string | null | undefined
): Promise<DexScreenerPrice | null> {
  if (!contract || !contract.startsWith("0x")) return null;

  const data = await fetchJson<{ pairs?: DexScreenerPair[] }>(`${DEXSCREENER}/${contract}`);
  if (!data?.pairs?.length) return null;

  const pairs = [...data.pairs].sort(
    (a, b) => Number(b.liquidity?.usd ?? 0) - Number(a.liquidity?.usd ?? 0)
  );
  const top = pairs[0];

  const price = Number(top.priceUsd);
  if (!Number.isFinite(price)) return null;

  return {
    price,
    liquidityUsd: Number(top.liquidity?.usd ?? 0),
    venue: `${top.dexId ?? "unknown"} on ${top.chainId ?? "unknown"}`,
    pairCount: pairs.length,
  };
}
