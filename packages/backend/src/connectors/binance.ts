import {
  fetchExchangeInfo,
  fetchTicker24hr,
  type ExchangeSymbolInfo,
  type ExchangeTicker,
} from "./binanceCompatibleExchange.js";

export type { ExchangeSymbolInfo, ExchangeTicker };

// Binance's dedicated public-market-data domain — no key, no signing, meant
// exactly for this use case (market data collectors). Fall back to the main
// domain if it's unreachable (e.g. some regions restrict it).
const PRIMARY = "https://data-api.binance.vision/api/v3";
const FALLBACK = "https://api.binance.com/api/v3";

export async function fetchBinanceTicker(
  symbol: string | null | undefined
): Promise<ExchangeTicker | null> {
  return (await fetchTicker24hr(PRIMARY, symbol)) ?? fetchTicker24hr(FALLBACK, symbol);
}

export async function fetchBinanceExchangeInfo(): Promise<ExchangeSymbolInfo[]> {
  const symbols = await fetchExchangeInfo(PRIMARY);
  return symbols.length ? symbols : fetchExchangeInfo(FALLBACK);
}
