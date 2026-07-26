import type { FastifyInstance } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { prisma } from "../db.js";
import { serializeSnapshot } from "../serializers.js";
import { metricSnapshotSchema } from "../schemas.js";

const params = z.object({ id: z.coerce.number() });
const query = z.object({ limit: z.coerce.number().min(1).max(500).optional() });

export async function snapshotRoutes(appRaw: FastifyInstance) {
  const app = appRaw.withTypeProvider<ZodTypeProvider>();

  app.get(
    "/tokens/:id/history",
    { schema: { params, querystring: query, response: { 200: z.array(metricSnapshotSchema) } } },
    async (request) => {
      const snapshots = await prisma.metricSnapshot.findMany({
        where: { tokenId: request.params.id },
        orderBy: { fetchedAt: "desc" },
        take: request.query.limit ?? 90,
      });
      return [...snapshots].reverse().map(serializeSnapshot);
    }
  );
}
