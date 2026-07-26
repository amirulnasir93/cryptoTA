import { useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { searchCoingecko, type Token } from "@crypto-analyzer/shared";
import { useLabels, useTokens, useUpdateToken } from "../api/queries";
import { COMMON_CHAINS } from "../constants";
import { Modal } from "./Modal";
import { SearchableSelect, type ComboOption } from "./SearchableSelect";

export function EditTokenModal({ token, onClose }: { token: Token | null; onClose: () => void }) {
  const { data: labels } = useLabels();
  const { data: allTokens } = useTokens({ status: "all" });
  const updateToken = useUpdateToken();

  const [form, setForm] = useState({ projectName: "", primaryChain: "", coingeckoId: "", cluster: "", notes: "" });
  const [selectedLabels, setSelectedLabels] = useState<number[]>([]);
  const [cgResults, setCgResults] = useState<ComboOption[]>([]);
  const [cgLoading, setCgLoading] = useState(false);

  // Re-seed the form whenever a different token is opened for editing.
  useEffect(() => {
    if (!token) return;
    setForm({
      projectName: token.projectName ?? "",
      primaryChain: token.primaryChain ?? "",
      coingeckoId: token.coingeckoId ?? "",
      cluster: token.cluster ?? "",
      notes: token.notes ?? "",
    });
    setSelectedLabels(token.labels.map((l) => l.id));
    setCgResults([]);
  }, [token]);

  const chainOptions = useMemo(
    () =>
      COMMON_CHAINS.filter((c) => c.toLowerCase().includes(form.primaryChain.toLowerCase())).map((c) => ({
        value: c,
        label: c,
      })),
    [form.primaryChain]
  );

  const clusterOptions = useMemo(() => {
    const clusters = new Set<string>();
    for (const t of allTokens ?? []) {
      if (t.cluster) clusters.add(t.cluster);
    }
    return [...clusters]
      .filter((c) => c.toLowerCase().includes(form.cluster.toLowerCase()))
      .sort()
      .map((c) => ({ value: c, label: c }));
  }, [allTokens, form.cluster]);

  const cgTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  function handleCoingeckoQuery(text: string) {
    if (cgTimer.current) clearTimeout(cgTimer.current);
    if (!text.trim()) {
      setCgResults([]);
      return;
    }
    setCgLoading(true);
    cgTimer.current = setTimeout(async () => {
      try {
        const results = await searchCoingecko(text);
        setCgResults(
          results.map((r) => ({ value: r.id, label: `${r.name} (${r.symbol.toUpperCase()})`, sublabel: r.id }))
        );
      } finally {
        setCgLoading(false);
      }
    }, 350);
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!token) return;
    await updateToken.mutateAsync({
      id: token.id,
      input: {
        projectName: form.projectName || null,
        primaryChain: form.primaryChain || null,
        coingeckoId: form.coingeckoId || null,
        cluster: form.cluster || null,
        notes: form.notes || null,
        labelIds: selectedLabels,
      },
    });
    onClose();
  }

  return (
    <Modal open={token !== null} onClose={onClose} title={token ? `Edit ${token.ticker}` : "Edit token"}>
      {token && (
        <form onSubmit={handleSubmit} className="space-y-3">
          <div>
            <label className="mb-1 block text-xs font-medium text-neutral-500 dark:text-neutral-400">Ticker</label>
            <input
              value={token.ticker}
              disabled
              className="w-full rounded-md border border-neutral-200 bg-neutral-100 px-2 py-1.5 text-sm text-neutral-500 dark:border-neutral-800 dark:bg-neutral-800 dark:text-neutral-400"
            />
          </div>

          <TextField
            label="Project name"
            value={form.projectName}
            onChange={(v) => setForm((f) => ({ ...f, projectName: v }))}
          />

          <div>
            <label className="mb-1 block text-xs font-medium text-neutral-500 dark:text-neutral-400">Chain</label>
            <SearchableSelect
              value={form.primaryChain}
              onChange={(v) => setForm((f) => ({ ...f, primaryChain: v }))}
              options={chainOptions}
              placeholder="e.g. Ethereum"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-neutral-500 dark:text-neutral-400">
              CoinGecko ID
            </label>
            <SearchableSelect
              value={form.coingeckoId}
              onChange={(v) => setForm((f) => ({ ...f, coingeckoId: v }))}
              onQueryChange={handleCoingeckoQuery}
              options={cgResults}
              loading={cgLoading}
              placeholder="Search by project name or ticker…"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-neutral-500 dark:text-neutral-400">Cluster</label>
            <SearchableSelect
              value={form.cluster}
              onChange={(v) => setForm((f) => ({ ...f, cluster: v }))}
              options={clusterOptions}
              placeholder="e.g. Trading venue"
            />
          </div>

          <TextField label="Notes" value={form.notes} onChange={(v) => setForm((f) => ({ ...f, notes: v }))} textarea />

          {labels && labels.length > 0 && (
            <div>
              <label className="mb-1 block text-xs font-medium text-neutral-500 dark:text-neutral-400">
                Labels
              </label>
              <div className="flex flex-wrap gap-3">
                {labels.map((l) => (
                  <label key={l.id} className="flex items-center gap-1.5 text-sm">
                    <input
                      type="checkbox"
                      checked={selectedLabels.includes(l.id)}
                      onChange={(e) =>
                        setSelectedLabels((prev) =>
                          e.target.checked ? [...prev, l.id] : prev.filter((id) => id !== l.id)
                        )
                      }
                    />
                    {l.name}
                  </label>
                ))}
              </div>
            </div>
          )}

          <div className="flex justify-end gap-2 pt-2">
            <button type="button" onClick={onClose} className="rounded-md px-3 py-1.5 text-sm text-neutral-500">
              Cancel
            </button>
            <button
              type="submit"
              disabled={updateToken.isPending}
              className="rounded-md bg-neutral-900 px-3 py-1.5 text-sm font-medium text-white disabled:opacity-50 dark:bg-neutral-100 dark:text-neutral-900"
            >
              {updateToken.isPending ? "Saving…" : "Save changes"}
            </button>
          </div>
        </form>
      )}
    </Modal>
  );
}

function TextField({
  label,
  value,
  onChange,
  textarea,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  textarea?: boolean;
}) {
  const className =
    "w-full rounded-md border border-neutral-200 bg-white px-2 py-1.5 text-sm text-neutral-900 dark:border-neutral-800 dark:bg-neutral-950 dark:text-neutral-100";
  return (
    <div>
      <label className="mb-1 block text-xs font-medium text-neutral-500 dark:text-neutral-400">{label}</label>
      {textarea ? (
        <textarea value={value} onChange={(e) => onChange(e.target.value)} className={className} rows={2} />
      ) : (
        <input value={value} onChange={(e) => onChange(e.target.value)} className={className} />
      )}
    </div>
  );
}
