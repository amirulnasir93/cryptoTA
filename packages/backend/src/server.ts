import Fastify from "fastify";
import cors from "@fastify/cors";
import swagger from "@fastify/swagger";
import swaggerUi from "@fastify/swagger-ui";
import {
  jsonSchemaTransform,
  serializerCompiler,
  validatorCompiler,
} from "fastify-type-provider-zod";
import { config } from "./config.js";
import { startScheduler } from "./jobs/scheduler.js";
import { refreshRoutes } from "./routes/refresh.js";
import { tokenRoutes } from "./routes/tokens.js";
import { labelRoutes } from "./routes/labels.js";
import { catalystRoutes } from "./routes/catalysts.js";
import { snapshotRoutes } from "./routes/snapshots.js";
import { dashboardRoutes } from "./routes/dashboard.js";
import { syncRoutes } from "./routes/sync.js";
import { analysisRoutes } from "./routes/analysis.js";
import { insightRoutes } from "./routes/insight.js";
import { lookupRoutes } from "./routes/lookup.js";
import { prisma } from "./db.js";

async function buildServer() {
  const app = Fastify({ logger: true });

  app.setValidatorCompiler(validatorCompiler);
  app.setSerializerCompiler(serializerCompiler);

  // The configured WEB_ORIGIN covers the React frontend's usual port, but
  // other local-only clients (the Flutter app's web build, a Vite instance
  // that fell back to a different port because 5173 was taken) run on
  // whatever port they land on. This is a local dev API with no public
  // exposure, so any localhost/127.0.0.1 origin is trusted rather than
  // hardcoding one port.
  await app.register(cors, {
    origin: (origin, cb) => {
      if (!origin || /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin) || origin === config.webOrigin) {
        cb(null, true);
        return;
      }
      cb(new Error("Not allowed by CORS"), false);
    },
  });

  await app.register(swagger, {
    openapi: { info: { title: "Crypto Analyzer API", version: "0.1.0" } },
    transform: jsonSchemaTransform,
  });
  await app.register(swaggerUi, { routePrefix: "/docs" });

  app.get("/health", async () => ({ ok: true }));

  await app.register(refreshRoutes);
  await app.register(tokenRoutes);
  await app.register(labelRoutes);
  await app.register(catalystRoutes);
  await app.register(snapshotRoutes);
  await app.register(dashboardRoutes);
  await app.register(syncRoutes);
  await app.register(analysisRoutes);
  await app.register(insightRoutes);
  await app.register(lookupRoutes);

  return app;
}

async function main() {
  const app = await buildServer();
  await app.listen({ port: config.port, host: "0.0.0.0" });
  startScheduler();

  const shutdown = async () => {
    await app.close();
    await prisma.$disconnect();
    process.exit(0);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
