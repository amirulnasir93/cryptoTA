import { useState } from "react";
import { Link } from "react-router-dom";
import { isReady } from "../appConfig";
import { useRefreshPrices } from "../api/queries";

// No secret to enter anymore -- refreshing just means "fetch live prices for
// every active token right now," straight from this browser.
export function RefreshButton() {
  const refresh = useRefreshPrices();
  const [status, setStatus] = useState<string | null>(null);
  const ready = isReady();

  async function handleRefresh() {
    setStatus(null);
    try {
      const dashboard = await refresh.mutateAsync();
      setStatus(`Refreshed ${dashboard.tokenCount} tokens.`);
    } catch (err) {
      setStatus(err instanceof Error ? err.message : "Refresh failed.");
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-3">
      <button
        onClick={handleRefresh}
        disabled={!ready || refresh.isPending}
        className="rounded-md bg-neutral-900 px-3 py-1.5 text-sm font-medium text-white disabled:opacity-50 dark:bg-neutral-100 dark:text-neutral-900"
      >
        {refresh.isPending ? "Refreshing…" : "Refresh prices"}
      </button>
      {!ready && (
        <p className="text-xs text-neutral-500 dark:text-neutral-400">
          Finish setup on the{" "}
          <Link to="/settings" className="underline">
            Settings
          </Link>{" "}
          page first.
        </p>
      )}
      {status && <p className="text-xs text-neutral-500 dark:text-neutral-400">{status}</p>}
    </div>
  );
}
