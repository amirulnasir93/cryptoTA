import { useState, type FormEvent } from "react";
import { useCreateLabel, useDeleteLabel, useLabels } from "../api/queries";

const SWATCHES = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#4a3aa7", "#e34948", "#898781"];

export function Labels() {
  const { data: labels, isLoading } = useLabels();
  const createLabel = useCreateLabel();
  const deleteLabel = useDeleteLabel();
  const [name, setName] = useState("");
  const [color, setColor] = useState(SWATCHES[0]);

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    createLabel.mutate({ name: name.trim(), color }, { onSuccess: () => setName("") });
  }

  return (
    <div className="max-w-lg space-y-4">
      <div>
        <h1 className="mb-1 text-lg font-semibold">Labels</h1>
        <p className="text-sm text-neutral-500 dark:text-neutral-400">
          Group your watchlist into overlapping lists — a token can carry more than one label.
        </p>
      </div>

      <form onSubmit={handleSubmit} className="flex items-end gap-2">
        <div className="flex-1">
          <label className="mb-1 block text-xs text-neutral-500 dark:text-neutral-400">Name</label>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g. Core, Degen, Long-term hold"
            className="w-full rounded-md border border-neutral-200 bg-white px-2 py-1.5 text-sm text-neutral-900 dark:border-neutral-800 dark:bg-neutral-900 dark:text-neutral-100"
          />
        </div>
        <div>
          <label className="mb-1 block text-xs text-neutral-500 dark:text-neutral-400">Color</label>
          <div className="flex gap-1">
            {SWATCHES.map((c) => (
              <button
                key={c}
                type="button"
                onClick={() => setColor(c)}
                className="h-6 w-6 rounded-full"
                style={{
                  backgroundColor: c,
                  outline: color === c ? "2px solid currentColor" : "none",
                  outlineOffset: 2,
                }}
                aria-label={c}
              />
            ))}
          </div>
        </div>
        <button
          type="submit"
          className="rounded-md bg-neutral-900 px-3 py-1.5 text-sm font-medium text-white dark:bg-neutral-100 dark:text-neutral-900"
        >
          Add
        </button>
      </form>

      {isLoading ? (
        <p className="text-neutral-500">Loading…</p>
      ) : (
        <ul className="space-y-1.5">
          {labels?.map((l) => (
            <li
              key={l.id}
              className="flex items-center justify-between rounded-md border border-neutral-200 bg-white px-3 py-2 dark:border-neutral-800 dark:bg-neutral-900"
            >
              <span className="flex items-center gap-2 text-sm">
                <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: l.color ?? "#999" }} />
                {l.name}
              </span>
              <button
                onClick={() => {
                  if (confirm(`Delete label "${l.name}"? This removes it from any tokens using it.`)) {
                    deleteLabel.mutate(l.id);
                  }
                }}
                className="text-xs text-neutral-400 hover:underline"
              >
                delete
              </button>
            </li>
          ))}
          {labels?.length === 0 && <li className="text-neutral-400">No labels yet.</li>}
        </ul>
      )}
    </div>
  );
}
