import type { FastifyInstance } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { prisma } from "../db.js";
import { serializeLabel } from "../serializers.js";
import { createLabelBodySchema, errorSchema, labelSchema, updateLabelBodySchema } from "../schemas.js";

const idParam = z.object({ id: z.coerce.number() });

export async function labelRoutes(appRaw: FastifyInstance) {
  const app = appRaw.withTypeProvider<ZodTypeProvider>();

  app.get("/labels", { schema: { response: { 200: z.array(labelSchema) } } }, async () => {
    const labels = await prisma.label.findMany({ orderBy: { name: "asc" } });
    return labels.map(serializeLabel);
  });

  app.post(
    "/labels",
    { schema: { body: createLabelBodySchema, response: { 201: labelSchema, 409: errorSchema } } },
    async (request, reply) => {
      const existing = await prisma.label.findUnique({ where: { name: request.body.name } });
      if (existing) return reply.code(409).send({ error: "label name already exists" });
      const label = await prisma.label.create({ data: request.body });
      return reply.code(201).send(serializeLabel(label));
    }
  );

  app.patch(
    "/labels/:id",
    { schema: { params: idParam, body: updateLabelBodySchema, response: { 200: labelSchema, 404: errorSchema } } },
    async (request, reply) => {
      const label = await prisma.label
        .update({ where: { id: request.params.id }, data: request.body })
        .catch(() => null);
      if (!label) return reply.code(404).send({ error: "not found" });
      return serializeLabel(label);
    }
  );

  app.delete("/labels/:id", { schema: { params: idParam } }, async (request, reply) => {
    const deleted = await prisma.label.delete({ where: { id: request.params.id } }).catch(() => null);
    if (!deleted) return reply.code(404).send({ error: "not found" });
    return reply.code(204).send();
  });
}
