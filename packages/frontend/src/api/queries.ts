import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { ChartInterval, CreateTokenInput } from "@crypto-analyzer/shared";
import { api, type CreateCatalystInput, type UpdateTokenInput } from "./client";

export function useTokens(params?: { status?: string; labelId?: number }) {
  return useQuery({
    queryKey: ["tokens", params],
    queryFn: () => api.listTokens(params),
  });
}

export function useToken(id: number | undefined) {
  return useQuery({
    queryKey: ["token", id],
    queryFn: () => api.getToken(id as number),
    enabled: id !== undefined,
  });
}

export function useTokenAnalysis(id: number | undefined, interval: ChartInterval = "1d") {
  return useQuery({
    queryKey: ["token-analysis", id, interval],
    queryFn: () => api.getTokenAnalysis(id as number, interval),
    enabled: id !== undefined,
    staleTime: 5 * 60_000, // candles don't need to refetch on every render
  });
}

export function useTokenInsight(id: number | undefined) {
  return useQuery({
    queryKey: ["token-insight", id],
    queryFn: () => api.getTokenInsight(id as number),
    enabled: id !== undefined,
    staleTime: 30 * 60_000, // description/links/community stats barely change minute to minute
  });
}

export function useDashboard() {
  return useQuery({
    queryKey: ["dashboard"],
    queryFn: api.getDashboard,
    refetchInterval: 60_000,
  });
}

export function useLabels() {
  return useQuery({ queryKey: ["labels"], queryFn: api.listLabels });
}

export function useConflicts() {
  return useQuery({ queryKey: ["conflicts"], queryFn: api.listConflicts });
}

function useInvalidateWatchlist() {
  const qc = useQueryClient();
  return () => {
    qc.invalidateQueries({ queryKey: ["tokens"] });
    qc.invalidateQueries({ queryKey: ["token"] });
    qc.invalidateQueries({ queryKey: ["dashboard"] });
  };
}

export function useCreateToken() {
  const invalidate = useInvalidateWatchlist();
  return useMutation({
    mutationFn: (input: CreateTokenInput) => api.createToken(input),
    onSuccess: invalidate,
  });
}

export function useUpdateToken() {
  const invalidate = useInvalidateWatchlist();
  return useMutation({
    mutationFn: ({ id, input }: { id: number; input: UpdateTokenInput }) => api.updateToken(id, input),
    onSuccess: invalidate,
  });
}

export function useArchiveToken() {
  const invalidate = useInvalidateWatchlist();
  return useMutation({ mutationFn: (id: number) => api.archiveToken(id), onSuccess: invalidate });
}

export function useRestoreToken() {
  const invalidate = useInvalidateWatchlist();
  return useMutation({ mutationFn: (id: number) => api.restoreToken(id), onSuccess: invalidate });
}

export function useRemoveToken() {
  const invalidate = useInvalidateWatchlist();
  return useMutation({ mutationFn: (id: number) => api.removeToken(id), onSuccess: invalidate });
}

export function useCreateLabel() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (input: { name: string; color?: string }) => api.createLabel(input),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["labels"] }),
  });
}

export function useDeleteLabel() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => api.deleteLabel(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["labels"] });
      qc.invalidateQueries({ queryKey: ["tokens"] });
    },
  });
}

export function useCreateCatalyst() {
  const invalidate = useInvalidateWatchlist();
  return useMutation({
    mutationFn: (input: CreateCatalystInput) => api.createCatalyst(input),
    onSuccess: invalidate,
  });
}

export function useDeleteCatalyst() {
  const invalidate = useInvalidateWatchlist();
  return useMutation({ mutationFn: (id: number) => api.deleteCatalyst(id), onSuccess: invalidate });
}
