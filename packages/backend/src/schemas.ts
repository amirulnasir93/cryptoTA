// Zod schemas for request validation and response typing. These mirror
// packages/shared's TS interfaces exactly, so what Fastify validates/returns
// and what the frontend (and later Flutter) expect can't silently drift.
// fastify-type-provider-zod also turns these into the OpenAPI doc at /docs.

import { z } from "zod";

export const errorSchema = z.object({ error: z.string() });

export const horizonSchema = z.enum(["4h_scalp", "1d_scalp", "1d_hold", "1w_hold", "1m_hold"]);
export const dataQualitySchema = z.enum(["Good", "Degraded", "Poor"]).nullable();
export const tokenStatusSchema = z.enum(["active", "archived", "removed"]);
export const catalystTypeSchema = z.enum(["unlock", "listing", "governance", "launch", "other"]);

export const metricSnapshotSchema = z.object({
  id: z.number(),
  tokenId: z.number(),
  fetchedAt: z.string(),
  priceCoingecko: z.number().nullable(),
  priceDexscreener: z.number().nullable(),
  priceBinance: z.number().nullable(),
  priceMexc: z.number().nullable(),
  divergencePct: z.number().nullable(),
  marketCap: z.number().nullable(),
  fdv: z.number().nullable(),
  volume24h: z.number().nullable(),
  volumeToMcap: z.number().nullable(),
  change24hPct: z.number().nullable(),
  change7dPct: z.number().nullable(),
  change30dPct: z.number().nullable(),
  ath: z.number().nullable(),
  drawdownFromAthPct: z.number().nullable(),
  circulatingSupply: z.number().nullable(),
  totalSupply: z.number().nullable(),
  floatPct: z.number().nullable(),
  tvl: z.number().nullable(),
  tvlChange30dPct: z.number().nullable(),
  dataQuality: dataQualitySchema,
  assessableHorizons: z.array(horizonSchema),
  gatingReason: z.string().nullable(),
});

export const labelSchema = z.object({
  id: z.number(),
  name: z.string(),
  color: z.string().nullable(),
});

export const deploymentSchema = z.object({
  id: z.number(),
  chain: z.string(),
  contractAddress: z.string().nullable(),
  isPrimaryLiquidity: z.boolean(),
  notes: z.string().nullable(),
});

export const catalystSchema = z.object({
  id: z.number(),
  tokenId: z.number(),
  eventDate: z.string(),
  eventType: catalystTypeSchema,
  description: z.string(),
  sizePctOfSupply: z.number().nullable(),
  sourceUrl: z.string().nullable(),
});

export const tokenSchema = z.object({
  id: z.number(),
  ticker: z.string(),
  projectName: z.string().nullable(),
  primaryChain: z.string().nullable(),
  coingeckoId: z.string().nullable(),
  defillamaSlug: z.string().nullable(),
  binanceSymbol: z.string().nullable(),
  mexcSymbol: z.string().nullable(),
  cluster: z.string().nullable(),
  notes: z.string().nullable(),
  collisionWarning: z.string().nullable(),
  status: tokenStatusSchema,
  createdAt: z.string(),
  updatedAt: z.string(),
  deployments: z.array(deploymentSchema),
  labels: z.array(labelSchema),
  latestSnapshot: metricSnapshotSchema.nullable(),
});

export const tokenDetailSchema = tokenSchema.extend({
  history: z.array(metricSnapshotSchema),
  catalysts: z.array(catalystSchema),
  clusterSiblings: z.array(
    z.object({
      id: z.number(),
      ticker: z.string(),
      projectName: z.string().nullable(),
      latestSnapshot: metricSnapshotSchema.nullable(),
    })
  ),
});

export const createTokenBodySchema = z.object({
  ticker: z.string().min(1).max(20),
  projectName: z.string().optional(),
  primaryChain: z.string().optional(),
  coingeckoId: z.string().optional(),
  defillamaSlug: z.string().optional(),
  cluster: z.string().optional(),
  notes: z.string().optional(),
  labelIds: z.array(z.number()).optional(),
});

export const updateTokenBodySchema = z.object({
  projectName: z.string().nullable().optional(),
  primaryChain: z.string().nullable().optional(),
  coingeckoId: z.string().nullable().optional(),
  defillamaSlug: z.string().nullable().optional(),
  binanceSymbol: z.string().nullable().optional(),
  mexcSymbol: z.string().nullable().optional(),
  cluster: z.string().nullable().optional(),
  notes: z.string().nullable().optional(),
  labelIds: z.array(z.number()).optional(),
});

export const createLabelBodySchema = z.object({
  name: z.string().min(1).max(50),
  color: z.string().max(20).optional(),
});

export const updateLabelBodySchema = createLabelBodySchema.partial();

export const createCatalystBodySchema = z.object({
  tokenId: z.number(),
  eventDate: z.coerce.date(),
  eventType: catalystTypeSchema,
  description: z.string().min(1),
  sizePctOfSupply: z.number().optional(),
  sourceUrl: z.string().url().optional(),
});

export const clusterExposureSchema = z.object({
  cluster: z.string(),
  tokenCount: z.number(),
  tickers: z.array(z.string()),
});

export const dashboardSummarySchema = z.object({
  generatedAt: z.string(),
  tokenCount: z.number(),
  dataQualityCounts: z.object({
    Good: z.number(),
    Degraded: z.number(),
    Poor: z.number(),
    Unknown: z.number(),
  }),
  clusterExposure: z.array(clusterExposureSchema),
  upcomingCatalysts: z.array(catalystSchema.extend({ ticker: z.string(), daysUntil: z.number() })),
  movers: z.array(
    z.object({ ticker: z.string(), tokenId: z.number(), change24hPct: z.number().nullable() })
  ),
  tokens: z.array(tokenSchema),
});
