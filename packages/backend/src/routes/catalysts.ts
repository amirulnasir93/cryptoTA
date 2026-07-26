import type { FastifyInstance } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { config } from "../config.js";
import { prisma } from "../db.js";
import { runCatalystSync } from "../jobs/catalystSyncJob.js";
import { serializeCatalyst } from "../serializers.js";
import { catalystSchema, createCatalystBodySchema } from "../schemas.js";

const idParam = z.object({ id: z.coerce.number() });

function requireRefreshSecret(headerValue: string | string[] | undefined): boolean {
  return headerValue === config.refreshSecret;
}

export async function catalystRoutes(appRaw: FastifyInstance) {
  const app = appRaw.withTypeProvider<ZodTypeProvider>();

  // Same shared-secret pattern as /refresh/run and /sync/sheets/run.
  app.post("/catalysts/sync-coinmarketcal", async (request, reply) => {
    if (!requireRefreshSecret(request.headers["x-refresh-secret"])) {
      return reply.code(401).send({ error: "unauthorized" });
    }
    return runCatalystSync();
  });

  app.post(
    "/catalysts",
    { schema: { body: createCatalystBodySchema, response: { 201: catalystSchema } } },
    async (request, reply) => {
      const catalyst = await prisma.catalyst.create({ data: request.body });
      return reply.code(201).send(serializeCatalyst(catalyst));
    }
  );

  app.delete("/catalysts/:id", { schema: { params: idParam } }, async (request, reply) => {
    const deleted = await prisma.catalyst
      .delete({ where: { id: request.params.id } })
      .catch(() => null);
    if (!deleted) return reply.code(404).send({ error: "not found" });
    return reply.code(204).send();
  });
}
