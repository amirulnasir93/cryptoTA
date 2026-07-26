import type { FastifyInstance } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { prisma } from "../db.js";
import { collisionWarningFor } from "../knownCollisions.js";
import { serializeCatalyst, serializeSnapshot, serializeToken } from "../serializers.js";
import {
  createTokenBodySchema,
  errorSchema,
  tokenDetailSchema,
  tokenSchema,
  updateTokenBodySchema,
} from "../schemas.js";

const idParam = z.object({ id: z.coerce.number() });
const listQuery = z.object({
  status: z.enum(["active", "archived", "removed", "all"]).optional(),
  labelId: z.coerce.number().optional(),
});

// A token can have many labels (many-to-many), so the frontend always sends
// the full desired set on PATCH rather than incremental add/remove calls.
const tokenInclude = {
  deployments: true,
  labels: { include: { label: true } },
  snapshots: { orderBy: { fetchedAt: "desc" as const }, take: 1 },
};

export async function tokenRoutes(appRaw: FastifyInstance) {
  const app = appRaw.withTypeProvider<ZodTypeProvider>();

  app.get(
    "/tokens",
    { schema: { querystring: listQuery, response: { 200: z.array(tokenSchema) } } },
    async (request) => {
      const { status, labelId } = request.query;
      const statusFilter = status === "all" ? undefined : status ?? { not: "removed" };

      const tokens = await prisma.token.findMany({
        where: {
          status: statusFilter,
          ...(labelId ? { labels: { some: { labelId } } } : {}),
        },
        include: tokenInclude,
        orderBy: { ticker: "asc" },
      });
      return tokens.map(serializeToken);
    }
  );

  app.get(
    "/tokens/:id",
    { schema: { params: idParam, response: { 200: tokenDetailSchema, 404: errorSchema } } },
    async (request, reply) => {
      const token = await prisma.token.findUnique({
        where: { id: request.params.id },
        include: {
          deployments: true,
          labels: { include: { label: true } },
          snapshots: { orderBy: { fetchedAt: "desc" as const }, take: 90 },
          catalysts: { orderBy: { eventDate: "asc" as const } },
        },
      });
      if (!token) return reply.code(404).send({ error: "not found" });

      const siblings = token.cluster
        ? await prisma.token.findMany({
            where: { cluster: token.cluster, id: { not: token.id }, status: { not: "removed" } },
            include: { snapshots: { orderBy: { fetchedAt: "desc" as const }, take: 1 } },
          })
        : [];

      const base = serializeToken({ ...token, snapshots: token.snapshots.slice(0, 1) });

      return {
        ...base,
        history: [...token.snapshots].reverse().map(serializeSnapshot),
        catalysts: token.catalysts.map(serializeCatalyst),
        clusterSiblings: siblings.map((s) => ({
          id: s.id,
          ticker: s.ticker,
          projectName: s.projectName,
          latestSnapshot: s.snapshots[0] ? serializeSnapshot(s.snapshots[0]) : null,
        })),
      };
    }
  );

  app.post(
    "/tokens",
    { schema: { body: createTokenBodySchema, response: { 201: tokenSchema } } },
    async (request, reply) => {
      const { labelIds, ...data } = request.body;
      const ticker = data.ticker.trim().toUpperCase();

      const token = await prisma.token.create({
        data: {
          ...data,
          ticker,
          // Applied automatically on every add, not just seeded rows — see
          // Skills/data-sources.md's "Known traps on the current list".
          collisionWarning: collisionWarningFor(ticker),
          labels: labelIds?.length ? { create: labelIds.map((labelId) => ({ labelId })) } : undefined,
        },
        include: tokenInclude,
      });
      return reply.code(201).send(serializeToken(token));
    }
  );

  app.patch(
    "/tokens/:id",
    { schema: { params: idParam, body: updateTokenBodySchema, response: { 200: tokenSchema, 404: errorSchema } } },
    async (request, reply) => {
      const { labelIds, ...data } = request.body;

      const token = await prisma.token
        .update({
          where: { id: request.params.id },
          data: {
            ...data,
            localVersion: { increment: 1 },
            ...(labelIds
              ? { labels: { deleteMany: {}, create: labelIds.map((labelId) => ({ labelId })) } }
              : {}),
          },
          include: tokenInclude,
        })
        .catch(() => null);

      if (!token) return reply.code(404).send({ error: "not found" });
      return serializeToken(token);
    }
  );

  app.post(
    "/tokens/:id/archive",
    { schema: { params: idParam, response: { 200: tokenSchema, 404: errorSchema } } },
    async (request, reply) => {
      const token = await prisma.token
        .update({
          where: { id: request.params.id },
          data: { status: "archived", localVersion: { increment: 1 } },
          include: tokenInclude,
        })
        .catch(() => null);
      if (!token) return reply.code(404).send({ error: "not found" });
      return serializeToken(token);
    }
  );

  app.post(
    "/tokens/:id/restore",
    { schema: { params: idParam, response: { 200: tokenSchema, 404: errorSchema } } },
    async (request, reply) => {
      const token = await prisma.token
        .update({
          where: { id: request.params.id },
          data: { status: "active", localVersion: { increment: 1 } },
          include: tokenInclude,
        })
        .catch(() => null);
      if (!token) return reply.code(404).send({ error: "not found" });
      return serializeToken(token);
    }
  );

  // Soft delete only (status -> "removed"), never a hard delete: keeps
  // MetricSnapshot history intact and mirrors how a row disappearing from the
  // synced Google Sheet is handled (see the Phase 7 sync algorithm).
  app.delete("/tokens/:id", { schema: { params: idParam } }, async (request, reply) => {
    const token = await prisma.token
      .update({
        where: { id: request.params.id },
        data: { status: "removed", localVersion: { increment: 1 } },
      })
      .catch(() => null);
    if (!token) return reply.code(404).send({ error: "not found" });
    return reply.code(204).send();
  });
}
