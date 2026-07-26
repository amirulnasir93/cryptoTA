import type { FastifyInstance } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { prisma } from "../db.js";
import { serializeToken } from "../serializers.js";
import { dashboardSummarySchema } from "../schemas.js";

const tokenInclude = {
  deployments: true,
  labels: { include: { label: true } },
  snapshots: { orderBy: { fetchedAt: "desc" as const }, take: 1 },
};

const DAY_MS = 24 * 60 * 60 * 1000;

export async function dashboardRoutes(appRaw: FastifyInstance) {
  const app = appRaw.withTypeProvider<ZodTypeProvider>();

  app.get("/dashboard", { schema: { response: { 200: dashboardSummarySchema } } }, async () => {
    const tokens = await prisma.token.findMany({
      where: { status: "active" },
      include: tokenInclude,
      orderBy: { ticker: "asc" },
    });
    const serialized = tokens.map(serializeToken);

    const dataQualityCounts = { Good: 0, Degraded: 0, Poor: 0, Unknown: 0 };
    for (const t of serialized) {
      const q = t.latestSnapshot?.dataQuality;
      if (q === "Good" || q === "Degraded" || q === "Poor") dataQualityCounts[q]++;
      else dataQualityCounts.Unknown++;
    }

    // Reuses the correlated-cluster grouping from Skills/data-sources.md — a
    // token's `cluster` field is seeded from the same column.
    const clusterMap = new Map<string, string[]>();
    for (const t of serialized) {
      const key = t.cluster ?? "Uncategorized";
      if (!clusterMap.has(key)) clusterMap.set(key, []);
      clusterMap.get(key)!.push(t.ticker);
    }
    const clusterExposure = [...clusterMap.entries()]
      .map(([cluster, tickers]) => ({ cluster, tokenCount: tickers.length, tickers }))
      .sort((a, b) => b.tokenCount - a.tokenCount);

    const now = new Date();
    const catalystRows = await prisma.catalyst.findMany({
      where: { eventDate: { gte: now, lte: new Date(now.getTime() + 90 * DAY_MS) } },
      include: { token: true },
      orderBy: { eventDate: "asc" },
    });
    const upcomingCatalysts = catalystRows.map((c) => ({
      id: c.id,
      tokenId: c.tokenId,
      eventDate: c.eventDate.toISOString(),
      eventType: c.eventType as "unlock" | "listing" | "governance" | "launch" | "other",
      description: c.description,
      sizePctOfSupply: c.sizePctOfSupply,
      sourceUrl: c.sourceUrl,
      ticker: c.token.ticker,
      daysUntil: Math.ceil((c.eventDate.getTime() - now.getTime()) / DAY_MS),
    }));

    const movers = [...serialized]
      .filter((t) => t.latestSnapshot?.change24hPct != null)
      .sort(
        (a, b) => Math.abs(b.latestSnapshot!.change24hPct!) - Math.abs(a.latestSnapshot!.change24hPct!)
      )
      .slice(0, 5)
      .map((t) => ({ ticker: t.ticker, tokenId: t.id, change24hPct: t.latestSnapshot!.change24hPct }));

    return {
      generatedAt: new Date().toISOString(),
      tokenCount: serialized.length,
      dataQualityCounts,
      clusterExposure,
      upcomingCatalysts,
      movers,
      tokens: serialized,
    };
  });
}
