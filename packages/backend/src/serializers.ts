import type {
  Token as PrismaToken,
  TokenDeployment as PrismaDeployment,
  Label as PrismaLabel,
  TokenLabel as PrismaTokenLabel,
  MetricSnapshot as PrismaSnapshot,
  Catalyst as PrismaCatalyst,
} from "@prisma/client";
import type {
  Token,
  TokenDeployment,
  Label,
  Catalyst,
  MetricSnapshot,
  Horizon,
} from "@crypto-analyzer/shared";

export function serializeSnapshot(s: PrismaSnapshot): MetricSnapshot {
  return {
    id: s.id,
    tokenId: s.tokenId,
    fetchedAt: s.fetchedAt.toISOString(),
    priceCoingecko: s.priceCoingecko,
    priceDexscreener: s.priceDexscreener,
    priceBinance: s.priceBinance,
    priceMexc: s.priceMexc,
    divergencePct: s.divergencePct,
    marketCap: s.marketCap,
    fdv: s.fdv,
    volume24h: s.volume24h,
    volumeToMcap: s.volumeToMcap,
    change24hPct: s.change24hPct,
    change7dPct: s.change7dPct,
    change30dPct: s.change30dPct,
    ath: s.ath,
    drawdownFromAthPct: s.drawdownFromAthPct,
    circulatingSupply: s.circulatingSupply,
    totalSupply: s.totalSupply,
    floatPct: s.floatPct,
    tvl: s.tvl,
    tvlChange30dPct: s.tvlChange30dPct,
    dataQuality: (s.dataQuality as MetricSnapshot["dataQuality"]) ?? null,
    assessableHorizons: s.assessableHorizonsJson
      ? (JSON.parse(s.assessableHorizonsJson) as Horizon[])
      : [],
    gatingReason: s.gatingReason,
  };
}

export function serializeDeployment(d: PrismaDeployment): TokenDeployment {
  return {
    id: d.id,
    chain: d.chain,
    contractAddress: d.contractAddress,
    isPrimaryLiquidity: d.isPrimaryLiquidity,
    notes: d.notes,
  };
}

export function serializeLabel(l: PrismaLabel): Label {
  return { id: l.id, name: l.name, color: l.color };
}

export function serializeCatalyst(c: PrismaCatalyst): Catalyst {
  return {
    id: c.id,
    tokenId: c.tokenId,
    eventDate: c.eventDate.toISOString(),
    eventType: c.eventType as Catalyst["eventType"],
    description: c.description,
    sizePctOfSupply: c.sizePctOfSupply,
    sourceUrl: c.sourceUrl,
  };
}

export type TokenWithRelations = PrismaToken & {
  deployments: PrismaDeployment[];
  labels: (PrismaTokenLabel & { label: PrismaLabel })[];
  snapshots: PrismaSnapshot[];
};

export function serializeToken(t: TokenWithRelations): Token {
  return {
    id: t.id,
    ticker: t.ticker,
    projectName: t.projectName,
    primaryChain: t.primaryChain,
    coingeckoId: t.coingeckoId,
    defillamaSlug: t.defillamaSlug,
    binanceSymbol: t.binanceSymbol,
    mexcSymbol: t.mexcSymbol,
    cluster: t.cluster,
    notes: t.notes,
    collisionWarning: t.collisionWarning,
    status: t.status as Token["status"],
    createdAt: t.createdAt.toISOString(),
    updatedAt: t.updatedAt.toISOString(),
    deployments: t.deployments.map(serializeDeployment),
    labels: t.labels.map((tl) => serializeLabel(tl.label)),
    latestSnapshot: t.snapshots[0] ? serializeSnapshot(t.snapshots[0]) : null,
  };
}
