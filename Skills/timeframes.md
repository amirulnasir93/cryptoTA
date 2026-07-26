# Horizons: what each one actually rests on

The discipline this file enforces is matching evidence to timeframe. Most bad
crypto analysis fails here — it cites a protocol's revenue growth to justify a
four-hour trade, or dismisses a monthly thesis because of an intraday wick. The
inputs are genuinely different at each range, and mixing them produces
confident-sounding nonsense.

## 4-hour scalp

**Rests on:** order book depth and imbalance, bid-ask spread, realized volatility
over recent hours, perpetual funding rate and its direction of change, open
interest change, session volume profile, immediate liquidation clusters.

**Irrelevant at this range:** TVL, revenue, tokenomics, narrative, team, audits.
A protocol's fundamentals do not move inside four hours. Citing them here is a
tell that the analysis is padding.

**Data requirement:** minute-level or better OHLCV, live order book, funding rate.
Aggregator daily data is useless here — by the time CoinGecko updates, the setup
is gone.

**Refuse when:** spread exceeds roughly 0.5%, depth within 1% of mid is thin
relative to intended size, the token trades meaningfully on only one venue, or
cross-source price divergence exceeds 1%. Most small-cap tokens fail this
permanently, and that is the correct finding rather than a gap to work around.

## 1-day scalp (intraday)

**Rests on:** prior-day high/low/close, opening range, VWAP and deviation bands,
intraday volume distribution, funding rate, same-day scheduled news, correlation
to BTC/ETH on the session.

**Marginally relevant:** an unlock or listing landing today. Otherwise fundamentals
stay out.

**Data requirement:** hourly OHLCV minimum, ideally 15-minute. Reliable volume.

**Refuse when:** divergence exceeds 5%, or 24h volume is under roughly $100K, or
volume is dominated by a single pair on a single venue.

## 1-day hold

**Rests on:** daily candle structure, position within recent range, short-term
trend, immediate catalysts in the next 24-48 hours, funding and positioning, recent
notable flows.

**Becoming relevant:** near-term scheduled events — an unlock tomorrow matters
today, because positioning front-runs it.

**Data requirement:** daily OHLCV over at least 30 days, current volume, catalyst
calendar.

## 1-week hold

This is the crossover horizon, and the most useful one for most watchlists. Both
technical structure and discrete events operate here.

**Rests on:** weekly and daily structure, range boundaries, trend across recent
weeks, and critically — every catalyst landing inside the seven-day window:
token unlocks and vesting cliffs, exchange listings, product launches, governance
votes closing, scheduled emissions changes, mainnet or upgrade dates, competitor
launches.

**Also relevant:** TVL and volume trend over recent weeks, holder concentration
changes, notable wallet accumulation or distribution.

**Data requirement:** daily OHLCV over 90 days, TVL series, unlock calendar,
protocol news over the past month.

**The dominant question:** is anything scheduled inside this window? A meaningful
unlock inside seven days generally outweighs the technical picture, because supply
arriving is a mechanical fact while structure is an inference.

## 1-month hold

**Rests on:** protocol fundamentals — TVL trend over 30-90 days, fee and revenue
trend and direction, active user trend, competitive position and share; token
economics — emission rate versus organic demand, the full unlock schedule across
the month, value accrual mechanism and whether it actually functions, float as a
share of total supply; narrative momentum and sector rotation; treasury runway.

**Largely irrelevant:** intraday structure, funding, order book. A month of noise
will wash through these.

**Data requirement:** TVL and revenue time series, complete unlock schedule,
governance activity, competitive landscape, sector flows.

**The dominant question:** is the protocol's economic activity growing or
declining, and does the token capture any of it? A protocol can grow while its
token bleeds — vote-escrow systems, emission-heavy DEXs and low-float launches all
produce this pattern regularly. Assess the token and the protocol separately, then
state the relationship.

## Cross-horizon conflicts

Different horizons will often disagree, and that is information rather than a
problem to resolve. A token can be technically constructive over four hours and
structurally impaired over a month — a low-float name with an unlock in three
weeks is exactly that. Report the divergence plainly instead of averaging it into
mush. The user is choosing a horizon; showing them where the horizons part is the
most valuable thing this analysis does.

When horizons conflict, say which one the evidence is strongest on, and why.
