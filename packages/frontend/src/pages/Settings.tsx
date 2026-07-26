import { useConflicts } from "../api/queries";
import { SyncControls } from "../components/SyncControls";

export function Settings() {
  const { data: conflicts, isLoading } = useConflicts();

  return (
    <div className="max-w-2xl space-y-6">
      <div>
        <h1 className="mb-1 text-lg font-semibold">Settings &amp; sync</h1>
        <p className="text-sm text-neutral-500 dark:text-neutral-400">
          Manual price refresh and two-way Google Sheets sync live here.
        </p>
      </div>

      <section className="space-y-2">
        <h2 className="text-sm font-semibold text-neutral-700 dark:text-neutral-200">Refresh &amp; sync</h2>
        <SyncControls />
        <p className="text-xs text-neutral-500 dark:text-neutral-400">
          The secret is your backend's <code className="rounded bg-neutral-100 px-1 dark:bg-neutral-800">REFRESH_SECRET</code>{" "}
          from <code className="rounded bg-neutral-100 px-1 dark:bg-neutral-800">packages/backend/.env</code> — it's kept
          in this browser's local storage only, not sent anywhere else.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-sm font-semibold text-neutral-700 dark:text-neutral-200">Google Sheets setup</h2>
        <p className="text-sm text-neutral-600 dark:text-neutral-300">
          Two-way sync needs a one-time, manual Google Cloud setup (a service account, not a login flow) before
          "Sync with Sheets" above will do anything besides report "not configured yet":
        </p>
        <ol className="list-inside list-decimal space-y-1 text-sm text-neutral-600 dark:text-neutral-300">
          <li>Create a Google Cloud project and enable the Google Sheets API.</li>
          <li>Create a service account and download its JSON key.</li>
          <li>
            Save the key as{" "}
            <code className="rounded bg-neutral-100 px-1 dark:bg-neutral-800">
              packages/backend/secrets/service-account.json
            </code>
            .
          </li>
          <li>Create a Google Sheet and share it with the service account's email as Editor.</li>
          <li>
            Set <code className="rounded bg-neutral-100 px-1 dark:bg-neutral-800">GOOGLE_SHEET_ID</code> in{" "}
            <code className="rounded bg-neutral-100 px-1 dark:bg-neutral-800">packages/backend/.env</code> to that
            Sheet's ID, then restart the backend.
          </li>
        </ol>
        <p className="text-xs text-neutral-500 dark:text-neutral-400">
          Full walkthrough: <code className="rounded bg-neutral-100 px-1 dark:bg-neutral-800">docs/SHEETS_SETUP.md</code>{" "}
          in the repo. A ready-to-import CSV template matching your current watchlist can be generated with{" "}
          <code className="rounded bg-neutral-100 px-1 dark:bg-neutral-800">
            npm run export-sheet-template --workspace packages/backend
          </code>
          .
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-sm font-semibold text-neutral-700 dark:text-neutral-200">Auto-imported catalysts</h2>
        <p className="text-sm text-neutral-600 dark:text-neutral-300">
          "Sync catalysts" above pulls unlocks/listings/governance events from CoinMarketCal and matches them to
          your watchlist by ticker. Needs its own free API key first:
        </p>
        <ol className="list-inside list-decimal space-y-1 text-sm text-neutral-600 dark:text-neutral-300">
          <li>
            Sign up at{" "}
            <code className="rounded bg-neutral-100 px-1 dark:bg-neutral-800">coinmarketcal.com/en/api</code> and
            create an API key.
          </li>
          <li>
            Set{" "}
            <code className="rounded bg-neutral-100 px-1 dark:bg-neutral-800">COINMARKETCAL_API_KEY</code> in{" "}
            <code className="rounded bg-neutral-100 px-1 dark:bg-neutral-800">packages/backend/.env</code>, then
            restart the backend.
          </li>
        </ol>
        <p className="text-xs text-neutral-500 dark:text-neutral-400">
          Optional — without it, catalysts stay manually entered on each token's page, which works fine too. Full
          notes: <code className="rounded bg-neutral-100 px-1 dark:bg-neutral-800">docs/CATALYSTS_SETUP.md</code>.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-sm font-semibold text-neutral-700 dark:text-neutral-200">Conflict log</h2>
        <p className="text-xs text-neutral-500 dark:text-neutral-400">
          When the same field changes on both sides between syncs, the Sheet's edit wins and the overwritten
          app-side value is recorded here rather than silently dropped.
        </p>
        {isLoading ? (
          <p className="text-sm text-neutral-500">Loading…</p>
        ) : conflicts && conflicts.length > 0 ? (
          <div className="overflow-x-auto rounded-lg border border-neutral-200 dark:border-neutral-800">
            <table className="w-full text-sm">
              <thead className="bg-neutral-50 text-left text-xs uppercase tracking-wide text-neutral-500 dark:bg-neutral-900 dark:text-neutral-400">
                <tr>
                  <th className="px-3 py-2 font-medium">Token</th>
                  <th className="px-3 py-2 font-medium">Field</th>
                  <th className="px-3 py-2 font-medium">Local value (overwritten)</th>
                  <th className="px-3 py-2 font-medium">Sheet value (kept)</th>
                  <th className="px-3 py-2 font-medium">Detected</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100 dark:divide-neutral-800">
                {conflicts.map((c) => (
                  <tr key={c.id}>
                    <td className="px-3 py-2 font-medium">{c.ticker}</td>
                    <td className="px-3 py-2">{c.field}</td>
                    <td className="px-3 py-2 text-neutral-500 dark:text-neutral-400">{c.localValue || "—"}</td>
                    <td className="px-3 py-2">{c.sheetValue || "—"}</td>
                    <td className="px-3 py-2 text-neutral-500 dark:text-neutral-400">
                      {new Date(c.detectedAt).toLocaleString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="text-sm text-neutral-400">No conflicts recorded.</p>
        )}
      </section>
    </div>
  );
}
