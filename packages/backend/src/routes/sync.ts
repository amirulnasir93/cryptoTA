import type { FastifyPluginAsync } from "fastify";
import { config } from "../config.js";
import { prisma } from "../db.js";
import { runSheetSync } from "../jobs/sheetSyncJob.js";

function requireRefreshSecret(headerValue: string | string[] | undefined): boolean {
  return headerValue === config.refreshSecret;
}

async function recentConflicts(since?: Date) {
  const rows = await prisma.conflictLog.findMany({
    where: since ? { detectedAt: { gte: since } } : undefined,
    include: { token: true },
    orderBy: { id: since ? "asc" : "desc" },
    take: since ? undefined : 50,
  });
  return rows.map((c) => ({
    id: c.id,
    tokenId: c.tokenId,
    ticker: c.token.ticker,
    detectedAt: c.detectedAt.toISOString(),
    field: c.field,
    localValue: c.localValue,
    sheetValue: c.sheetValue,
    resolution: c.resolution,
  }));
}

// Same shared-secret pattern as /refresh/run, so both can be triggered
// identically from the UI, curl, or a future GitHub Actions cron job.
export const syncRoutes: FastifyPluginAsync = async (app) => {
  app.post("/sync/sheets/run", async (request, reply) => {
    if (!requireRefreshSecret(request.headers["x-refresh-secret"])) {
      return reply.code(401).send({ error: "unauthorized" });
    }
    const startedAt = new Date();
    const summary = await runSheetSync();
    return {
      ranAt: summary.ranAt,
      pushed: summary.pushed,
      pulled: summary.pulled,
      created: summary.created,
      archived: summary.archived,
      skipped: summary.skipped,
      conflicts: await recentConflicts(startedAt),
    };
  });

  app.get("/sync/conflicts", async () => recentConflicts());
};
