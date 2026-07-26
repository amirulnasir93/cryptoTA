import { Bar, Brush, CartesianGrid, ComposedChart, Tooltip, XAxis, YAxis } from "recharts";

// Recharts' own BrushStartEndIndex type isn't actually exported from its
// package -- declared locally in their .d.ts but never re-exported -- so we
// define an equivalent shape here rather than depend on an internal path.
export interface ZoomRange {
  startIndex?: number;
  endIndex?: number;
}

export interface CandlePoint {
  date: string;
  open: number;
  high: number;
  low: number;
  close: number;
}

const tickStyle = { fontSize: 11, fill: "var(--text-muted)" };

interface CandleShapeProps {
  x?: number;
  y?: number;
  width?: number;
  height?: number;
  payload?: CandlePoint;
}

// A real candlestick, drawn from a single range-valued Bar (dataKey -> [low,
// high]) rather than two separate Bar elements. Two unstacked Bars without a
// shared stackId get positioned *side by side* by Recharts (each claiming
// half the category slot), not overlaid -- that was the original bug here.
// A single custom shape avoids that entirely, and also sidesteps needing a
// fixed pixel barSize (which overflowed the chart at high candle counts,
// e.g. 168 candles on a 1h view): Recharts hands this shape the exact
// per-category band width it already computed, so it always fits.
// Recharts' Bar["shape"] type is deliberately loose (props: unknown), since
// it's shared across every bar-shaped chart type -- narrow it ourselves.
function CandleShape(props: unknown) {
  const { x, y, width, height, payload } = props as CandleShapeProps;
  if (x == null || y == null || width == null || height == null || !payload) return <g />;

  const { open, high, low, close } = payload;
  const isUp = close >= open;
  const color = isUp ? "var(--delta-up)" : "var(--delta-down)";

  // Recharts only gives this shape the pixel position it computed for the
  // bar's own [low, high] range (y = pixel top at `high`, height = pixel span
  // down to `low`) -- no direct access to the y-scale. Open/close's pixel
  // positions are recovered by linear interpolation within that known span.
  const range = high - low;
  const toPixelY = (value: number) => (range === 0 ? y : y + height * ((high - value) / range));

  const bodyTop = toPixelY(Math.max(open, close));
  const bodyBottom = toPixelY(Math.min(open, close));
  const bodyHeight = Math.max(bodyBottom - bodyTop, 1); // keep a doji visible as a hairline, not nothing

  const centerX = x + width / 2;
  const bodyWidth = Math.max(Math.min(width * 0.7, 10), 2);

  return (
    <g>
      <line x1={centerX} x2={centerX} y1={y} y2={y + height} stroke={color} strokeWidth={1} />
      <rect x={centerX - bodyWidth / 2} y={bodyTop} width={bodyWidth} height={bodyHeight} fill={color} />
    </g>
  );
}

// width/height must be accepted and forwarded explicitly: ResponsiveContainer
// sizes its content by cloning its *immediate* child with those props, and
// since this is a custom wrapper (not a raw recharts chart), that clone lands
// on CandlestickChart itself -- without forwarding them to ComposedChart, the
// chart would silently render at 0x0.
export function CandlestickChart({
  data,
  width,
  height,
  onZoomChange,
}: {
  data: CandlePoint[];
  width?: number;
  height?: number;
  onZoomChange?: (range: ZoomRange) => void;
}) {
  const chartData = data.map((d) => ({ ...d, wick: [d.low, d.high] as [number, number] }));

  return (
    <ComposedChart width={width} height={height} data={chartData} margin={{ top: 4, right: 8, bottom: 4, left: 8 }}>
      <CartesianGrid stroke="var(--gridline)" vertical={false} />
      <XAxis dataKey="date" tick={tickStyle} stroke="var(--gridline)" minTickGap={24} />
      <YAxis tick={tickStyle} stroke="var(--gridline)" width={64} domain={["auto", "auto"]} />
      <Tooltip content={<CandleTooltip />} />
      <Bar dataKey="wick" shape={CandleShape} isAnimationActive={false} />
      {onZoomChange && (
        <Brush
          dataKey="date"
          height={18}
          stroke="var(--gridline)"
          fill="var(--chart-surface)"
          travellerWidth={8}
          tickFormatter={() => ""}
          onChange={onZoomChange}
        />
      )}
    </ComposedChart>
  );
}

function CandleTooltip({
  active,
  payload,
}: {
  active?: boolean;
  payload?: { payload: CandlePoint }[];
}) {
  if (!active || !payload?.length) return null;
  const d = payload[0].payload;
  return (
    <div
      className="rounded-md border px-2.5 py-1.5 text-xs"
      style={{
        backgroundColor: "var(--chart-surface)",
        borderColor: "var(--gridline)",
        color: "var(--text-muted)",
      }}
    >
      <div className="mb-1 font-medium text-neutral-700 dark:text-neutral-300">{d.date}</div>
      <div>Open: {d.open.toPrecision(6)}</div>
      <div>High: {d.high.toPrecision(6)}</div>
      <div>Low: {d.low.toPrecision(6)}</div>
      <div>Close: {d.close.toPrecision(6)}</div>
    </div>
  );
}
