# Data sources and canonical identifiers

## Why identifiers come first

Ticker collision is the highest-frequency failure in watchlist tooling. Several
symbols on this list are shared with unrelated tokens, and at least one trades
under a different symbol on a major venue. Resolve to a contract address or
aggregator slug before fetching anything. A confident analysis of the wrong asset
is the worst output this skill can produce, because nothing about it looks wrong.

Known traps on the current list:

- **BASED** is Based One (based.one), contract
  `0x4f2b33840227ddd0e28da8d4185d6fa07adfed87`, CoinGecko slug `based-one`.
  Coinbase lists it as **BASED1**, not BASED. Two unrelated micro-cap tokens also
  use the BASED ticker on Base (`based-2`, `based-coin`) — both are effectively
  illiquid and are not this asset.
- **GENIUS** is Genius Terminal, CoinGecko slug `genius-3`. Distinct from
  Genius (GENI) on Polygon and Genius Token (GNUS).
- **APEX**, **ZEST**, **UAI** each collide with other projects. Match on chain and
  contract.
- **EVAA** and **TRADOOR** are TON-native protocols whose primary *trading*
  liquidity sits on BNB Chain. A price feed keyed only to the TON contract will
  under-report volume badly. Fetch both deployments.
- **BASED** is a LayerZero OFT spanning Ethereum, BSC and Hyperliquid, so supply is
  split across chains. Check how each source handles multi-chain supply before
  trusting a circulating figure.

## Source reliability by metric

No single source is right about everything. Rough hierarchy:

**Price and volume** — CoinGecko and CoinMarketCap for majors; both are reliable
where liquidity is deep. For thin-float names, treat any single aggregator as one
estimate among several and report the range. DEX-native tokens are better served by
DexScreener or GeckoTerminal, which index pools directly.

**TVL, fees, revenue** — DefiLlama, free and keyless, is the best available source
and generally the one to trust when it conflicts with an aggregator. Note its
metadata (market cap, supply) is sometimes stale even when its TVL is current;
prefer DefiLlama for protocol metrics and an aggregator for token metrics.

**Holder counts and concentration** — block explorers directly: Etherscan, BscScan,
Basescan, Tonviewer, the Stacks explorer. Aggregator holder counts are frequently
stale. Concentration matters more than raw count.

**Supply and unlocks** — project documentation first, then the block explorer, then
aggregators. Aggregator circulating-supply figures are the single most frequently
wrong number in this domain, particularly in the months after a launch. Where a
project's own docs and an explorer agree against an aggregator, trust them.

**News and catalysts** — official blogs, governance forums and reputable crypto
media. Exclude SEO "price prediction" pages entirely; they are generated content
and contaminate analysis with fabricated targets.

## Reconciling conflicts

When sources disagree, do not silently pick one. Report the range, then reason
about which is likelier correct:

- Is one source's timestamp materially older?
- Does one use a different supply figure, producing a different market cap from the
  same price?
- Is one indexing a single venue while the token trades across several chains?
- Post-launch tokens routinely show large divergence because circulating supply is
  genuinely disputed — this is a real signal about float uncertainty, not just a
  data bug, and it belongs in the output.

Divergence above roughly 20% on a liquid asset usually means the sources are
tracking different things. Investigate before reporting.

## Correlated clusters on the current watchlist

Assess the list as a portfolio. These names do not move independently:

- **Curve complex** — CRV and CVX. Convex's value derives from directing Curve
  gauge votes, so it is a leveraged expression of Curve. Treat a read on one as a
  read on both.
- **Trading venues** — UNI, AERO, APEX, TRADOOR, GENIUS, BASED, and CRV. Seven of
  thirteen names are DEXs, perp venues or trading front-ends. This is the dominant
  concentration on the list, and a sector-wide drawdown in trading volume hits all
  of them together.
- **TON** — EVAA and TRADOOR.
- **Base** — AERO and RECALL.
- **AI agents** — RECALL, UAI, ENSO.
- **Hyperliquid-adjacent** — BASED, and APEX by overlap.
- **Genuinely differentiated** — ZEST (Bitcoin DeFi on Stacks) and UNI (large-cap).

When multiple names in one cluster read constructive, say so plainly. Five
correlated constructive reads is one idea, not five.

## Free-tier fetching notes

CoinGecko's Demo tier allows roughly 10,000 calls a month with a rate limit
somewhere around 30 calls per minute — its own docs and pricing page disagree, so
plan conservatively. Batch aggressively: `/simple/price` and `/coins/markets` accept
many IDs per call, turning a thirteen-token list into one or two requests rather
than thirteen. DefiLlama and DexScreener are free and keyless. Etherscan's free tier
was cut in July 2026 — verify current limits rather than assuming.

Cache locally and respect TTLs. For a personal watchlist, polling prices every
30-60 seconds and protocol metrics every 5-15 minutes stays comfortably inside
every free tier.
