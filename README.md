# Crypto Watchlist

A local-first web app for tracking a crypto token watchlist: add/archive/remove
tokens, group them into overlapping labels, and see a metrics dashboard (both
portfolio-wide and per-token) built from CoinGecko, DexScreener, DefiLlama,
Binance and MEXC. `packages/frontend` talks directly to a Google Sheet (as its
database) and to those price APIs from the browser — no backend required —
so it can be hosted for free on GitHub Pages; see
[Web app hosting](#web-app-hosting-github-pages) below. A standalone Android
app (`mobile/`) is also available — see [Mobile app](#mobile-app-android)
below. `packages/backend` (Fastify + Prisma/SQLite + node-cron) still exists
and works for anyone who'd rather self-host a persistent, always-on backend
instead — see `docs/DEPLOY.md`.

It grew out of the `Skills/token-watchlist-analyst` Claude Code Skill in this
repo — that Skill's cross-source divergence gating, ticker-collision traps and
correlated-cluster map are the quantitative core of this app's dashboard.
The Skill itself is untouched and still works standalone; this app is a
separate, persistent tool for day-to-day monitoring rather than an on-demand
Claude analysis.

## Stack

- **Backend:** Node.js + TypeScript, Fastify, Prisma + SQLite, `node-cron`.
- **Frontend:** React + TypeScript, Vite, TanStack Query, Recharts, Tailwind.
- **Sync:** `google-spreadsheet` two-way sync with a Google Sheet (optional).

See `docs/ARCHITECTURE.md` for the full design.

## Prerequisites

- Node.js 20+ and npm (this repo uses npm workspaces).
- No Python required — everything, including the port of `Skills/fetch.py`'s
  gating logic, is TypeScript.

## First-time setup

```bash
npm install                                            # installs all workspaces
cp packages/backend/.env.example packages/backend/.env  # then edit if needed
npm run prisma:migrate                                  # creates the local SQLite DB
npm run seed                                             # imports Skills/watchlist.csv
```

Optionally resolve which watchlist tickers have public Binance/MEXC markets
(skips known ticker-collision names like BASED/GENIUS/APEX/ZEST/UAI, which
need manual verification rather than a blind ticker-string match):

```bash
npm run resolve-symbols --workspace packages/backend
```

## Running it

```bash
npm run dev
```

This starts the backend on `http://localhost:3001` (Swagger docs at `/docs`,
useful if you're self-hosting it — see `docs/DEPLOY.md`) and the frontend on
`http://localhost:5173`. The frontend doesn't talk to that backend at all,
though — the first time you open it, go to **Settings** and paste a Sheet ID
and a Web OAuth Client ID (see `docs/WEB_STANDALONE_SETUP.md`), then sign in
with Google. It refreshes prices for every active token itself, on a plain
"Refresh prices" button — there's no cron in the browser to wait for.

The backend's own `node-cron` job (interval set by `REFRESH_CRON` in `.env`)
and its `POST /refresh/run` endpoint still work for anyone actually using the
backend directly (Swagger, a script, a self-hosted alternate frontend):

```bash
curl -X POST http://localhost:3001/refresh/run -H "x-refresh-secret: <REFRESH_SECRET from .env>"
```

## Google Sheets two-way sync

Optional. See `docs/SHEETS_SETUP.md` for the one-time manual steps (Google
Cloud project, service account, sharing the Sheet) — none of which Claude Code
can do on your behalf. Until that's set up, `/sync/sheets/run` and the
scheduled sync job both no-op with a clear "not configured" message rather
than failing.

## Hosting it somewhere other than your PC

See `docs/DEPLOY.md` — the app is designed so this needs no rearchitecture,
just a `DATABASE_URL` change and a way to trigger `/refresh/run` /
`/sync/sheets/run` on a schedule.

## Repo layout

```
Skills/              the original Claude Code Skill — unchanged
packages/
  shared/             TypeScript types shared by backend and frontend
  backend/            Fastify API, Prisma schema, connectors, jobs
  frontend/           React app (Dashboard / Watchlist / Token detail / Labels)
mobile/               Flutter Android app — see below
docs/                 architecture, Sheets setup, deploy notes
```

## Tests

```bash
npm test   # gating logic + sync-decision logic, run with vitest
```

## Web app hosting (GitHub Pages)

`packages/frontend` builds to static files and is deployed automatically to
GitHub Pages by `.github/workflows/deploy.yml` on every push to `main` (once
Pages is enabled once in the repo's Settings). It needs no backend — same
direct-to-Sheet, direct-to-price-API architecture as the mobile app below,
just running in a browser instead of on a phone. One-time setup (reuses the
mobile app's Web OAuth Client ID): see `docs/WEB_STANDALONE_SETUP.md`.

## Mobile app (Android)

`mobile/` is a Flutter app that deliberately does **not** talk to the backend
above at all — it needs no server running anywhere. It reads and writes the
same Google Sheet directly (signed in as you, not the service account), and
pulls prices straight from CoinGecko/DexScreener/Binance/MEXC, computing all
the same indicators on-device. The web app and the phone stay in sync only
through the shared Sheet, not a live connection to each other.

One-time setup (Google sign-in needs its own OAuth clients, separate from the
web app's service account): see `docs/MOBILE_SHEETS_SETUP.md`. Build with:

```bash
cd mobile
flutter build apk --release --split-per-abi
```
