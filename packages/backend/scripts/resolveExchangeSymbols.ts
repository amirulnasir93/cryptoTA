// One-time (re-runnable) resolution step: check which watchlist tickers have a
// public ...USDT pair on Binance/MEXC, and populate Token.binanceSymbol /
// Token.mexcSymbol accordingly. Leaves both null when a ticker isn't listed —
// most of this watchlist (EVAA, ENSO, TRADOOR, RECALL, UAI, ZEST, BASED,
// GENIUS) is unlikely to be on either venue; UNI/CRV/CVX/AERO/APEX plausibly are.
//
// Run with: npm run resolve-symbols --workspace packages/backend

import { prisma } from "../src/db.js";
import { fetchBinanceExchangeInfo } from "../src/connectors/binance.js";
import { fetchMexcExchangeInfo } from "../src/connectors/mexc.js";
import { KNOWN_TICKER_COLLISIONS } from "../src/knownCollisions.js";

async function main() {
  const tokens = await prisma.token.findMany({ where: { status: { not: "removed" } } });

  console.log("Fetching Binance exchangeInfo...");
  const binanceSymbols = await fetchBinanceExchangeInfo();
  const binanceUsdtBases = new Set(
    binanceSymbols
      .filter((s) => s.quoteAsset === "USDT" && (s.status ?? "TRADING") === "TRADING")
      .map((s) => s.baseAsset)
  );
  console.log(`  ${binanceUsdtBases.size} USDT pairs found`);

  console.log("Fetching MEXC exchangeInfo...");
  const mexcSymbols = await fetchMexcExchangeInfo();
  const mexcUsdtBases = new Set(
    mexcSymbols.filter((s) => s.quoteAsset === "USDT").map((s) => s.baseAsset)
  );
  console.log(`  ${mexcUsdtBases.size} USDT pairs found`);

  for (const token of tokens) {
    // A ticker-string match on an exchange is not proof it's the same asset.
    // Skills/data-sources.md flags BASED, GENIUS, APEX, ZEST and UAI as
    // colliding with unrelated projects elsewhere — matching those blindly
    // by symbol is exactly the "confident analysis of the wrong asset"
    // failure mode this whole domain is designed to avoid. Leave them for
    // manual confirmation (checking the exchange's own contract/network info
    // against Token.coingeckoId / TokenDeployment) instead of auto-assigning.
    if (KNOWN_TICKER_COLLISIONS[token.ticker]) {
      const onBinance = binanceUsdtBases.has(token.ticker);
      const onMexc = mexcUsdtBases.has(token.ticker);
      if (onBinance || onMexc) {
        console.log(
          `  ${token.ticker}: SKIPPED (known ticker collision) — a USDT pair exists on ` +
            `${[onBinance && "Binance", onMexc && "MEXC"].filter(Boolean).join(" & ")}, ` +
            `but must be verified by hand before trusting it as this asset.`
        );
      } else {
        console.log(`  ${token.ticker}: not listed on either venue's public USDT market`);
      }
      continue;
    }

    const updates: { binanceSymbol?: string | null; mexcSymbol?: string | null } = {};

    if (binanceUsdtBases.has(token.ticker)) updates.binanceSymbol = `${token.ticker}USDT`;
    if (mexcUsdtBases.has(token.ticker)) updates.mexcSymbol = `${token.ticker}USDT`;

    if (Object.keys(updates).length > 0) {
      await prisma.token.update({ where: { id: token.id }, data: updates });
      console.log(`  ${token.ticker}: ${JSON.stringify(updates)}`);
    } else {
      console.log(`  ${token.ticker}: not listed on either venue's public USDT market`);
    }
  }

  console.log("Done.");
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
