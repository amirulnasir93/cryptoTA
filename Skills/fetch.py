#!/usr/bin/env python3
"""Fetch a timestamped snapshot for a token watchlist from free data sources.

Pulls price/market data from CoinGecko and protocol metrics from DefiLlama, then
computes the cross-source divergence that gates which horizons are assessable.

Requires network access. Free tiers only -- no API key needed, though setting
COINGECKO_API_KEY raises the rate limit considerably.

Usage:
    python fetch.py --watchlist watchlist.csv --out snapshot.json
"""

import argparse
import csv
import json
import os
import sys
import time
from datetime import datetime, timezone
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

CG = "https://api.coingecko.com/api/v3"
LLAMA = "https://api.llama.fi"
DEXSCREENER = "https://api.dexscreener.com/latest/dex/tokens"

# Divergence thresholds gating each horizon. See references/timeframes.md.
GATES = [
    (0.01, ["4h_scalp", "1d_scalp", "1d_hold", "1w_hold", "1m_hold"]),
    (0.05, ["1d_scalp", "1d_hold", "1w_hold", "1m_hold"]),
    (0.20, ["1d_hold", "1w_hold", "1m_hold"]),
    (float("inf"), ["1w_hold", "1m_hold"]),
]

MIN_VOLUME_FOR_SHORT_HORIZONS = 100_000


def get(url, params=None, retries=3):
    """GET with backoff. Free tiers rate-limit aggressively; be patient."""
    if params:
        pairs = "&".join(f"{k}={v}" for k, v in params.items())
        url = f"{url}?{pairs}"
    headers = {"Accept": "application/json", "User-Agent": "watchlist-analyst/1.0"}
    key = os.environ.get("COINGECKO_API_KEY")
    if key and "coingecko" in url:
        headers["x-cg-demo-api-key"] = key

    for attempt in range(retries):
        try:
            with urlopen(Request(url, headers=headers), timeout=30) as r:
                return json.loads(r.read().decode())
        except HTTPError as e:
            if e.code == 429:
                wait = 2 ** (attempt + 2)
                print(f"  rate limited, waiting {wait}s", file=sys.stderr)
                time.sleep(wait)
                continue
            print(f"  HTTP {e.code} on {url}", file=sys.stderr)
            return None
        except (URLError, TimeoutError, json.JSONDecodeError) as e:
            print(f"  {type(e).__name__} on {url}", file=sys.stderr)
            time.sleep(2)
    return None


def load_watchlist(path):
    with open(path, newline="", encoding="utf-8") as f:
        return [row for row in csv.DictReader(f) if row.get("ticker")]


def fetch_market_data(ids):
    """Batch CoinGecko lookup. Batching matters: 13 tokens in one call, not 13."""
    if not ids:
        return {}
    data = get(
        f"{CG}/coins/markets",
        {
            "vs_currency": "usd",
            "ids": ",".join(ids),
            "price_change_percentage": "24h,7d,30d",
            "sparkline": "false",
        },
    )
    return {c["id"]: c for c in data} if data else {}


def fetch_dex_price(contract):
    """DexScreener as an independent second source. Keyless, no rate limit issues."""
    if not contract or not contract.startswith("0x"):
        return None
    data = get(f"{DEXSCREENER}/{contract}")
    if not data or not data.get("pairs"):
        return None
    pairs = sorted(
        data["pairs"],
        key=lambda p: float(p.get("liquidity", {}).get("usd") or 0),
        reverse=True,
    )
    top = pairs[0]
    try:
        return {
            "price": float(top["priceUsd"]),
            "liquidity_usd": float(top.get("liquidity", {}).get("usd") or 0),
            "venue": f"{top.get('dexId')} on {top.get('chainId')}",
            "pair_count": len(pairs),
        }
    except (KeyError, TypeError, ValueError):
        return None


def fetch_protocol(slug):
    if not slug:
        return None
    data = get(f"{LLAMA}/protocol/{slug}")
    if not data:
        return None
    tvl_series = data.get("tvl") or []
    current = tvl_series[-1]["totalLiquidityUSD"] if tvl_series else None
    change_30d = None
    if len(tvl_series) > 30 and current:
        prior = tvl_series[-31]["totalLiquidityUSD"]
        if prior:
            change_30d = (current - prior) / prior * 100
    return {
        "tvl": current,
        "tvl_change_30d_pct": change_30d,
        "chains": data.get("chains", []),
    }


def divergence(prices):
    prices = [p for p in prices if p and p > 0]
    if len(prices) < 2:
        return None
    return (max(prices) - min(prices)) / min(prices)


def horizons_for(div, volume):
    """Apply the gating table. Absent a second source, stay conservative."""
    if div is None:
        allowed = ["1d_hold", "1w_hold", "1m_hold"]
        reason = "single source only - short horizons need corroboration"
    else:
        allowed = next(h for threshold, h in GATES if div <= threshold)
        reason = f"cross-source divergence {div:.1%}"

    if volume is not None and volume < MIN_VOLUME_FOR_SHORT_HORIZONS:
        allowed = [h for h in allowed if h not in ("4h_scalp", "1d_scalp")]
        reason += f"; 24h volume ${volume:,.0f} below liquidity floor"

    return allowed, reason


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--watchlist", default="watchlist.csv")
    ap.add_argument("--out", default="snapshot.json")
    args = ap.parse_args()

    rows = load_watchlist(args.watchlist)
    print(f"Loaded {len(rows)} tokens from {args.watchlist}", file=sys.stderr)

    cg_ids = [r["coingecko_id"] for r in rows if r.get("coingecko_id")]
    print("Fetching market data...", file=sys.stderr)
    market = fetch_market_data(cg_ids)

    snapshot = {
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "tokens": {},
    }

    for row in rows:
        ticker = row["ticker"]
        print(f"  {ticker}", file=sys.stderr)
        m = market.get(row.get("coingecko_id"), {})
        dex = fetch_dex_price(row.get("contract"))
        proto = fetch_protocol(row.get("defillama_slug"))
        time.sleep(1.5)  # stay well inside free-tier limits

        cg_price = m.get("current_price")
        dex_price = dex["price"] if dex else None
        div = divergence([cg_price, dex_price])
        volume = m.get("total_volume")
        allowed, reason = horizons_for(div, volume)

        circ, total = m.get("circulating_supply"), m.get("total_supply")
        snapshot["tokens"][ticker] = {
            "project": row.get("project"),
            "chain": row.get("chain"),
            "cluster": row.get("cluster"),
            "notes": row.get("notes"),
            "price": {
                "coingecko": cg_price,
                "dexscreener": dex_price,
                "divergence": div,
            },
            "market_cap": m.get("market_cap"),
            "fdv": m.get("fully_diluted_valuation"),
            "volume_24h": volume,
            "volume_to_mcap": (
                volume / m["market_cap"]
                if volume and m.get("market_cap")
                else None
            ),
            "change_24h_pct": m.get("price_change_percentage_24h_in_currency"),
            "change_7d_pct": m.get("price_change_percentage_7d_in_currency"),
            "change_30d_pct": m.get("price_change_percentage_30d_in_currency"),
            "ath": m.get("ath"),
            "drawdown_from_ath_pct": m.get("ath_change_percentage"),
            "circulating_supply": circ,
            "total_supply": total,
            "float_pct": (circ / total * 100) if circ and total else None,
            "protocol": proto,
            "dex": dex,
            "assessable_horizons": allowed,
            "gating_reason": reason,
        }

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(snapshot, f, indent=2)

    print(f"\nWrote {args.out}", file=sys.stderr)
    gated = [t for t, d in snapshot["tokens"].items() if "4h_scalp" not in d["assessable_horizons"]]
    if gated:
        print(f"Short horizons unavailable for: {', '.join(gated)}", file=sys.stderr)


if __name__ == "__main__":
    main()
