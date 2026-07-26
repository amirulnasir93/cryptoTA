import { Bar, BarChart, CartesianGrid, Cell, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { ClusterExposure } from "@crypto-analyzer/shared";

// Fixed categorical order, never cycled/reassigned by rank. Anything past the
// 8 validated slots folds into "Other" rather than generating a 9th hue.
const SERIES_COLORS = [
  "var(--series-1)",
  "var(--series-2)",
  "var(--series-3)",
  "var(--series-4)",
  "var(--series-5)",
  "var(--series-6)",
  "var(--series-7)",
  "var(--series-8)",
];

export function ClusterExposureChart({ data }: { data: ClusterExposure[] }) {
  const sorted = [...data].sort((a, b) => b.tokenCount - a.tokenCount);
  const top = sorted.slice(0, 8);
  const rest = sorted.slice(8);
  const chartData =
    rest.length > 0
      ? [
          ...top,
          {
            cluster: "Other",
            tokenCount: rest.reduce((sum, r) => sum + r.tokenCount, 0),
            tickers: rest.flatMap((r) => r.tickers),
          },
        ]
      : top;

  return (
    <div>
      <div className="h-64 w-full">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={chartData} layout="vertical" margin={{ left: 8, right: 16, top: 8, bottom: 8 }}>
            <CartesianGrid horizontal={false} stroke="var(--gridline)" />
            <XAxis
              type="number"
              allowDecimals={false}
              tick={{ fontSize: 12, fill: "var(--text-muted)" }}
              stroke="var(--gridline)"
            />
            <YAxis
              type="category"
              dataKey="cluster"
              width={150}
              tick={{ fontSize: 12, fill: "var(--text-muted)" }}
              stroke="var(--gridline)"
            />
            <Tooltip
              formatter={(value: number) => [`${value} token${value === 1 ? "" : "s"}`, "Exposure"]}
              contentStyle={{
                backgroundColor: "var(--chart-surface)",
                border: "1px solid var(--gridline)",
                borderRadius: 6,
                color: "var(--text-muted)",
              }}
            />
            <Bar dataKey="tokenCount" radius={[0, 4, 4, 0]}>
              {chartData.map((_, i) => (
                <Cell key={i} fill={SERIES_COLORS[i % SERIES_COLORS.length]} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Table-view fallback: every chart needs one, and it's the only place
          the actual ticker membership behind each bar is visible. */}
      <ul className="mt-3 space-y-1 text-xs text-neutral-500 dark:text-neutral-400">
        {chartData.map((c, i) => (
          <li key={c.cluster} className="flex gap-2">
            <span
              className="mt-0.5 h-2 w-2 shrink-0 rounded-full"
              style={{ backgroundColor: SERIES_COLORS[i % SERIES_COLORS.length] }}
            />
            <span>
              <span className="font-medium text-neutral-700 dark:text-neutral-300">{c.cluster}</span> —{" "}
              {c.tickers.join(", ")}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
