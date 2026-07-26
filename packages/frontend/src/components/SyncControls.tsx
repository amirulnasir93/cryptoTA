import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { api } from "../api/client";
import { useRefreshSecret } from "../hooks/useRefreshSecret";

export function SyncControls() {
  const [secret, setSecret] = useRefreshSecret();
  const [status, setStatus] = useState<string | null>(null);
  const [busy, setBusy] = useState<"refresh" | "sync" | "catalysts" | null>(null);
  const qc = useQueryClient();

  async function handleRefresh() {
    setBusy("refresh");
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
      setBusy(null);
    }
  }

  async function handleSync() {
    setBusy("sync");
    setStatus(null);
    try {
      const result = await api.runSheetSync(secret);
      if (result.skipped) {
        setStatus(result.skipped);
      } else {
        setStatus(
          `Sync done — pushed ${result.pushed.length}, pulled ${result.pulled.length}, created ${result.created.length}, ${result.conflicts.length} conflict(s).`
        );
      }
      qc.invalidateQueries({ queryKey: ["tokens"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
      qc.invalidateQueries({ queryKey: ["conflicts"] });
    } catch (err) {
      setStatus(err instanceof Error ? err.message : "Sync failed.");
    } finally {
      setBusy(null);
    }
  }

  async function handleCatalystSync() {
    setBusy("catalysts");
    setStatus(null);
    try {
      const result = await api.syncCoinMarketCal(secret);
      if (result.skipped) {
        setStatus(result.skipped);
      } else {
        setStatus(
          `Scanned ${result.eventsScanned} events, imported ${result.created.length} new catalyst(s)` +
            (result.skippedCollisionRisk.length
              ? `, flagged ${result.skippedCollisionRisk.length} for manual review (ticker collision risk).`
              : ".")
        );
      }
      qc.invalidateQueries({ queryKey: ["tokens"] });
      qc.invalidateQueries({ queryKey: ["token"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    } catch (err) {
      setStatus(err instanceof Error ? err.message : "Catalyst sync failed.");
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3 text-sm dark:border-neutral-800 dark:bg-neutral-900">
      <div className="flex flex-wrap items-center gap-2">
        <input
          type="password"
          value={secret}
          onChange={(e) => setSecret(e.target.value)}
          placeholder="REFRESH_SECRET (from backend .env)"
          className="min-w-[14rem] flex-1 rounded-md border border-neutral-200 bg-white px-2 py-1.5 text-neutral-900 dark:border-neutral-800 dark:bg-neutral-950 dark:text-neutral-100"
        />
        <button
          onClick={handleRefresh}
          disabled={!secret || busy !== null}
          className="rounded-md border border-neutral-300 px-3 py-1.5 font-medium text-neutral-900 disabled:opacity-50 dark:border-neutral-700 dark:text-neutral-100"
        >
          {busy === "refresh" ? "Refreshing…" : "Refresh prices"}
        </button>
        <button
          onClick={handleSync}
          disabled={!secret || busy !== null}
          className="rounded-md bg-neutral-900 px-3 py-1.5 font-medium text-white disabled:opacity-50 dark:bg-neutral-100 dark:text-neutral-900"
        >
          {busy === "sync" ? "Syncing…" : "Sync with Sheets"}
        </button>
        <button
          onClick={handleCatalystSync}
          disabled={!secret || busy !== null}
          className="rounded-md border border-neutral-300 px-3 py-1.5 font-medium text-neutral-900 disabled:opacity-50 dark:border-neutral-700 dark:text-neutral-100"
        >
          {busy === "catalysts" ? "Syncing…" : "Sync catalysts"}
        </button>
      </div>
      {status && <p className="mt-2 text-xs text-neutral-500 dark:text-neutral-400">{status}</p>}
    </div>
  );
}
