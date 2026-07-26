import { useEffect, useLayoutEffect, useRef } from "react";
import {
  CandlestickSeries,
  ColorType,
  CrosshairMode,
  HistogramSeries,
  LineSeries,
  LineStyle,
  createChart,
  type IChartApi,
  type IPriceLine,
  type ISeriesApi,
  type UTCTimestamp,
} from "lightweight-charts";
import type { AnalysisPoint, KeyLevel, TrendChannel } from "@crypto-analyzer/shared";

// Recharts' own BrushStartEndIndex type isn't exported from its package, and
// this shape has nothing to do with Recharts anymore anyway -- it's just the
// [startIndex, endIndex] window the other (still-Recharts) indicator panels
// slice their own data by, kept in sync with whatever range is visible on
// this chart.
export interface ZoomRange {
  startIndex?: number;
  endIndex?: number;
}

function toUtcTimestamp(iso: string): UTCTimestamp {
  return Math.floor(new Date(iso).getTime() / 1000) as UTCTimestamp;
}

// Crypto prices span many orders of magnitude (a $60,000 BTC vs. a
// $0.0000004 memecoin) -- a fixed 2-decimal format would round the latter to
// "0.00" on every candle. Pick enough decimals to keep the price legible.
function pickPrecision(price: number): number {
  if (!Number.isFinite(price) || price <= 0) return 2;
  if (price >= 100) return 2;
  if (price >= 1) return 4;
  if (price >= 0.01) return 6;
  return 8;
}

// Canvas contexts can't resolve CSS `var(...)` strings -- lightweight-charts
// needs real color values, so the app's existing custom properties (already
// theme-aware via prefers-color-scheme, see index.css) are read once via
// getComputedStyle rather than duplicated as a second color source.
function readThemeColors() {
  const style = getComputedStyle(document.documentElement);
  const read = (name: string, fallback: string) => style.getPropertyValue(name).trim() || fallback;
  return {
    text: read("--text-muted", "#6b7280"),
    grid: read("--gridline", "#e1e0d9"),
    up: read("--delta-up", "#006300"),
    down: read("--delta-down", "#d03b3b"),
    series1: read("--series-1", "#2a78d6"),
    upperChannel: read("--series-4", "#eda100"),
    lowerChannel: read("--series-7", "#4a3aa7"),
  };
}

export function PriceChart({
  points,
  chartType,
  keyLevels,
  trendChannel,
  height = 256,
  onVisibleRangeChange,
}: {
  points: AnalysisPoint[];
  chartType: "candle" | "line";
  keyLevels: KeyLevel[];
  trendChannel: TrendChannel | null;
  height?: number;
  onVisibleRangeChange?: (range: ZoomRange) => void;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const volumeSeriesRef = useRef<ISeriesApi<"Histogram"> | null>(null);
  const mainSeriesRef = useRef<ISeriesApi<"Candlestick"> | ISeriesApi<"Line"> | null>(null);
  const upperChannelRef = useRef<ISeriesApi<"Line"> | null>(null);
  const lowerChannelRef = useRef<ISeriesApi<"Line"> | null>(null);
  const priceLinesRef = useRef<IPriceLine[]>([]);
  const onVisibleRangeChangeRef = useRef(onVisibleRangeChange);
  onVisibleRangeChangeRef.current = onVisibleRangeChange;

  // Chart + volume pane: created once. `autoSize` hands width/height tracking
  // to lightweight-charts' own internal ResizeObserver rather than rolling a
  // second one here.
  useLayoutEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    const colors = readThemeColors();

    const chart = createChart(container, {
      autoSize: true,
      layout: {
        background: { type: ColorType.Solid, color: "transparent" },
        textColor: colors.text,
        fontSize: 11,
      },
      grid: {
        vertLines: { visible: false },
        horzLines: { color: colors.grid },
      },
      crosshair: { mode: CrosshairMode.Normal },
      rightPriceScale: { borderColor: colors.grid },
      timeScale: { borderColor: colors.grid, timeVisible: true, secondsVisible: false },
    });
    chartRef.current = chart;

    // Volume rendered as a squat histogram along the bottom ~18% of the same
    // pane (an overlay price scale with a big top margin) -- the standard
    // lightweight-charts pattern for a secondary series sharing one chart,
    // rather than a whole separate synced chart just for volume.
    const volumeSeries = chart.addSeries(HistogramSeries, {
      priceFormat: { type: "volume" },
      priceScaleId: "volume",
      color: colors.grid,
      lastValueVisible: false,
      priceLineVisible: false,
    });
    volumeSeries.priceScale().applyOptions({ scaleMargins: { top: 0.82, bottom: 0 } });
    volumeSeriesRef.current = volumeSeries;

    const handleRangeChange = () => {
      const cb = onVisibleRangeChangeRef.current;
      if (!cb) return;
      const range = chart.timeScale().getVisibleLogicalRange();
      if (!range) return;
      cb({ startIndex: Math.max(0, Math.floor(range.from)), endIndex: Math.ceil(range.to) });
    };
    chart.timeScale().subscribeVisibleLogicalRangeChange(handleRangeChange);

    return () => {
      chart.timeScale().unsubscribeVisibleLogicalRangeChange(handleRangeChange);
      chart.remove();
      chartRef.current = null;
      volumeSeriesRef.current = null;
      mainSeriesRef.current = null;
      upperChannelRef.current = null;
      lowerChannelRef.current = null;
      priceLinesRef.current = [];
    };
  }, [height]);

  // Main series (candlestick or line): torn down and recreated on toggle,
  // since a series' type can't be changed in place once added.
  useEffect(() => {
    const chart = chartRef.current;
    if (!chart) return;

    if (mainSeriesRef.current) {
      chart.removeSeries(mainSeriesRef.current);
      mainSeriesRef.current = null;
    }
    if (upperChannelRef.current) {
      chart.removeSeries(upperChannelRef.current);
      upperChannelRef.current = null;
    }
    if (lowerChannelRef.current) {
      chart.removeSeries(lowerChannelRef.current);
      lowerChannelRef.current = null;
    }
    priceLinesRef.current = [];

    const colors = readThemeColors();
    const lastPrice = points[points.length - 1]?.close ?? 0;
    const precision = pickPrecision(lastPrice);
    const priceFormat = { type: "price" as const, precision, minMove: 1 / 10 ** precision };

    mainSeriesRef.current =
      chartType === "candle"
        ? chart.addSeries(CandlestickSeries, {
            upColor: colors.up,
            downColor: colors.down,
            borderVisible: false,
            wickUpColor: colors.up,
            wickDownColor: colors.down,
            priceFormat,
          })
        : chart.addSeries(LineSeries, {
            color: colors.series1,
            lineWidth: 2,
            priceFormat,
          });

    // Trend channel lines live on the main price scale so they're drawn to
    // the same scale as the candles/line, not the volume histogram's scale.
    upperChannelRef.current = chart.addSeries(LineSeries, {
      color: colors.upperChannel,
      lineWidth: 1,
      lineStyle: LineStyle.Dashed,
      lastValueVisible: false,
      priceLineVisible: false,
      crosshairMarkerVisible: false,
    });
    lowerChannelRef.current = chart.addSeries(LineSeries, {
      color: colors.lowerChannel,
      lineWidth: 1,
      lineStyle: LineStyle.Dashed,
      lastValueVisible: false,
      priceLineVisible: false,
      crosshairMarkerVisible: false,
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [chartType]);

  // Data: candles/line, volume, key-level price lines, and the trend-channel
  // projection, all re-set whenever the underlying analysis changes.
  useEffect(() => {
    const chart = chartRef.current;
    const mainSeries = mainSeriesRef.current;
    const volumeSeries = volumeSeriesRef.current;
    if (!chart || !mainSeries || !volumeSeries) return;
    const colors = readThemeColors();

    if (chartType === "candle") {
      (mainSeries as ISeriesApi<"Candlestick">).setData(
        points.map((p) => ({
          time: toUtcTimestamp(p.timestamp),
          open: p.open,
          high: p.high,
          low: p.low,
          close: p.close,
        }))
      );
    } else {
      (mainSeries as ISeriesApi<"Line">).setData(
        points.map((p) => ({ time: toUtcTimestamp(p.timestamp), value: p.close }))
      );
    }

    volumeSeries.setData(
      points.map((p, i) => ({
        time: toUtcTimestamp(p.timestamp),
        value: p.volume,
        color: i === 0 || p.close >= points[i - 1].close ? colors.up : colors.down,
      }))
    );

    for (const line of priceLinesRef.current) mainSeries.removePriceLine(line);
    priceLinesRef.current = keyLevels.map((level: KeyLevel) =>
      mainSeries.createPriceLine({
        price: level.price,
        color: level.type === "resistance" ? colors.down : colors.up,
        lineWidth: 1,
        lineStyle: LineStyle.Dotted,
        axisLabelVisible: true,
        title: `${level.type} (${level.touches}×)`,
      })
    );

    if (trendChannel && upperChannelRef.current && lowerChannelRef.current) {
      upperChannelRef.current.setData([
        { time: toUtcTimestamp(trendChannel.upper.fromTimestamp), value: trendChannel.upper.fromPrice },
        { time: toUtcTimestamp(trendChannel.upper.toTimestamp), value: trendChannel.upper.toPrice },
      ]);
      lowerChannelRef.current.setData([
        { time: toUtcTimestamp(trendChannel.lower.fromTimestamp), value: trendChannel.lower.fromPrice },
        { time: toUtcTimestamp(trendChannel.lower.toTimestamp), value: trendChannel.lower.toPrice },
      ]);
    } else {
      upperChannelRef.current?.setData([]);
      lowerChannelRef.current?.setData([]);
    }

    chart.timeScale().fitContent();
  }, [points, keyLevels, trendChannel, chartType]);

  return <div ref={containerRef} style={{ width: "100%", height }} />;
}
