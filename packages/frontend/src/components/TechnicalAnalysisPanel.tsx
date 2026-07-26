import { useEffect, useMemo, useState, type ReactElement } from "react";
import {
  Bar,
  Brush,
  CartesianGrid,
  Cell,
  ComposedChart,
  Legend,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { ChartInterval, TokenAnalysisResult, TrendState } from "@crypto-analyzer/shared";
import { CandlestickChart, type ZoomRange } from "./CandlestickChart";

const tickStyle = { fontSize: 11, fill: "var(--text-muted)" };
const legendStyle = { fontSize: 12, color: "var(--text-muted)" };
const tooltipStyle = {
  backgroundColor: "var(--chart-surface)",
  border: "1px solid var(--gridline)",
  borderRadius: 6,
  color: "var(--text-muted)",
};

const INTERVALS: ChartInterval[] = ["15m", "1h", "2h", "4h", "1d", "2d", "3d", "1w", "1M"];
const SUB_DAILY: Set<ChartInterval> = new Set(["15m", "1h", "2h", "4h"]);

function formatDate(iso: string, interval: ChartInterval): string {
  const d = new Date(iso);
  if (SUB_DAILY.has(interval)) {
    return d.toLocaleString(undefined, { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
  }
  if (interval === "1M") {
    return d.toLocaleDateString(undefined, { month: "short", year: "numeric" });
  }
  return d.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

export function TechnicalAnalysisPanel({
  analysis,
  interval,
  onIntervalChange,
}: {
  analysis: TokenAnalysisResult;
  interval: ChartInterval;
  onIntervalChange: (interval: ChartInterval) => void;
}) {
  const [chartType, setChartType] = useState<"candle" | "line">("candle");
  const [zoomRange, setZoomRange] = useState<ZoomRange | null>(null);

  const data = useMemo(() => {
    if (!analysis.available) return [];
    return analysis.points.map((p) => ({ ...p, date: formatDate(p.timestamp, interval) }));
  }, [analysis, interval]);

  // Zoom lives on the Price panel's own Brush (drag the handles to zoom,
  // drag the middle to pan -- the same interaction DexScreener/MEXC use,
  // just via a visible mini-map instead of scroll-wheel). Reset it whenever
  // the underlying series changes so a stale index range from a previous,
  // differently-sized dataset can't slice out of bounds.
  useEffect(() => {
    setZoomRange(null);
  }, [data]);

  const visibleData = useMemo(() => {
    if (!zoomRange || zoomRange.startIndex == null || zoomRange.endIndex == null) return data;
    return data.slice(zoomRange.startIndex, zoomRange.endIndex + 1);
  }, [data, zoomRange]);

  const intervalPicker = (
    <div className="flex flex-wrap gap-0.5 rounded-md border border-neutral-200 p-0.5 dark:border-neutral-800">
      {INTERVALS.map((iv) => (
        <button
          key={iv}
          onClick={() => onIntervalChange(iv)}
          className={`rounded px-2 py-0.5 text-xs font-medium ${
            interval === iv
              ? "bg-neutral-900 text-white dark:bg-neutral-100 dark:text-neutral-900"
              : "text-neutral-500 hover:bg-neutral-100 dark:text-neutral-400 dark:hover:bg-neutral-800"
          }`}
        >
          {iv}
        </button>
      ))}
    </div>
  );

  if (!analysis.available) {
    return (
      <section className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
        <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
          <h2 className="text-sm font-semibold text-neutral-700 dark:text-neutral-200">Technical analysis</h2>
          {intervalPicker}
        </div>
        <p className="text-sm text-neutral-500 dark:text-neutral-400">{analysis.reason}</p>
      </section>
    );
  }

  return (
    <section className="space-y-4">
      <div className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
        <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
          <h2 className="text-sm font-semibold text-neutral-700 dark:text-neutral-200">Technical analysis</h2>
          <TrendBadge state={analysis.trend.state} basis={analysis.trend.basis} />
        </div>
        <p className="mb-3 text-xs text-neutral-500 dark:text-neutral-400">
          A mechanical read of current indicator state from {data.length} {interval} candles — not a price
          forecast. No system can reliably predict future prices; this only describes what the data shows right
          now.
        </p>

        {analysis.divergences.length > 0 && (
          <ul className="space-y-1 text-xs">
            {analysis.divergences.map((d, i) => {
              const color = d.type === "bullish" ? "var(--delta-up)" : "var(--delta-down)";
              return (
                <li key={i} className="flex flex-wrap items-center gap-1.5">
                  <span
                    className="rounded-full px-1.5 py-0.5 font-medium capitalize"
                    style={{ color, backgroundColor: `color-mix(in srgb, ${color} 14%, transparent)` }}
                  >
                    {d.type} {d.indicator} divergence
                  </span>
                  <span className="text-neutral-500 dark:text-neutral-400">
                    {formatDate(d.fromDate, interval)} → {formatDate(d.toDate, interval)}
                  </span>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      <div className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
        <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
          <h3 className="text-xs font-semibold uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
            Price
          </h3>
          <div className="flex flex-wrap items-center gap-3">
            {intervalPicker}
            <div className="flex gap-0.5 rounded-md border border-neutral-200 p-0.5 dark:border-neutral-800">
              {(["candle", "line"] as const).map((type) => (
                <button
                  key={type}
                  onClick={() => setChartType(type)}
                  className={`rounded px-2 py-0.5 text-xs font-medium capitalize ${
                    chartType === type
                      ? "bg-neutral-900 text-white dark:bg-neutral-100 dark:text-neutral-900"
                      : "text-neutral-500 hover:bg-neutral-100 dark:text-neutral-400 dark:hover:bg-neutral-800"
                  }`}
                >
                  {type}
                </button>
              ))}
            </div>
          </div>
        </div>
        <p className="mb-2 text-xs text-neutral-400">Drag the handles below the chart to zoom, drag the middle to pan.</p>
        <div className="h-64">
          <ResponsiveContainer width="100%" height="100%">
            {chartType === "candle" ? (
              <CandlestickChart data={data} onZoomChange={setZoomRange} />
            ) : (
              <LineChart data={data} margin={{ top: 4, right: 8, bottom: 4, left: 8 }}>
                <CartesianGrid stroke="var(--gridline)" vertical={false} />
                <XAxis dataKey="date" tick={tickStyle} stroke="var(--gridline)" minTickGap={24} />
                <YAxis tick={tickStyle} stroke="var(--gridline)" width={64} domain={["auto", "auto"]} />
                <Tooltip contentStyle={tooltipStyle} />
                <Line
                  type="monotone"
                  dataKey="close"
                  stroke="var(--series-1)"
                  strokeWidth={2}
                  dot={false}
                  isAnimationActive={false}
                />
                <Brush
                  dataKey="date"
                  height={18}
                  stroke="var(--gridline)"
                  fill="var(--chart-surface)"
                  travellerWidth={8}
                  tickFormatter={() => ""}
                  onChange={setZoomRange}
                />
              </LineChart>
            )}
          </ResponsiveContainer>
        </div>
      </div>

      <ChartCard title="Volume">
        <LineChart data={visibleData} margin={{ top: 4, right: 8, bottom: 4, left: 8 }}>
          <CartesianGrid stroke="var(--gridline)" vertical={false} />
          <XAxis dataKey="date" tick={tickStyle} stroke="var(--gridline)" minTickGap={24} />
          <YAxis tick={tickStyle} stroke="var(--gridline)" width={64} />
          <Tooltip contentStyle={tooltipStyle} />
          <Line
            type="monotone"
            dataKey="volume"
            stroke="var(--series-2)"
            strokeWidth={2}
            dot={false}
            isAnimationActive={false}
          />
        </LineChart>
      </ChartCard>

      <ChartCard title="RSI (14)">
        <LineChart data={visibleData} margin={{ top: 4, right: 8, bottom: 4, left: 8 }}>
          <CartesianGrid stroke="var(--gridline)" vertical={false} />
          <XAxis dataKey="date" tick={tickStyle} stroke="var(--gridline)" minTickGap={24} />
          <YAxis domain={[0, 100]} tick={tickStyle} stroke="var(--gridline)" width={40} />
          <ReferenceLine y={70} stroke="var(--status-critical)" strokeDasharray="4 4" />
          <ReferenceLine y={30} stroke="var(--status-good)" strokeDasharray="4 4" />
          <Tooltip contentStyle={tooltipStyle} />
          <Line
            type="monotone"
            dataKey="rsi"
            stroke="var(--series-1)"
            strokeWidth={2}
            dot={false}
            isAnimationActive={false}
            connectNulls
          />
        </LineChart>
      </ChartCard>

      <ChartCard title="Stochastic RSI" withLegend>
        <LineChart data={visibleData} margin={{ top: 4, right: 8, bottom: 4, left: 8 }}>
          <CartesianGrid stroke="var(--gridline)" vertical={false} />
          <XAxis dataKey="date" tick={tickStyle} stroke="var(--gridline)" minTickGap={24} />
          <YAxis domain={[0, 100]} tick={tickStyle} stroke="var(--gridline)" width={40} />
          <ReferenceLine y={80} stroke="var(--status-critical)" strokeDasharray="4 4" />
          <ReferenceLine y={20} stroke="var(--status-good)" strokeDasharray="4 4" />
          <Tooltip contentStyle={tooltipStyle} />
          <Legend wrapperStyle={legendStyle} />
          <Line
            type="monotone"
            dataKey="stochRsiK"
            name="%K"
            stroke="var(--series-1)"
            strokeWidth={2}
            dot={false}
            isAnimationActive={false}
            connectNulls
          />
          <Line
            type="monotone"
            dataKey="stochRsiD"
            name="%D"
            stroke="var(--series-2)"
            strokeWidth={2}
            dot={false}
            isAnimationActive={false}
            connectNulls
          />
        </LineChart>
      </ChartCard>

      <ChartCard title="MACD (12, 26, 9)" withLegend>
        <ComposedChart data={visibleData} margin={{ top: 4, right: 8, bottom: 4, left: 8 }}>
          <CartesianGrid stroke="var(--gridline)" vertical={false} />
          <XAxis dataKey="date" tick={tickStyle} stroke="var(--gridline)" minTickGap={24} />
          <YAxis tick={tickStyle} stroke="var(--gridline)" width={56} domain={["auto", "auto"]} />
          <Tooltip contentStyle={tooltipStyle} />
          <Legend wrapperStyle={legendStyle} />
          <Bar dataKey="macdHistogram" name="Histogram">
            {visibleData.map((d, i) => (
              <Cell key={i} fill={(d.macdHistogram ?? 0) >= 0 ? "var(--delta-up)" : "var(--delta-down)"} />
            ))}
          </Bar>
          <Line
            type="monotone"
            dataKey="macd"
            name="MACD"
            stroke="var(--series-1)"
            strokeWidth={2}
            dot={false}
            isAnimationActive={false}
            connectNulls
          />
          <Line
            type="monotone"
            dataKey="macdSignal"
            name="Signal"
            stroke="var(--series-2)"
            strokeWidth={2}
            dot={false}
            isAnimationActive={false}
            connectNulls
          />
        </ComposedChart>
      </ChartCard>

      <ChartCard title="OBV">
        <LineChart data={visibleData} margin={{ top: 4, right: 8, bottom: 4, left: 8 }}>
          <CartesianGrid stroke="var(--gridline)" vertical={false} />
          <XAxis dataKey="date" tick={tickStyle} stroke="var(--gridline)" minTickGap={24} />
          <YAxis tick={tickStyle} stroke="var(--gridline)" width={64} domain={["auto", "auto"]} />
          <Tooltip contentStyle={tooltipStyle} />
          <Line
            type="monotone"
            dataKey="obv"
            stroke="var(--series-3)"
            strokeWidth={2}
            dot={false}
            isAnimationActive={false}
          />
        </LineChart>
      </ChartCard>
    </section>
  );
}

function ChartCard({
  title,
  children,
  withLegend,
}: {
  title: string;
  children: ReactElement;
  withLegend?: boolean;
}) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
      <h3 className="mb-2 text-xs font-semibold uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
        {title}
      </h3>
      <div className={withLegend ? "h-52" : "h-40"}>
        <ResponsiveContainer width="100%" height="100%">
          {children}
        </ResponsiveContainer>
      </div>
    </div>
  );
}

function TrendBadge({ state, basis }: { state: TrendState; basis: string }) {
  const color =
    state === "Uptrend" ? "var(--delta-up)" : state === "Downtrend" ? "var(--delta-down)" : "var(--status-muted)";
  return (
    <span
      title={basis}
      className="cursor-help rounded-full px-2 py-0.5 text-xs font-medium"
      style={{ color, backgroundColor: `color-mix(in srgb, ${color} 14%, transparent)` }}
    >
      {state}
    </span>
  );
}
