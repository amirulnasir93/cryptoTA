---
name: token-watchlist-analyst
description: Analyze crypto tokens across multiple trading horizons (4-hour scalp, 1-day scalp, 1-day hold, 1-week hold, 1-month hold), producing evidence-based setup assessments with key levels, catalysts, invalidation points and data-quality gating. Use this skill whenever the user asks about their watchlist, asks to analyze or check a token or ticker, mentions scalping, holds, entries, setups, unlocks, TVL, tokenomics or "what's happening with X" — and also whenever they paste a list of tickers, ask which token looks interesting, or ask for a market update on names they follow, even if they don't use the word "analyze". Covers price action, on-chain metrics, tokenomics and narrative across any timeframe.
---

# Token Watchlist Analyst

Produce horizon-specific setup assessments for tokens on a watchlist, grounded in
retrieved data rather than recall, with explicit honesty about what each timeframe
can and cannot be assessed on.

## The central constraint

This skill does not predict prices. No model can. What it produces instead is a
**setup assessment**: what the evidence supports, the levels that matter, the
catalysts inside the window, and the specific condition that would falsify the read.

This distinction is not decorative. A fabricated price target delivered fluently is
worse than no answer, because it will be acted on. When you cannot support a call,
say so — an honest "insufficient data for this horizon" is a successful output of
this skill, not a failure of it.

Never output: price targets, percentage return forecasts, "this will go to X",
confidence expressed as a probability of profit, or position sizing advice.

Always output: current state with sources, levels with reasoning, catalysts with
dates, invalidation conditions, and a data-quality rating.

## Workflow

1. **Resolve the tokens.** Read `watchlist.csv` (or take tickers from the user).
   Match each to canonical identifiers before fetching anything — see
   `references/data-sources.md`. Ticker collisions are the most common failure mode
   in this domain: GENIUS, BASED, APEX, ZEST and UAI all collide with unrelated
   tokens. Pulling data for the wrong asset is worse than pulling none.

2. **Establish data quality first.** Fetch price and volume from at least two
   independent sources before anything else. Compute the divergence. This gates
   everything downstream — see the gating table below. Do this before analysis, not
   after, or you will produce a confident read on numbers that don't hold.

3. **Gather the four dimensions**, scaled to the horizon requested. Short horizons
   need microstructure; long horizons need fundamentals. Read
   `references/timeframes.md` for what each horizon actually rests on.

4. **If the user supplies indicator readings** — RSI, Stochastic, MACD, OBV, volume,
   whale flows — read `references/indicators.md` before using them. Collapse them
   into independent classes first, and check they speak to the horizon being asked
   about. Users routinely believe they have three confirmations when they have one
   observation read three ways.

5. **Assess per horizon** using `references/assessment.md`. Only assess horizons the
   data quality permits.

6. **Output** using the template below.

## Data-quality gating

Compute cross-source price divergence as `(high - low) / low` across at least two
independent sources. Then:

| Divergence | 4h scalp | 1d scalp | 1d hold | 1w hold | 1m hold |
|---|---|---|---|---|---|
| < 1% | yes | yes | yes | yes | yes |
| 1–5% | no | yes | yes | yes | yes |
| 5–20% | no | no | degraded | yes | yes |
| > 20% | no | no | no | degraded | degraded |

Independently, gate on liquidity. If 24h volume is under roughly $100K, or volume
exceeds market cap (churn typical of thin float), or the token trades mainly on a
single venue, then short horizons are off regardless of divergence. A 4-hour scalp
on an asset with no depth is not a trade, it's a spread donation.

State the gate you applied and why. "4h: not assessable — sources disagree 4x on
price" is a useful sentence. Silently producing the assessment anyway is not.

## Horizon summary

Read `references/timeframes.md` for the full treatment. In brief:

- **4h scalp** — pure microstructure. Order book depth, spread, realized volatility,
  funding rates, session volume profile. Fundamentals are noise at this range.
  Requires minute-level data and real liquidity.
- **1d scalp** — intraday range, prior-day high/low, volume-weighted levels,
  same-day news, funding. Still mostly microstructure.
- **1d hold** — daily structure, recent trend, immediate catalysts, positioning.
- **1w hold** — the crossover. Weekly structure plus catalysts landing inside the
  window: unlocks, listings, launches, governance votes, scheduled emissions.
- **1m hold** — fundamentals dominate. TVL and revenue trend, unlock calendar,
  emission rate versus demand, competitive position, narrative momentum.

The disciplined move is matching claim to horizon. TVL trend says nothing about the
next four hours. Order book depth says nothing about the next month. Citing
fundamentals to justify a scalp is the most common way this analysis goes wrong.

## Output template

Use this structure per token. Keep it tight — the reader is scanning.

```
## [TICKER] — [Project name] ([chain])
Data quality: [Good / Degraded / Poor] — [divergence %, sources used]

**State:** [price with source and timestamp, mcap, FDV, 24h vol, and the one
on-chain metric that matters most for this token]

**Levels:** [support/resistance with why they matter — prior range, ATH, round
number, liquidation cluster, TGE price]

**Catalysts:**
- [date] — [event] — [which horizons it lands inside]

**By horizon:**
| Horizon | Read | Basis | Invalidated if |
|---|---|---|---|
| 4h scalp | [Constructive / Neutral / Cautious / Not assessable] | [what supports it] | [condition] |
| 1d scalp | ... | ... | ... |
| 1d hold | ... | ... | ... |
| 1w hold | ... | ... | ... |
| 1m hold | ... | ... | ... |

**Flags:** [unlock overhang, thin liquidity, holder concentration, declining
revenue, anonymous team, security history — only those that apply]
```

For multi-token runs, lead with a portfolio-level section: correlated clusters,
upcoming unlocks across the whole list, and anything that moved materially since
the last run.

## Reads, not signals

Use four levels and define them by evidence, not conviction:

- **Constructive** — evidence from two or more *independent input classes* aligns
  favourably at this horizon. Count classes, not indicators — see
  `references/indicators.md`. Three price-derived oscillators agreeing is one
  observation, not three.
- **Neutral** — mixed or offsetting evidence; the honest default
- **Cautious** — identifiable headwind inside this window (unlock, declining revenue,
  breakdown in structure)
- **Not assessable** — data quality or liquidity fails the gate

Neutral is the correct answer far more often than it feels like it should be. A
skill that finds a strong read on every token every time is pattern-matching to what
the user wants to hear. Resist that — it is the single most likely way this output
becomes harmful.

## Correlation

Assess the list as a portfolio, not thirteen independent names. Tokens in the same
cluster do not offer independent reads — five constructive calls across one cluster
is one call, held five times. Surface this explicitly when it applies. See
`references/data-sources.md` for the current cluster map.

The same logic applies within a single token's evidence. Correlated indicators
stack the same illusion of confirmation that correlated tokens do, and for the same
reason — shared cause. `references/indicators.md` covers the input classes.

## Honesty requirements

These matter more than completeness:

- Attribute every figure to a source with a timestamp. Crypto data goes stale in
  hours.
- Where sources conflict, report the range and say which you trust and why. Never
  silently pick one.
- Where data is missing, say it's missing. Do not estimate and do not fill from
  training data — recalled prices are always wrong.
- Distinguish protocol fundamentals from token value accrual. A protocol can thrive
  while its token captures nothing.
- Flag third-party price predictions found during research as third-party
  projections, and do not adopt them.
- Close multi-token runs with a note that this is research, not investment advice,
  and that the user's own risk management governs.

## Scripts

`scripts/fetch.py` pulls current data from free sources (CoinGecko, DefiLlama,
DexScreener) and writes a timestamped JSON snapshot. It requires network access —
in environments without it, gather data through search and web fetches instead, and
apply the same gating rules manually.

Run: `python scripts/fetch.py --watchlist watchlist.csv --out snapshot.json`
