import { useMemo, useRef, useState, type FormEvent } from "react";
import { searchCoingecko, type Token } from "@crypto-analyzer/shared";
import {
  useArchiveToken,
  useCreateToken,
  useLabels,
  useRemoveToken,
  useRestoreToken,
  useTokens,
} from "../api/queries";
import { TokenTable } from "../components/TokenTable";
import { Modal } from "../components/Modal";
import { SearchableSelect, type ComboOption } from "../components/SearchableSelect";
import { EditTokenModal } from "../components/EditTokenModal";
import { NotConfiguredNotice } from "../components/NotConfiguredNotice";
import { COMMON_CHAINS } from "../constants";
import { isReady } from "../appConfig";

type StatusFilter = "active" | "archived" | "all";
const STATUS_OPTIONS: StatusFilter[] = ["active", "archived", "all"];

export function Watchlist() {
  const [status, setStatus] = useState<StatusFilter>("active");
  const [labelId, setLabelId] = useState<number | undefined>(undefined);
  const [showAdd, setShowAdd] = useState(false);
  const [editingToken, setEditingToken] = useState<Token | null>(null);

  const { data: tokens, isLoading } = useTokens({ status, labelId });
  const { data: labels } = useLabels();
  const archive = useArchiveToken();
  const restore = useRestoreToken();
  const remove = useRemoveToken();

  if (!isReady()) return <NotConfiguredNotice />;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex gap-1">
          {STATUS_OPTIONS.map((s) => (
            <button
              key={s}
              onClick={() => setStatus(s)}
              className={`rounded-md px-3 py-1.5 text-sm font-medium capitalize ${
                status === s
                  ? "bg-neutral-900 text-white dark:bg-neutral-100 dark:text-neutral-900"
                  : "text-neutral-600 hover:bg-neutral-100 dark:text-neutral-300 dark:hover:bg-neutral-800"
              }`}
            >
              {s}
            </button>
          ))}
        </div>

        <div className="flex items-center gap-2">
          <select
            value={labelId ?? ""}
            onChange={(e) => setLabelId(e.target.value ? Number(e.target.value) : undefined)}
            className="rounded-md border border-neutral-200 bg-white px-2 py-1.5 text-sm text-neutral-900 dark:border-neutral-800 dark:bg-neutral-900 dark:text-neutral-100"
          >
            <option value="">All labels</option>
            {labels?.map((l) => (
              <option key={l.id} value={l.id}>
                {l.name}
              </option>
            ))}
          </select>
          <button
            onClick={() => setShowAdd(true)}
            className="rounded-md bg-neutral-900 px-3 py-1.5 text-sm font-medium text-white dark:bg-neutral-100 dark:text-neutral-900"
          >
            + Add token
          </button>
        </div>
      </div>

      {isLoading ? (
        <p className="text-neutral-500">Loading…</p>
      ) : (
        <TokenTable
          tokens={tokens ?? []}
          onEdit={(token) => setEditingToken(token)}
          onArchive={(id) => archive.mutate(id)}
          onRestore={(id) => restore.mutate(id)}
          onRemove={(id) => remove.mutate(id)}
        />
      )}

      <AddTokenModal open={showAdd} onClose={() => setShowAdd(false)} />
      <EditTokenModal token={editingToken} onClose={() => setEditingToken(null)} />
    </div>
  );
}

function AddTokenModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { data: labels } = useLabels();
  const { data: allTokens } = useTokens({ status: "all" });
  const createToken = useCreateToken();
  const [form, setForm] = useState({
    ticker: "",
    projectName: "",
    primaryChain: "",
    coingeckoId: "",
    cluster: "",
    notes: "",
  });
  const [selectedLabels, setSelectedLabels] = useState<number[]>([]);
  const [warning, setWarning] = useState<string | null>(null);

  const [cgResults, setCgResults] = useState<ComboOption[]>([]);
  const [cgLoading, setCgLoading] = useState(false);
  const cgTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

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

  function reset() {
    setForm({ ticker: "", projectName: "", primaryChain: "", coingeckoId: "", cluster: "", notes: "" });
    setSelectedLabels([]);
    setWarning(null);
    setCgResults([]);
  }

  function close() {
    reset();
    onClose();
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    const created = await createToken.mutateAsync({
      ticker: form.ticker,
      projectName: form.projectName || undefined,
      primaryChain: form.primaryChain || undefined,
      coingeckoId: form.coingeckoId || undefined,
      cluster: form.cluster || undefined,
      notes: form.notes || undefined,
      labelIds: selectedLabels,
    });
    if (created.collisionWarning) {
      setWarning(created.collisionWarning);
      return; // pause so the user actually sees the warning before the modal closes
    }
    close();
  }

  return (
    <Modal open={open} onClose={close} title="Add token">
      <form onSubmit={handleSubmit} className="space-y-3">
        <Field
          label="Ticker*"
          value={form.ticker}
          onChange={(v) => setForm((f) => ({ ...f, ticker: v.toUpperCase() }))}
          required
        />
        <Field
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
          <p className="mt-1 text-xs text-neutral-400">
            Pick from search results rather than typing an id from memory — a wrong/stale CoinGecko id is the
            single most common way this data goes wrong.
          </p>
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

        <Field label="Notes" value={form.notes} onChange={(v) => setForm((f) => ({ ...f, notes: v }))} textarea />

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

        {warning && (
          <div
            className="rounded-md border px-3 py-2 text-sm"
            style={{ borderColor: "var(--status-warning)", color: "var(--status-warning)" }}
          >
            ⚠ {warning}
          </div>
        )}

        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={close} className="rounded-md px-3 py-1.5 text-sm text-neutral-500">
            {warning ? "Close" : "Cancel"}
          </button>
          {!warning && (
            <button
              type="submit"
              disabled={createToken.isPending || !form.ticker}
              className="rounded-md bg-neutral-900 px-3 py-1.5 text-sm font-medium text-white disabled:opacity-50 dark:bg-neutral-100 dark:text-neutral-900"
            >
              {createToken.isPending ? "Adding…" : "Add token"}
            </button>
          )}
        </div>
      </form>
    </Modal>
  );
}

function Field({
  label,
  value,
  onChange,
  required,
  textarea,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  required?: boolean;
  textarea?: boolean;
}) {
  const className =
    "w-full rounded-md border border-neutral-200 bg-white px-2 py-1.5 text-sm text-neutral-900 dark:border-neutral-800 dark:bg-neutral-900 dark:text-neutral-100";
  return (
    <div>
      <label className="mb-1 block text-xs font-medium text-neutral-500 dark:text-neutral-400">{label}</label>
      {textarea ? (
        <textarea value={value} onChange={(e) => onChange(e.target.value)} className={className} rows={2} />
      ) : (
        <input value={value} onChange={(e) => onChange(e.target.value)} required={required} className={className} />
      )}
    </div>
  );
}
