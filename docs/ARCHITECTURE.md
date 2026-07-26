# Architecture

## Why this exists

`Skills/` is a Claude Code Skill for on-demand qualitative analysis of a
watchlist (horizon-based reads: Constructive/Neutral/Cautious/Not assessable).
It's re-run manually and produces a narrative. This app is the complement:
a persistent tool for day-to-day quantitative monitoring — CRUD on the
watchlist, labels, and a metrics dashboard — that stays running and refreshes
itself. The two are intentionally decoupled: `Skills/fetch.py`'s
divergence/gating logic is **ported** into this app's `gating.ts`, not
imported, so the Skill keeps working standalone if this app disappears.

## Stack

| Layer | Choice | Why |
|---|---|---|
| Backend | Node.js + TypeScript, Fastify | Single language across the stack (this machine had no working Python install); Fastify's `@fastify/swagger` auto-generates an OpenAPI doc, which is what makes a later Flutter client cheap to add. |
| ORM/DB | Prisma + SQLite | Zero-config, file-based, fine for one user. Swapping to Postgres later is an env/schema change, not a rewrite — see `DEPLOY.md`. |
| Scheduler | `node-cron`, in-process | Simple locally; both jobs are also exposed as HTTP endpoints so an external cron can drive them once hosted (see `DEPLOY.md`). |
| Frontend | React + TypeScript + Vite | TanStack Query for data fetching, Recharts for charts, Tailwind for styling. A pure API client — same contract a Flutter app will use later. |
| Shared types | `packages/shared` | One set of TS interfaces imported by both backend and frontend, so the contract can't silently drift. |
| Sheets sync | `google-spreadsheet` + a service account | No OAuth consent screen needed for a single-user tool — see `SHEETS_SETUP.md`. |

## Data model

See `packages/backend/prisma/schema.prisma` for the authoritative schema.
Highlights:

- `Token` — one row per watchlist entry. `status` is `active | archived |
  removed`, all soft states — nothing is ever hard-deleted except by direct DB
  access, so `MetricSnapshot` history never gets orphaned.
- `TokenDeployment` — a token can have several (e.g. EVAA is TON-native but
  its main trading liquidity is a separate BNB Chain contract — both are
  recorded, per `Skills/data-sources.md`).
- `Label` / `TokenLabel` — many-to-many; a token can carry more than one
  label.
- `MetricSnapshot` — one row per token per refresh run: every source's price,
  the computed divergence, the deterministic data-quality/horizon-gate
  output, and the usual fundamentals (mcap, FDV, volume, ATH drawdown, float
  %, TVL).
- `Catalyst` — manually entered (there's no reliable free unlock-calendar
  API); surfaced on both the token detail page and the dashboard's 90-day
  lookahead.
- `SheetSyncState` / `ConflictLog` — bookkeeping for the two-way Sheets sync,
  see below.

## Data pipeline

`jobs/refreshJob.ts`, run on a schedule and via `POST /refresh/run`:

1. Load every non-removed token.
2. Batch-fetch CoinGecko `/coins/markets` for all of them in one call.
3. Per token, fetch DexScreener (by contract), Binance and MEXC (by trading
   symbol) and DefiLlama (by protocol slug) in parallel.
4. `gating.ts` computes cross-source `divergence()`, which `horizonsFor()`
   turns into the set of assessable horizons and `dataQualityFor()` turns into
   a single Good/Degraded/Poor badge — both ported directly from
   `Skills/fetch.py`'s `GATES` table.
5. Writes one `MetricSnapshot` per token and one `FetchRun` for the batch.

Binance/MEXC symbols are resolved once via `scripts/resolveExchangeSymbols.ts`
against each venue's `/exchangeInfo` — deliberately **not** auto-applied for
tickers in `knownCollisions.ts` (BASED, GENIUS, APEX, ZEST, UAI), since a
ticker-string match on an exchange isn't proof it's the same asset. Those were
instead manually verified once (via CoinGecko homepage/category cross-checks)
and hand-entered in `seed/seedFromCsv.ts`.

## Google Sheets two-way sync

`jobs/sheetSyncJob.ts` implements a **shadow-copy 3-way diff**: for every
token, it hashes the current local row, the current Sheet row, and compares
both to `SheetSyncState.baseContentHash` (the hash recorded at the last
successful sync — the "common ancestor"). The pure decision table lives in
`jobs/syncDecision.ts` (unit tested independently of any I/O):

| local vs base | sheet vs base | action |
|---|---|---|
| same | same | no-op |
| changed | same | push local → Sheet |
| same | changed | pull Sheet → local |
| changed (equal to each other) | changed | converge, no data loss |
| changed (different) | changed | **conflict** — Sheet wins, logged to `ConflictLog` |

New rows on either side are handled before this table even applies (append /
create); a row disappearing from the Sheet archives the token locally rather
than deleting it.

## Dashboard scope

Deliberately **quantitative only** — price/mcap/volume/TVL/divergence/data
quality/cluster exposure. The qualitative horizon narrative
(Constructive/Cautious/etc.) stays the Claude Skill's job, run separately;
this app never generates that verdict itself. Cluster exposure grouping
reuses the correlated-cluster map from `Skills/data-sources.md` (Curve
complex, trading-venue tokens, TON, Base, AI-agent cluster) via each token's
`cluster` field.
