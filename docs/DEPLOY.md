# Moving off "runs on my PC"

The app is local-first today, but was deliberately built so hosting it
elsewhere later needs configuration changes, not a rewrite. This is what
changes and why.

## The database

Prisma + SQLite locally. Prisma is the reason this swap is cheap: every query
goes through `prisma.token.findMany(...)`-style calls, never raw
SQLite-dialect SQL, so switching providers is a schema/env change, not a code
change.

- **Fly.io** — allocate a small persistent volume, mount it where
  `DATABASE_URL`'s `file:` path points, and SQLite keeps working exactly as-is.
  Cheapest true "lift and shift."
- **Neon or Supabase (free Postgres)** — change
  `provider = "sqlite"` to `provider = "postgresql"` in
  `packages/backend/prisma/schema.prisma`, point `DATABASE_URL` at the
  Postgres connection string, run `prisma migrate deploy`. Both have a free
  tier that doesn't expire, unlike some others.
- **Avoid Render's free web-service tier for this app specifically** — its
  filesystem is ephemeral (wiped on every redeploy/restart/scale-to-zero), so
  a SQLite file there silently loses data, and its free Postgres expires after
  30 days. Render is fine for other things, just not as the disk this app
  writes to.

## The scheduled jobs

Locally, `node-cron` runs inside the same long-lived Fastify process. That
breaks if a host spins the process down when idle (common on free tiers),
since a cron registered in-process simply stops firing while asleep.

Both jobs are already exposed as plain, externally-triggerable endpoints for
exactly this reason:

- `POST /refresh/run`
- `POST /sync/sheets/run`

Both require an `x-refresh-secret` header matching `REFRESH_SECRET` from
`.env` — set that to a long random value once you're hosting this somewhere
reachable from the internet.

Once hosted, replace the in-process cron with an external one that just calls
these endpoints on a schedule:

- **GitHub Actions** — a `schedule:` (cron) workflow that does a `curl -X POST`
  to both endpoints. Free, needs nothing installed on the host, and pairs
  naturally with keeping the code on GitHub anyway.
- **The host's own cron feature** — Render Cron Jobs, Railway Cron, etc., if
  you'd rather not depend on GitHub Actions.

No backend code changes either way — only which scheduler calls the same two
HTTP endpoints.

## The frontend

`packages/frontend` builds to static files (`npm run build --workspace packages/frontend`
→ `packages/frontend/dist`). That can be hosted anywhere static files are
served — GitHub Pages, Vercel, Netlify, or served directly by the backend.
Set `VITE_API_URL` at build time to point it at wherever the backend ends up
living, instead of the `http://localhost:3001` default.

## CORS

`WEB_ORIGIN` in the backend's `.env` controls the CORS allow-list. Update it
to the frontend's real hosted origin once that's not `localhost:5173` anymore.

## Google Sheets sync

No changes needed — the service-account key and Sheet ID work identically
wherever the backend process runs. Just make sure
`packages/backend/secrets/service-account.json` (or its contents, as a
platform secret) makes it to the hosted environment; it's gitignored on
purpose and won't come along with a `git push`.

## Flutter client (later)

Once hosted, the same `VITE_API_URL`-style base URL is all a Flutter client
needs to point at — the API doesn't distinguish between the web frontend and
a future mobile client beyond CORS (which only applies to browser clients
anyway).
