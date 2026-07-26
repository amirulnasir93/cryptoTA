export function LabelChip({ name, color }: { name: string; color?: string | null }) {
  if (!color) {
    return (
      <span className="inline-flex items-center rounded-full bg-neutral-100 px-2 py-0.5 text-xs font-medium text-neutral-600 dark:bg-neutral-800 dark:text-neutral-300">
        {name}
      </span>
    );
  }
  return (
    <span
      className="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium"
      style={{ backgroundColor: `color-mix(in srgb, ${color} 18%, transparent)`, color }}
    >
      {name}
    </span>
  );
}
