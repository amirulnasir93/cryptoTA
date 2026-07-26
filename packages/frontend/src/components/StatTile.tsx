import type { ReactNode } from "react";

export function StatTile({ label, value, sub }: { label: string; value: ReactNode; sub?: ReactNode }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
      <div className="text-xs font-medium uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
        {label}
      </div>
      <div className="mt-1 text-2xl font-semibold tabular-nums text-neutral-900 dark:text-neutral-50">
        {value}
      </div>
      {sub && <div className="mt-1 text-xs text-neutral-500 dark:text-neutral-400">{sub}</div>}
    </div>
  );
}
