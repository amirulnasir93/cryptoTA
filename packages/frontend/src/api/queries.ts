import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { Catalyst, ChartInterval, CreateTokenInput } from "@crypto-analyzer/shared";
import { isReady, requireRepository } from "../appConfig";

// Wraps every queryFn/mutationFn so "not configured / not signed in yet" surfaces
// as a normal React Query error state (pages check isReady() directly before
// rendering data, but a mutation fired from a stale page still needs to fail
// loudly rather than silently no-op).
function repo() {
  return requireRepository();
}

export function useTokens(params?: { status?: string; labelId?: number }) {
  return useQuery({
    queryKey: ["tokens", params],
    queryFn: async () => {
      const all = await repo().listTokens(params?.status);
      if (params?.labelId == null) return all;
      return all.filter((t) => t.labels.some((l) => l.id === params.labelId));
    },
    enabled: isReady(),
  });
}

export function useToken(id: number | undefined) {
  return useQuery({
    queryKey: ["token", id],
    queryFn: () => repo().getToken(id as number),
    enabled: isReady() && id !== undefined,
  });
}

export function useTokenAnalysis(id: number | undefined, interval: ChartInterval = "1d") {
  return useQuery({
    queryKey: ["token-analysis", id, interval],
    queryFn: () => repo().getTokenAnalysis(id as number, interval),
    enabled: isReady() && id !== undefined,
    staleTime: 5 * 60_000, // candles don't need to refetch on every render
  });
}

export function useTokenInsight(id: number | undefined) {
  return useQuery({
    queryKey: ["token-insight", id],
    queryFn: () => repo().getTokenInsight(id as number),
    enabled: isReady() && id !== undefined,
    staleTime: 30 * 60_000, // description/links/community stats barely change minute to minute
  });
}

export function useDashboard() {
  return useQuery({
    queryKey: ["dashboard"],
    queryFn: () => repo().getDashboard(),
    enabled: isReady(),
  });
}

export function useLabels() {
  return useQuery({
    queryKey: ["labels"],
    queryFn: () => repo().listLabels(),
    enabled: isReady(),
  });
}

function useInvalidateWatchlist() {
  const qc = useQueryClient();
  return () => {
    qc.invalidateQueries({ queryKey: ["tokens"] });
    qc.invalidateQueries({ queryKey: ["token"] });
    qc.invalidateQueries({ queryKey: ["dashboard"] });
    qc.invalidateQueries({ queryKey: ["labels"] });
  };
}

export function useCreateToken() {
  const invalidate = useInvalidateWatchlist();
  return useMutation({
    mutationFn: async (input: CreateTokenInput) => {
      const names = input.labelIds?.length ? await resolveLabelNames(input.labelIds) : [];
      return repo().createToken(input, names);
    },
    onSuccess: invalidate,
  });
}

// UpdateTokenInput mirrors the old backend contract's field set but replaces
// labelIds-as-the-only-option with two ways in: labelIds (resolved against
// the currently-known labels list -- what the Add/Edit token checkboxes use)
// and labelNames (passed straight through -- what TokenDetail's own label
// editor uses, since typing a brand-new label has no id to resolve yet).
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
  labelNames?: string[];
}

async function resolveLabelNames(ids: number[]): Promise<string[]> {
  const all = await repo().listLabels();
  const idSet = new Set(ids);
  return all.filter((l) => idSet.has(l.id)).map((l) => l.name);
}

export function useUpdateToken() {
  const invalidate = useInvalidateWatchlist();
  return useMutation({
    mutationFn: async ({ id, input }: { id: number; input: UpdateTokenInput }) => {
      const { labelIds, labelNames, ...rest } = input;
      const labels = labelNames ?? (labelIds ? await resolveLabelNames(labelIds) : undefined);
      return repo().updateToken(id, { ...rest, labels });
    },
    onSuccess: invalidate,
  });
}

export function useArchiveToken() {
  const invalidate = useInvalidateWatchlist();
  return useMutation({ mutationFn: (id: number) => repo().archiveToken(id), onSuccess: invalidate });
}

export function useRestoreToken() {
  const invalidate = useInvalidateWatchlist();
  return useMutation({ mutationFn: (id: number) => repo().restoreToken(id), onSuccess: invalidate });
}

export function useRemoveToken() {
  const invalidate = useInvalidateWatchlist();
  return useMutation({ mutationFn: (id: number) => repo().removeToken(id), onSuccess: invalidate });
}

// No useCreateLabel -- there's no independent label entity anymore (see
// repository.ts's listLabels doc comment); a label only exists by being on
// some token, so it's created implicitly via useUpdateToken's labelNames.
export function useDeleteLabel() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (name: string) => repo().deleteLabelEverywhere(name),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["labels"] });
      qc.invalidateQueries({ queryKey: ["tokens"] });
      qc.invalidateQueries({ queryKey: ["token"] });
    },
  });
}

export interface CreateCatalystInput {
  ticker: string;
  eventDate: string;
  eventType: Catalyst["eventType"];
  description: string;
  sizePctOfSupply?: number;
  sourceUrl?: string;
}

export function useCreateCatalyst() {
  const invalidate = useInvalidateWatchlist();
  return useMutation({
    mutationFn: (input: CreateCatalystInput) => repo().createCatalyst(input),
    onSuccess: invalidate,
  });
}

export function useDeleteCatalyst() {
  const invalidate = useInvalidateWatchlist();
  return useMutation({ mutationFn: (id: number) => repo().deleteCatalyst(id), onSuccess: invalidate });
}

// Replaces the old backend-refresh-secret-gated runRefresh/runSheetSync --
// there's no cron job or separate sync step anymore, just "fetch live prices
// for every active token, right now."
export function useRefreshPrices() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => repo().refreshAndGetDashboard(),
    onSuccess: (dashboard) => {
      qc.setQueryData(["dashboard"], dashboard);
      qc.invalidateQueries({ queryKey: ["tokens"] });
      qc.invalidateQueries({ queryKey: ["token"] });
    },
  });
}
