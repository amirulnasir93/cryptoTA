import { PrismaClient } from "@prisma/client";

// Singleton so tsx's watch-mode reloads don't open a new SQLite connection pool
// every time a file changes.
const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: ["warn", "error"],
  });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}

// SQLite: allow concurrent reads while a write (refresh job / sheet sync) is in
// flight, rather than locking the whole DB file. PRAGMA journal_mode returns a
// row (the resulting mode), so it must go through $queryRawUnsafe, not
// $executeRawUnsafe, or SQLite rejects it as "not allowed" for an exec call.
prisma.$queryRawUnsafe("PRAGMA journal_mode=WAL;").catch(() => {
  // Best-effort — if this fails (e.g. on a networked filesystem) the app still
  // works, just with SQLite's default locking behaviour.
});
