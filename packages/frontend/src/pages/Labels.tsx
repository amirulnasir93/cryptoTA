import { useLabels, useDeleteLabel } from "../api/queries";
import { isReady } from "../appConfig";
import { NotConfiguredNotice } from "../components/NotConfiguredNotice";

// There's no separate Labels table now that the Sheet is the database -- a
// label only exists by being listed in some token's "Labels" cell. So this
// page shows the distinct set already in use (add a new one from a token's
// own Overview tab) and can remove a label from every token at once.
export function Labels() {
  const { data: labels, isLoading } = useLabels();
  const deleteLabel = useDeleteLabel();

  if (!isReady()) return <NotConfiguredNotice />;

  return (
    <div className="max-w-lg space-y-4">
      <div>
        <h1 className="mb-1 text-lg font-semibold">Labels</h1>
        <p className="text-sm text-neutral-500 dark:text-neutral-400">
          Add a new label from a token's Overview tab -- it shows up here once at least one token has it.
        </p>
      </div>

      {isLoading ? (
        <p className="text-neutral-500">Loading…</p>
      ) : (
        <ul className="space-y-1.5">
          {labels?.map((l) => (
            <li
              key={l.id}
              className="flex items-center justify-between rounded-md border border-neutral-200 bg-white px-3 py-2 dark:border-neutral-800 dark:bg-neutral-900"
            >
              <span className="text-sm">{l.name}</span>
              <button
                onClick={() => {
                  if (confirm(`Delete label "${l.name}"? This removes it from any tokens using it.`)) {
                    deleteLabel.mutate(l.name);
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
