import { describe, expect, it } from "vitest";
import { dataQualityFor, divergence, horizonsFor } from "../src/gating.js";

// Cases mirror the worked examples in Skills/SKILL.md's gating table and
// Skills/fetch.py's GATES thresholds, so a drift here should be caught here.

describe("divergence", () => {
  it("returns null with fewer than two valid prices", () => {
    expect(divergence([])).toBeNull();
    expect(divergence([100])).toBeNull();
    expect(divergence([100, null, undefined, 0, -5])).toBeNull();
  });

  it("computes (max-min)/min across valid prices", () => {
    expect(divergence([100, 110])).toBeCloseTo(0.1);
    expect(divergence([100, 105, 102])).toBeCloseTo(0.05);
  });
});

describe("horizonsFor", () => {
  it("<1% divergence allows every horizon", () => {
    const { allowed } = horizonsFor(0.005, 1_000_000);
    expect(allowed).toEqual(["4h_scalp", "1d_scalp", "1d_hold", "1w_hold", "1m_hold"]);
  });

  it("1-5% divergence excludes 4h scalp only", () => {
    const { allowed } = horizonsFor(0.03, 1_000_000);
    expect(allowed).toEqual(["1d_scalp", "1d_hold", "1w_hold", "1m_hold"]);
  });

  it("5-20% divergence excludes both scalps", () => {
    const { allowed } = horizonsFor(0.1, 1_000_000);
    expect(allowed).toEqual(["1d_hold", "1w_hold", "1m_hold"]);
  });

  it(">20% divergence allows only 1w/1m hold", () => {
    const { allowed } = horizonsFor(0.3, 1_000_000);
    expect(allowed).toEqual(["1w_hold", "1m_hold"]);
  });

  it("single-source (null divergence) stays conservative", () => {
    const { allowed, reason } = horizonsFor(null, 1_000_000);
    expect(allowed).toEqual(["1d_hold", "1w_hold", "1m_hold"]);
    expect(reason).toMatch(/single source only/);
  });

  it("thin liquidity strips both scalp horizons regardless of divergence", () => {
    const { allowed, reason } = horizonsFor(0.005, 50_000);
    expect(allowed).toEqual(["1d_hold", "1w_hold", "1m_hold"]);
    expect(reason).toMatch(/below liquidity floor/);
  });
});

describe("dataQualityFor", () => {
  it("maps divergence buckets to a single top-level badge", () => {
    expect(dataQualityFor(null)).toBeNull();
    expect(dataQualityFor(0.03)).toBe("Good");
    expect(dataQualityFor(0.1)).toBe("Degraded");
    expect(dataQualityFor(0.3)).toBe("Poor");
  });
});
