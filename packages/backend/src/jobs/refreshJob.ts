// Orchestrates: load active tokens -> hit every connector -> compute
// divergence/gating -> write one MetricSnapshot per token + one FetchRun for
// the whole run. This is the direct successor to Skills/fetch.py, generalized
// from two price sources ([coingecko, dexscreener]) to four
// ([coingecko, dexscreener, binance, mexc]) and writing to the DB instead of
// a snapshot.json file.

import { prisma } from "../db.js";
import { fetchCoingeckoMarkets } from "../connectors/coingecko.js";
import { fetchDexPrice } from "../connectors/dexscreener.js";
import { fetchProtocol } from "../connectors/defillama.js";
import { fetchBinanceTicker } from "../connectors/binance.js";
import { fetchMexcTicker } from "../connectors/mexc.js";
import { divergence, horizonsFor, dataQualityFor } from "../gating.js";
import { sleep } from "../connectors/base.js";

export interface RefreshRunSummary {
  fetchRunId: number;
  tokensProcessed: number;
  status: "ok" | "partial" | "failed";
}

/** Picks the contract address most likely to have DEX liquidity: the primary
 * deployment marked `isPrimaryLiquidity`, falling back to any 0x-format one. */
function pickDexContract(
  deployments: { contractAddress: string | null; isPrimaryLiquidity: boolean }[]
): string | null {
  const primary = deployments.find((d) => d.isPrimaryLiquidity && d.contractAddress?.startsWith("0x"));
  if (primary?.contractAddress) return primary.contractAddress;
  const anyEvm = deployments.find((d) => d.contractAddress?.startsWith("0x"));
  return anyEvm?.contractAddress ?? null;
}

export async function runRefresh(): Promise<RefreshRunSummary> {
  const fetchRun = await prisma.fetchRun.create({ data: { status: "running" } });

  try {
    const tokens = await prisma.token.findMany({
      where: { status: { not: "removed" } },
      include: { deployments: true },
    });

    const coingeckoIds = tokens.map((t) => t.coingeckoId).filter((id): id is string => !!id);
    console.log(`[refresh] fetching CoinGecko markets for ${coingeckoIds.length} tokens...`);
    const market = await fetchCoingeckoMarkets(coingeckoIds);

    let processed = 0;
    let failures = 0;
    const fetchedAt = new Date();

    for (const token of tokens) {
      try {
        const cg = token.coingeckoId ? market[token.coingeckoId] : undefined;
        const dexContract = pickDexContract(token.deployments);

        const [dex, binance, mexc, protocol] = await Promise.all([
          fetchDexPrice(dexContract),
          fetchBinanceTicker(token.binanceSymbol),
          fetchMexcTicker(token.mexcSymbol),
          fetchProtocol(token.defillamaSlug),
        ]);

        const cgPrice = cg?.current_price ?? null;
        const dexPrice = dex?.price ?? null;
        const binancePrice = binance?.price ?? null;
        const mexcPrice = mexc?.price ?? null;

        const div = divergence([cgPrice, dexPrice, binancePrice, mexcPrice]);
        const volume24h = cg?.total_volume ?? dex?.liquidityUsd ?? null;
        const { allowed, reason } = horizonsFor(div, volume24h);
        const dataQuality = dataQualityFor(div);

        const circulating = cg?.circulating_supply ?? null;
        const total = cg?.total_supply ?? null;
        const marketCap = cg?.market_cap ?? null;

        await prisma.metricSnapshot.create({
          data: {
            tokenId: token.id,
            fetchedAt,
            priceCoingecko: cgPrice,
            priceDexscreener: dexPrice,
            priceBinance: binancePrice,
            priceMexc: mexcPrice,
            divergencePct: div,
            marketCap,
            fdv: cg?.fully_diluted_valuation ?? null,
            volume24h,
            volumeToMcap: volume24h && marketCap ? volume24h / marketCap : null,
            change24hPct: cg?.price_change_percentage_24h_in_currency ?? null,
            change7dPct: cg?.price_change_percentage_7d_in_currency ?? null,
            change30dPct: cg?.price_change_percentage_30d_in_currency ?? null,
            ath: cg?.ath ?? null,
            drawdownFromAthPct: cg?.ath_change_percentage ?? null,
            circulatingSupply: circulating,
            totalSupply: total,
            floatPct: circulating && total ? (circulating / total) * 100 : null,
            tvl: protocol?.tvl ?? null,
            tvlChange30dPct: protocol?.tvlChange30dPct ?? null,
            dataQuality,
            assessableHorizonsJson: JSON.stringify(allowed),
            gatingReason: reason,
            rawJson: JSON.stringify({ cg, dex, binance, mexc, protocol }),
          },
        });

        processed += 1;
      } catch (err) {
        failures += 1;
        console.error(`[refresh] failed for ${token.ticker}:`, err);
      }

      // Stay well inside every free tier's rate limit across the loop.
      await sleep(1200);
    }

    const status: RefreshRunSummary["status"] =
      failures === 0 ? "ok" : processed > 0 ? "partial" : "failed";

    await prisma.fetchRun.update({
      where: { id: fetchRun.id },
      data: {
        finishedAt: new Date(),
        status,
        tokensCount: processed,
        errorSummary: failures ? `${failures} token(s) failed to refresh` : null,
      },
    });

    console.log(`[refresh] done: ${processed}/${tokens.length} tokens, status=${status}`);
    return { fetchRunId: fetchRun.id, tokensProcessed: processed, status };
  } catch (err) {
    await prisma.fetchRun.update({
      where: { id: fetchRun.id },
      data: { finishedAt: new Date(), status: "failed", errorSummary: (err as Error).message },
    });
    throw err;
  }
}
