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
  const finalHeaders = {
    Accept: "application/json",
    "User-Agent": "crypto-analyzer/0.1",
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
