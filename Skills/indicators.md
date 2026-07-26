# Indicators

## The independence rule

Confluence only counts across independent input classes. Most "three indicators
agree" setups are one input read three ways, and the agreement is arithmetic rather
than evidence.

There are four genuinely different classes:

1. **Price-derived momentum** — RSI, Stochastic, MACD, rate of change, moving
   averages. All computed from the same price series. Heavily correlated with each
   other by construction.
2. **Volume-derived** — volume trend, volume factor, OBV, volume profile. Different
   input, though contaminated in crypto (see below).
3. **Derivatives positioning** — funding rate, open interest, long/short ratio,
   liquidation levels.
4. **On-chain flows** — exchange netflow, holder concentration change, whale wallet
   movement, vesting contract outflows.

RSI oversold plus Stochastic oversold plus MACD below signal is **one** observation
from class 1, not three. RSI oversold plus rising OBV plus negative funding plus
exchange outflows is **four** classes agreeing, and that is a real confluence.

When counting confluence, count classes, never indicators.

## Horizon routing

| Indicator | 4h scalp | 1d scalp | 1d hold | 1w hold | 1m hold |
|---|---|---|---|---|---|
| RSI | yes | yes | yes | weak | no |
| Stochastic | yes | yes | weak | no | no |
| MACD | noisy | yes | yes | yes | weak |
| Volume factor | yes | yes | yes | yes | yes |
| OBV | weak | yes | yes | yes | weak |
| Funding / OI | yes | yes | yes | weak | no |
| Whale flows | no | weak | yes | yes | yes |
| Exchange netflow | no | weak | yes | yes | yes |
| Holder concentration | no | no | no | yes | yes |
| TVL / revenue trend | no | no | no | weak | yes |

"No" means the indicator cannot speak to that horizon — not that it is unavailable.
Routing an oscillator reading to a monthly decision is the horizon-smearing failure
described in `timeframes.md`.

## RSI

Bounded momentum oscillator, 0-100, conventionally oversold below 30 and overbought
above 70.

**Oversold is a condition, not a signal.** In a sustained downtrend RSI sits under
30 for weeks while price continues lower. For a low-float token under continuous
emission or unlock pressure, oversold is the resting state rather than an anomaly —
buying it is buying the structural condition of the asset.

The higher-value use is **divergence**: price making a lower low while RSI makes a
higher low suggests selling pressure is decelerating. Divergence is worth noting;
absolute level rarely is on its own.

Default period 14. On 4h crypto charts this is noisy; on 1d it is more stable.

## Stochastic

Measures where the close sits within the recent high-low range. %K fast, %D its
moving average. Faster and noisier than RSI.

Of the oscillators this has the highest false-positive rate, and it is the one I
would weight least. In strong trends it "embeds" — pinning near an extreme for
extended stretches while price continues in the trend direction. Traders read the
embedded reading as an imminent reversal and are repeatedly wrong.

Because it is computed from the same price series as RSI, treat a Stochastic
reading that agrees with RSI as confirming nothing. Where it earns attention is
disagreement with RSI, which usually means the recent range has shifted.

Useful mainly for 4h and intraday. Not informative beyond a day.

## MACD

Difference between two exponential moving averages, plus a signal line and
histogram. A trend-following construction, so it lags by design.

Crossovers are the commonly cited signal and are weak in isolation — lagging and
prone to whipsaw in ranging conditions, which is most conditions. The histogram is
more informative than the crossover, since it shows momentum changing before the
lines cross.

Default 12/26/9 was designed for daily equity charts. On 4h crypto it generates
frequent false crossovers. If used at that horizon, expect noise.

Most useful at 1d and 1w for establishing trend state — is this asset trending or
ranging — rather than for entry timing.

## Volume factor

Current volume relative to its own recent average, plus two ratios worth computing:
volume-to-market-cap, and volume concentration across venues.

**This is the credibility check on every other indicator.** A breakout on
below-average volume is noise. An oversold reading on collapsing volume means
disinterest, not accumulation. Check volume before trusting any price-derived
signal.

Specific readings that matter:

- **Volume-to-market-cap above ~1** means the entire float is turning over daily.
  This is speculative churn typical of recently launched thin-float tokens, not
  organic liquidity. Several names on this watchlist show it.
- **Volume concentrated on a single venue or pair** means the "price" is one order
  book's opinion. Cross-source divergence usually follows.
- **Volume on low-tier exchanges** is frequently wash traded. Prefer volume from
  venues with credible surveillance, and prefer DEX volume, which is verifiable
  on-chain.

## OBV

On-balance volume: a running total that adds the day's volume on up closes and
subtracts it on down closes. The idea is that volume flow precedes price.

**The crypto-specific caveat is severe.** OBV inherits whatever volume series feeds
it, and aggregator volume for small caps is contaminated by wash trading. For any
token where volume-to-market-cap is implausibly high, OBV is measuring fabricated
activity and should be disregarded entirely.

Where the volume series is trustworthy, the useful reading is again divergence:
price flat or falling while OBV rises suggests accumulation that price hasn't
reflected yet. The absolute OBV number is meaningless — only its slope and its
relationship to price carry information.

Prefer computing OBV from DEX volume where the token is DEX-native, since on-chain
volume cannot be fabricated as cheaply.

## Whale wallet movement

The highest-value class on this list, and by a wide margin the easiest to misread.
Most public "whale alert" commentary carries close to zero signal, because a large
transfer is reported without any of the context that determines its meaning.

**What a large transfer does not tell you:**

- An exchange inflow is not necessarily selling. It may be market-maker inventory,
  custody migration, collateral posting, or an OTC settlement leg.
- Labeled wallets are frequently mislabeled, and labels propagate between data
  providers uncorrected.
- A transfer out of a vesting contract is unlock mechanics on a schedule, not a
  discretionary decision — it tells you the calendar worked.
- For a LayerZero OFT token like BASED, cross-chain movement looks like a flow but
  is the same holder on a different chain.
- For low-float tokens, the largest wallets are team, treasury and market makers.
  "Whale accumulation" often just means the market maker rebalanced.

**What carries signal:**

- **Exchange netflow trend** over days or weeks, not single events. Sustained net
  outflow suggests holders moving to self-custody; sustained inflow suggests supply
  positioning to sell.
- **Holder concentration change** — is the top-10 or top-100 share rising or
  falling over time? Direction matters more than level, since every token is
  concentrated at launch.
- **New address growth** alongside rising concentration is distribution to a
  widening base; concentration rising while addresses stall is the opposite.
- **Vesting contract outflows relative to the published schedule** — tokens moving
  ahead of schedule, or to venues rather than to holders, is worth flagging.
- **Wallets with a track record**, where a provider has established one. Treat the
  label as a hypothesis, not a fact.

**Horizon:** whale flows are not a 4h input. Detection lags, interpretation takes
longer, and the position being built may take weeks to express. Useful from 1d
outward, strongest at 1w and 1m.

## Weighting

An honest ranking of what these contribute, strongest first:

1. Volume factor and on-chain flow trends — different input class from price,
   hardest to fake at the trend level, informative across most horizons.
2. Divergences between price and any oscillator — more informative than the
   oscillator's absolute level.
3. Funding and open interest — genuinely independent, though only at short horizons.
4. Absolute oscillator levels — weak alone, and actively misleading in trends.
5. MACD crossovers — lagging, whipsaw-prone, weak in isolation.
6. Stochastic in isolation — highest false-positive rate of the set.
7. Single large wallet transfers reported without context — near zero signal, high
   noise. Do not report these as findings.

## Applying this

When a user supplies indicator readings, do three things before assessing:

1. **Collapse them into classes.** Report how many independent classes are actually
   represented. If it's one, say so — the user may believe they have three
   confirmations.
2. **Check the horizon routing table.** If the readings don't speak to the horizon
   being asked about, say that plainly and gather what does.
3. **Verify against volume.** A price-derived signal on unconvincing volume is not
   a signal.

Then assess normally, per `assessment.md`.
