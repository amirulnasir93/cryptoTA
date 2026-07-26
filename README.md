# Crypto Watchlist

A local-first web app for tracking a crypto token watchlist: add/archive/remove
tokens, group them into overlapping labels, and see a metrics dashboard (both
portfolio-wide and per-token) built from CoinGecko, DexScreener, DefiLlama,
Binance and MEXC. Optionally keeps itself in sync both ways with a Google
Sheet. A standalone Android app (`mobile/`) is also available — see
[Mobile app](#mobile-app-android) below.

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

This starts the backend on `http://localhost:3001` (Swagger docs at
`/docs`) and the frontend on `http://localhost:5173`. The backend also starts
a background job (`node-cron`, interval set by `REFRESH_CRON` in `.env`) that
periodically refreshes prices/metrics for every active token.

To trigger a refresh manually instead of waiting for the cron:

```bash
curl -X POST http://localhost:3001/refresh/run -H "x-refresh-secret: <REFRESH_SECRET from .env>"
```

(The frontend's Watchlist page has a "Refresh prices" button that does the
same thing once you paste that secret in.)

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
