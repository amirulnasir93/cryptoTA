import type {
  Catalyst,
  ChartInterval,
  CoingeckoSearchResult,
  ConflictLogEntry,
  CreateTokenInput,
  DashboardSummary,
  Label,
  MetricSnapshot,
  Token,
  TokenAnalysisResult,
  TokenDetail,
  TokenInsightResult,
} from "@crypto-analyzer/shared";

const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:3001";

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  // Only declare a JSON content-type when there's actually a body -- Fastify
  // rejects a JSON content-type on an empty body (FST_ERR_CTP_EMPTY_JSON_BODY),
  // which every bodiless POST (archive/restore/refresh/sync) was hitting.
  const headers: Record<string, string> = { ...(options.headers as Record<string, string>) };
  if (options.body && !headers["Content-Type"]) {
    headers["Content-Type"] = "application/json";
  }

  const res = await fetch(`${API_URL}${path}`, { ...options, headers });

  if (!res.ok) {
    const body = await res.json().catch(() => ({}) as { error?: string });
    throw new Error(body.error ?? `Request failed: ${res.status}`);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

export interface UpdateTokenInput {
  projectName?: string | null;
  primaryChain?: string | null;
  coingeckoId?: string | null;
  defillamaSlug?: string | null;
  binanceSymbol?: string | null;
  mexcSymbol?: string | null;
  cluster?: string | null;
  notes?: string | null;
  labelIds?: number[];
}

export interface CreateCatalystInput {
  tokenId: number;
  eventDate: string;
  eventType: Catalyst["eventType"];
  description: string;
  sizePctOfSupply?: number;
  sourceUrl?: string;
}

export const api = {
  listTokens: (params?: { status?: string; labelId?: number }) => {
    const qs = new URLSearchParams();
    if (params?.status) qs.set("status", params.status);
    if (params?.labelId) qs.set("labelId", String(params.labelId));
    const suffix = qs.toString() ? `?${qs}` : "";
    return request<Token[]>(`/tokens${suffix}`);
  },
  getToken: (id: number) => request<TokenDetail>(`/tokens/${id}`),
  getTokenHistory: (id: number, limit?: number) =>
    request<MetricSnapshot[]>(`/tokens/${id}/history${limit ? `?limit=${limit}` : ""}`),
  createToken: (input: CreateTokenInput) =>
    request<Token>("/tokens", { method: "POST", body: JSON.stringify(input) }),
  updateToken: (id: number, input: UpdateTokenInput) =>
    request<Token>(`/tokens/${id}`, { method: "PATCH", body: JSON.stringify(input) }),
  archiveToken: (id: number) => request<Token>(`/tokens/${id}/archive`, { method: "POST" }),
  restoreToken: (id: number) => request<Token>(`/tokens/${id}/restore`, { method: "POST" }),
  removeToken: (id: number) => request<void>(`/tokens/${id}`, { method: "DELETE" }),

  listLabels: () => request<Label[]>("/labels"),
  createLabel: (input: { name: string; color?: string }) =>
    request<Label>("/labels", { method: "POST", body: JSON.stringify(input) }),
  updateLabel: (id: number, input: { name?: string; color?: string }) =>
    request<Label>(`/labels/${id}`, { method: "PATCH", body: JSON.stringify(input) }),
  deleteLabel: (id: number) => request<void>(`/labels/${id}`, { method: "DELETE" }),

  createCatalyst: (input: CreateCatalystInput) =>
    request<Catalyst>("/catalysts", { method: "POST", body: JSON.stringify(input) }),
  deleteCatalyst: (id: number) => request<void>(`/catalysts/${id}`, { method: "DELETE" }),

  getDashboard: () => request<DashboardSummary>("/dashboard"),

  runRefresh: (secret: string) =>
    request<{ fetchRunId: number; tokensProcessed: number; status: string }>("/refresh/run", {
      method: "POST",
      headers: { "x-refresh-secret": secret },
    }),

  runSheetSync: (secret: string) =>
    request<{
      ranAt: string;
      pushed: string[];
      pulled: string[];
      created: string[];
      archived: string[];
      skipped?: string;
      conflicts: ConflictLogEntry[];
    }>("/sync/sheets/run", {
      method: "POST",
      headers: { "x-refresh-secret": secret },
    }),

  listConflicts: () => request<ConflictLogEntry[]>("/sync/conflicts"),

  syncCoinMarketCal: (secret: string) =>
    request<{
      ranAt: string;
      created: string[];
      skippedCollisionRisk: string[];
      eventsScanned: number;
      skipped?: string;
    }>("/catalysts/sync-coinmarketcal", {
      method: "POST",
      headers: { "x-refresh-secret": secret },
    }),

  getTokenAnalysis: (id: number, interval?: ChartInterval) =>
    request<TokenAnalysisResult>(`/tokens/${id}/analysis${interval ? `?interval=${interval}` : ""}`),

  getTokenInsight: (id: number) => request<TokenInsightResult>(`/tokens/${id}/insight`),

  searchCoingecko: (query: string) =>
    request<CoingeckoSearchResult[]>(`/lookup/coingecko?q=${encodeURIComponent(query)}`),
};
