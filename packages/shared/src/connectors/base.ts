// Shared GET-with-backoff helper. Free tiers rate-limit aggressively; be patient.
// Mirrors the retry/backoff behaviour of Skills/fetch.py's get().

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export interface FetchJsonOptions {
  retries?: number;
  headers?: Record<string, string>;
}

export type FetchFailureReason = "rate_limited" | "http_error" | "network_error";

export type FetchResult<T> =
  | { ok: true; data: T }
  | { ok: false; reason: FetchFailureReason; status?: number };

// Most callers just want T | null (see fetchJson below) -- but a caller that
// needs to tell a real absence of data apart from "we got rate-limited and
// gave up" (a very different, transient failure) can call this directly for
// the reason instead of a flattened null.
export async function fetchJsonWithReason<T = unknown>(
  url: string,
  options: FetchJsonOptions = {}
): Promise<FetchResult<T>> {
  const { retries = 4, headers = {} } = options;
  // Setting User-Agent from a browser turns every request into a CORS
  // preflight (it isn't a safelisted header) -- harmless for most of these
  // APIs, but confirmed live that data-api.binance.vision's OPTIONS handler
  // rejects the preflight outright (403) regardless of which header
  // triggers it, which would silently block every Binance price fetch from
  // the standalone frontend. Skip it in a browser so the request stays
  // "simple" and needs no preflight at all; keep it for the Node backend,
  // where there's no CORS concept and it's just polite API etiquette.
  // Checked via a cast (not a bare `typeof window` reference) so this
  // compiles under the backend's Node-only lib config too, which has no
  // ambient `window` type at all -- this file is built by both tsconfigs.
  const isBrowser = typeof (globalThis as Record<string, unknown>).window !== "undefined";
  const finalHeaders = {
    Accept: "application/json",
    ...(isBrowser ? {} : { "User-Agent": "crypto-analyzer/0.1" }),
    ...headers,
  };

  let last: FetchResult<T> = { ok: false, reason: "network_error" };
  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const res = await fetch(url, { headers: finalHeaders });
      if (res.status === 429) {
        last = { ok: false, reason: "rate_limited", status: 429 };
        const wait = Math.min(2 ** (attempt + 2) * 1000, 10_000);
        console.warn(`  rate limited, waiting ${wait}ms: ${url}`);
        await sleep(wait);
        continue;
      }
      if (!res.ok) {
        console.warn(`  HTTP ${res.status} on ${url}`);
        return { ok: false, reason: "http_error", status: res.status };
      }
      return { ok: true, data: (await res.json()) as T };
    } catch (err) {
      const e = err as Error;
      console.warn(`  ${e.name} on ${url}: ${e.message}`);
      last = { ok: false, reason: "network_error" };
      await sleep(2000);
    }
  }
  return last;
}

export async function fetchJson<T = unknown>(
  url: string,
  options: FetchJsonOptions = {}
): Promise<T | null> {
  const result = await fetchJsonWithReason<T>(url, options);
  return result.ok ? result.data : null;
}
