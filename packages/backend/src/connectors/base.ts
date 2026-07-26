// Shared GET-with-backoff helper. Free tiers rate-limit aggressively; be patient.
// Mirrors the retry/backoff behaviour of Skills/fetch.py's get().

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export interface FetchJsonOptions {
  retries?: number;
  headers?: Record<string, string>;
}

export async function fetchJson<T = unknown>(
  url: string,
  options: FetchJsonOptions = {}
): Promise<T | null> {
  const { retries = 3, headers = {} } = options;
  const finalHeaders = {
    Accept: "application/json",
    "User-Agent": "crypto-analyzer/0.1",
    ...headers,
  };

  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const res = await fetch(url, { headers: finalHeaders });
      if (res.status === 429) {
        const wait = 2 ** (attempt + 2) * 1000;
        console.warn(`  rate limited, waiting ${wait}ms: ${url}`);
        await sleep(wait);
        continue;
      }
      if (!res.ok) {
        console.warn(`  HTTP ${res.status} on ${url}`);
        return null;
      }
      return (await res.json()) as T;
    } catch (err) {
      const e = err as Error;
      console.warn(`  ${e.name} on ${url}: ${e.message}`);
      await sleep(2000);
    }
  }
  return null;
}
