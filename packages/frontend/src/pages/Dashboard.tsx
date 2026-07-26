import { useDashboard } from "../api/queries";
import { StatTile } from "../components/StatTile";
import { ClusterExposureChart } from "../components/ClusterExposureChart";
import { TokenTable } from "../components/TokenTable";
import { DeltaText } from "../components/DeltaText";
import { RefreshButton } from "../components/RefreshButton";

export function Dashboard() {
  const { data, isLoading, error } = useDashboard();

  if (isLoading) return <p className="text-neutral-500">Loading dashboard…</p>;
  if (error || !data) {
    return <p style={{ color: "var(--delta-down)" }}>Failed to load dashboard.</p>;
  }

  const { tokenCount, dataQualityCounts, clusterExposure, upcomingCatalysts, movers, tokens } = data;

  return (
    <div className="space-y-6">
      <RefreshButton />

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <StatTile label="Watchlist" value={tokenCount} sub="active tokens" />
        <StatTile
          label="Data quality"
          value={dataQualityCounts.Good}
          sub={`Good · ${dataQualityCounts.Degraded} degraded · ${dataQualityCounts.Poor} poor · ${dataQualityCounts.Unknown} unknown`}
        />
        <StatTile
          label="Top mover (24h)"
          value={movers[0]?.ticker ?? "—"}
          sub={movers[0] ? <DeltaText value={movers[0].change24hPct} /> : undefined}
        />
        <StatTile label="Clusters" value={clusterExposure.length} sub="correlated groups" />
      </div>

      <section className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
        <h2 className="mb-3 text-sm font-semibold text-neutral-700 dark:text-neutral-200">Cluster exposure</h2>
        <p className="mb-3 text-xs text-neutral-500 dark:text-neutral-400">
          Tokens in the same cluster don't move independently — several constructive names in one cluster is
          one idea, not several.
        </p>
        <ClusterExposureChart data={clusterExposure} />
      </section>

      {upcomingCatalysts.length > 0 && (
        <section className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
          <h2 className="mb-3 text-sm font-semibold text-neutral-700 dark:text-neutral-200">
            Upcoming catalysts (90 days)
          </h2>
          <ul className="space-y-1.5 text-sm">
            {upcomingCatalysts.map((c) => (
              <li key={c.id} className="flex items-center justify-between gap-4">
                <span>
                  <span className="font-medium">{c.ticker}</span> — {c.description}
                </span>
                <span className="shrink-0 text-neutral-500 dark:text-neutral-400">
                  {c.daysUntil === 0 ? "today" : `in ${c.daysUntil}d`}
                </span>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section>
        <h2 className="mb-3 text-sm font-semibold text-neutral-700 dark:text-neutral-200">Watchlist</h2>
        <TokenTable tokens={tokens} />
      </section>
    </div>
  );
}
