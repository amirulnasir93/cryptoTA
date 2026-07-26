import type { FastifyInstance } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { searchCoingecko } from "@crypto-analyzer/shared";

const query = z.object({ q: z.string().min(1) });

// Backs the Add Token form's CoinGecko-id typeahead -- picking from a search
// result instead of hand-typing an id is exactly how the stale APEX/RECALL
// ids (see dataCorrections.ts) would have been avoided in the first place.
export async function lookupRoutes(appRaw: FastifyInstance) {
  const app = appRaw.withTypeProvider<ZodTypeProvider>();

  app.get("/lookup/coingecko", { schema: { querystring: query } }, async (request) => {
    return searchCoingecko(request.query.q);
  });
}
