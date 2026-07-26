import {
  fetchExchangeInfo,
  fetchTicker24hr,
  type ExchangeSymbolInfo,
  type ExchangeTicker,
} from "./binanceCompatibleExchange.js";

export type { ExchangeSymbolInfo, ExchangeTicker };

const BASE = "https://api.mexc.com/api/v3";

export async function fetchMexcTicker(
  symbol: string | null | undefined
): Promise<ExchangeTicker | null> {
  return fetchTicker24hr(BASE, symbol);
}

export async function fetchMexcExchangeInfo(): Promise<ExchangeSymbolInfo[]> {
  return fetchExchangeInfo(BASE);
}
