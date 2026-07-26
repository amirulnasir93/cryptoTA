import type { DataQuality } from "@crypto-analyzer/shared";

const STYLES: Record<"Good" | "Degraded" | "Poor", { color: string; label: string }> = {
  Good: { color: "var(--status-good)", label: "Good" },
  Degraded: { color: "var(--status-warning)", label: "Degraded" },
  Poor: { color: "var(--status-critical)", label: "Poor" },
};

// Status color never carries meaning alone — always paired with the text label.
export function DataQualityBadge({ quality }: { quality: DataQuality | null | undefined }) {
  const style = quality ? STYLES[quality] : undefined;
  const color = style?.color ?? "var(--status-muted)";
  const label = style?.label ?? "Unknown";

  return (
    <span
      className="inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium"
      style={{
        color,
        backgroundColor: `color-mix(in srgb, ${color} 14%, transparent)`,
      }}
    >
      <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: color }} />
      {label}
    </span>
  );
}
