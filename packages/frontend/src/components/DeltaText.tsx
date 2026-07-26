export function DeltaText({ value, suffix = "%" }: { value: number | null | undefined; suffix?: string }) {
  if (value === null || value === undefined || Number.isNaN(value)) {
    return <span className="text-neutral-400">—</span>;
  }
  const color = value >= 0 ? "var(--delta-up)" : "var(--delta-down)";
  const sign = value >= 0 ? "+" : "";
  return (
    <span className="tabular-nums font-medium" style={{ color }}>
      {sign}
      {value.toFixed(2)}
      {suffix}
    </span>
  );
}
