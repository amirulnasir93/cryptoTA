import type { FastifyPluginAsync } from "fastify";
import { config } from "../config.js";
import { runRefresh } from "../jobs/refreshJob.js";

function requireRefreshSecret(headerValue: string | string[] | undefined): boolean {
  return headerValue === config.refreshSecret;
}

// A shared-secret header (not session/cookie auth) so this can be triggered
// identically from the web UI, curl, or later a GitHub Actions cron job once
// this is hosted somewhere that idles the process.
export const refreshRoutes: FastifyPluginAsync = async (app) => {
  app.post("/refresh/run", async (request, reply) => {
    if (!requireRefreshSecret(request.headers["x-refresh-secret"])) {
      return reply.code(401).send({ error: "unauthorized" });
    }
    const result = await runRefresh();
    return result;
  });
};
