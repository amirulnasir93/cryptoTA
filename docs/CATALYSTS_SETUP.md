# Setting up auto-imported catalysts (CoinMarketCal)

Optional. Without this, Catalysts (unlocks/listings/governance/launch events)
stay 100% manually entered on each token's detail page — which is also a
perfectly fine way to use this app; nothing else depends on this integration.

This is a one-time, manual signup — Claude Code cannot create accounts on
your behalf, the same rule that applied to the Google Sheets setup.

## Background: why CoinMarketCal, not CoinGecko/CoinMarketCap

Neither CoinGecko nor CoinMarketCap offers unlock/listing/news data on a free
tier (CoinGecko's News API is explicitly gated to "Analyst plan & above";
CoinMarketCap's vesting-schedule fields exist in their schema but sit behind
a paid plan). CoinMarketCal is a purpose-built crypto events calendar
(listings, unlocks, hard forks, governance, etc.) with a free developer
signup tier.

**Caveat:** CoinMarketCal's official API docs returned a 403 while this was
being built, so the connector (`src/connectors/coinmarketcal.ts`) parses its
response defensively rather than against a confirmed schema. The first real
sync is the actual verification step — if it comes back empty or errors in
an unexpected way, that's the signal to adjust the parsing, not that
something is broken on your end.

## 1. Get an API key

1. Go to [coinmarketcal.com/en/api](https://coinmarketcal.com/en/api) and
   sign up for a developer account (or via
   [api.coinmarketcal.com/developer/dashboard](https://api.coinmarketcal.com/developer/dashboard)).
2. Create an API key from your dashboard.

## 2. Configure the backend

In `packages/backend/.env`:

```
COINMARKETCAL_API_KEY="<your key>"
```

Restart the backend. It'll start running the sync on a schedule
(`CATALYST_SYNC_CRON`, default every 6 hours) and you can also trigger it
on demand from the Settings page's "Sync catalysts" button.

## What the sync does

- Fetches upcoming events (90-day window) across all coins CoinMarketCal
  tracks — not just your watchlist, since there's no guarantee its coin IDs
  line up with our CoinGecko IDs.
- Matches each event's coin(s) to your watchlist by ticker symbol.
- For tickers already flagged as collision-prone in
  `Skills/data-sources.md` (BASED, GENIUS, APEX, ZEST, UAI), a bare ticker
  match isn't trusted — the event's coin *name* also has to plausibly match
  the token's project name, or it's skipped and reported as needing manual
  review rather than silently imported. This mirrors how ticker collisions
  are handled everywhere else in this app.
- Creates a `Catalyst` row per matched event (deduped on token + date +
  description, so re-running the sync never creates duplicates).
- Never deletes or edits catalysts you entered by hand.

## Troubleshooting

- `"skipped": "COINMARKETCAL_API_KEY not configured..."` means the env var
  isn't set yet, or the backend needs a restart after editing `.env`.
- If a token you expect events for never gets anything imported, check
  whether it's one of the collision-prone tickers above — it may be getting
  correctly skipped for manual review rather than failing silently. The
  sync's status message reports how many were flagged this way.
