import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { api } from "../api/client";
import { useRefreshSecret } from "../hooks/useRefreshSecret";

// Just the button, no secret input — for pages where that input would be
// clutter. Reads the secret saved once on the Settings page.
export function RefreshButton() {
  const [secret] = useRefreshSecret();
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<string | null>(null);
  const qc = useQueryClient();

  async function handleRefresh() {
    setBusy(true);
    setStatus(null);
    try {
      const result = await api.runRefresh(secret);
      setStatus(`Refreshed ${result.tokensProcessed} tokens (${result.status}).`);
      qc.invalidateQueries({ queryKey: ["tokens"] });
      qc.invalidateQueries({ queryKey: ["token"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    } catch (err) {
      setStatus(err instanceof Error ? err.message : "Refresh failed.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-3">
      <button
        onClick={handleRefresh}
        disabled={!secret || busy}
        className="rounded-md bg-neutral-900 px-3 py-1.5 text-sm font-medium text-white disabled:opacity-50 dark:bg-neutral-100 dark:text-neutral-900"
      >
        {busy ? "Refreshing…" : "Refresh prices"}
      </button>
      {!secret && (
        <p className="text-xs text-neutral-500 dark:text-neutral-400">
          Set your <code className="rounded bg-neutral-100 px-1 dark:bg-neutral-800">REFRESH_SECRET</code> on the{" "}
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
