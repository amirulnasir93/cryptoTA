// MEXC's spot API is intentionally Binance-API-compatible, so both venue
// connectors share this fetch/parse logic against whichever base URL they pass in.

import { fetchJson } from "./base.js";

export interface ExchangeTicker {
  price: number | null;
  volume24hUsd: number | null;
}

export interface ExchangeSymbolInfo {
  symbol: string;
  status?: string;
  baseAsset: string;
  quoteAsset: string;
}

interface Ticker24hr {
  lastPrice: string;
  quoteVolume: string;
}

interface ExchangeInfoResponse {
  symbols: ExchangeSymbolInfo[];
}

export async function fetchTicker24hr(
  baseUrl: string,
  symbol: string | null | undefined
): Promise<ExchangeTicker | null> {
  if (!symbol) return null;
  const data = await fetchJson<Ticker24hr>(`${baseUrl}/ticker/24hr?symbol=${symbol}`);
  if (!data) return null;
  const price = Number(data.lastPrice);
  const volume = Number(data.quoteVolume);
  return {
    price: Number.isFinite(price) ? price : null,
    volume24hUsd: Number.isFinite(volume) ? volume : null,
  };
}

export async function fetchExchangeInfo(baseUrl: string): Promise<ExchangeSymbolInfo[]> {
  const data = await fetchJson<ExchangeInfoResponse>(`${baseUrl}/exchangeInfo`);
  return data?.symbols ?? [];
}
