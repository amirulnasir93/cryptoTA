import { describe, expect, it } from "vitest";
import {
  decideSyncAction,
  formatLabelList,
  hashRowFields,
  parseLabelList,
} from "../src/jobs/syncDecision.js";

describe("decideSyncAction", () => {
  it("no-ops when neither side changed", () => {
    expect(decideSyncAction("a", "a", "a")).toBe("noop");
  });

  it("pushes local -> sheet when only local changed", () => {
    expect(decideSyncAction("b", "a", "a")).toBe("push");
  });

  it("pulls sheet -> local when only the sheet changed", () => {
    expect(decideSyncAction("a", "b", "a")).toBe("pull");
  });

  it("converges without conflict when both sides land on the same value", () => {
    expect(decideSyncAction("b", "b", "a")).toBe("converge");
  });

  it("flags a true conflict when both changed to different values", () => {
    expect(decideSyncAction("b", "c", "a")).toBe("conflict");
  });
});

describe("hashRowFields", () => {
  it("is stable regardless of key insertion order", () => {
    const h1 = hashRowFields({ Ticker: "UNI", Notes: "x" });
    const h2 = hashRowFields({ Notes: "x", Ticker: "UNI" });
    expect(h1).toBe(h2);
  });

  it("changes when any field value changes", () => {
    const h1 = hashRowFields({ Ticker: "UNI", Notes: "x" });
    const h2 = hashRowFields({ Ticker: "UNI", Notes: "y" });
    expect(h1).not.toBe(h2);
  });
});

describe("label list round-trip", () => {
  it("canonicalizes ordering so cosmetic reordering doesn't look like a change", () => {
    const a = formatLabelList(parseLabelList("Degen, Core"));
    const b = formatLabelList(parseLabelList("Core,Degen"));
    expect(a).toBe(b);
  });
});
