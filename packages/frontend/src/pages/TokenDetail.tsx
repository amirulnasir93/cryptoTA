import { useState, type FormEvent, type ReactNode } from "react";
import { Link, useParams } from "react-router-dom";
import type { Catalyst, ChartInterval } from "@crypto-analyzer/shared";
import {
  useCreateCatalyst,
  useDeleteCatalyst,
  useLabels,
  useToken,
  useTokenAnalysis,
  useTokenInsight,
  useUpdateToken,
} from "../api/queries";
import { DataQualityBadge } from "../components/DataQualityBadge";
import { DeltaText } from "../components/DeltaText";
import { InsightPanel } from "../components/InsightPanel";
import { TechnicalAnalysisPanel } from "../components/TechnicalAnalysisPanel";
import { NotConfiguredNotice } from "../components/NotConfiguredNotice";
import { isReady } from "../appConfig";

const TABS = ["Overview", "Technical analysis", "Insight"] as const;
type Tab = (typeof TABS)[number];

export function TokenDetail() {
  const { id } = useParams();
  const tokenId = id ? Number(id) : undefined;
  const { data: token, isLoading } = useToken(tokenId);
  const { data: labels } = useLabels();
  const [tab, setTab] = useState<Tab>("Overview");
  const [chartInterval, setChartInterval] = useState<ChartInterval>("1d");
  const { data: analysis, isLoading: analysisLoading } = useTokenAnalysis(tokenId, chartInterval);
  const { data: insight, isLoading: insightLoading } = useTokenInsight(tab === "Insight" ? tokenId : undefined);
  const updateToken = useUpdateToken();
  const [notesDraft, setNotesDraft] = useState<string | null>(null);
  const [newLabel, setNewLabel] = useState("");

  if (!isReady()) return <NotConfiguredNotice />;
  if (isLoading) return <p className="text-neutral-500">Loading…</p>;
  if (!token) return <p className="text-neutral-500">Token not found.</p>;

  const s = token.latestSnapshot;
  const notes = notesDraft ?? token.notes ?? "";

  function toggleLabel(name: string) {
    if (!token) return;
    const has = token.labels.some((l) => l.name === name);
    const names = token.labels.map((l) => l.name);
    const next = has ? names.filter((n) => n !== name) : [...names, name];
    updateToken.mutate({ id: token.id, input: { labelNames: next } });
  }

  function addNewLabel() {
    if (!token) return;
    const name = newLabel.trim();
    if (!name || token.labels.some((l) => l.name === name)) return;
    updateToken.mutate({ id: token.id, input: { labelNames: [...token.labels.map((l) => l.name), name] } });
    setNewLabel("");
  }

  function saveNotes() {
    if (!token) return;
    updateToken.mutate({ id: token.id, input: { notes } });
  }

  return (
    <div className="space-y-6">
      <div>
        <div className="flex items-center gap-2">
          <h1 className="text-xl font-semibold">{token.ticker}</h1>
          <span className="text-neutral-500 dark:text-neutral-400">{token.projectName}</span>
          <DataQualityBadge quality={s?.dataQuality} />
        </div>
        <p className="text-sm text-neutral-500 dark:text-neutral-400">
          {token.primaryChain}
          {token.cluster && ` · ${token.cluster}`}
        </p>
      </div>

      {token.collisionWarning && (
        <div
          className="rounded-md border px-3 py-2 text-sm"
          style={{ borderColor: "var(--status-warning)", color: "var(--status-warning)" }}
        >
          ⚠ {token.collisionWarning}
        </div>
      )}

      <div className="flex gap-0.5 rounded-md border border-neutral-200 p-0.5 dark:border-neutral-800 w-fit">
        {TABS.map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`rounded px-3 py-1 text-sm font-medium ${
              tab === t
                ? "bg-neutral-900 text-white dark:bg-neutral-100 dark:text-neutral-900"
                : "text-neutral-500 hover:bg-neutral-100 dark:text-neutral-400 dark:hover:bg-neutral-800"
            }`}
          >
            {t}
          </button>
        ))}
      </div>

      {tab === "Overview" && (
        <>
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
            <Metric label="Price" value={s?.priceCoingecko != null ? `$${s.priceCoingecko}` : "—"} />
            <Metric label="24h" value={<DeltaText value={s?.change24hPct} />} />
            <Metric label="7d" value={<DeltaText value={s?.change7dPct} />} />
            <Metric label="30d" value={<DeltaText value={s?.change30dPct} />} />
            <Metric label="Market cap" value={s?.marketCap != null ? formatUsd(s.marketCap) : "—"} />
            <Metric label="FDV" value={s?.fdv != null ? formatUsd(s.fdv) : "—"} />
            <Metric label="24h volume" value={s?.volume24h != null ? formatUsd(s.volume24h) : "—"} />
            <Metric label="Vol / MCap" value={s?.volumeToMcap != null ? s.volumeToMcap.toFixed(2) : "—"} />
            <Metric
              label="ATH drawdown"
              value={s?.drawdownFromAthPct != null ? `${s.drawdownFromAthPct.toFixed(1)}%` : "—"}
            />
            <Metric label="Float" value={s?.floatPct != null ? `${s.floatPct.toFixed(1)}%` : "—"} />
            <Metric label="TVL" value={s?.tvl != null ? formatUsd(s.tvl) : "—"} />
            <Metric
              label="TVL 30d"
              value={s?.tvlChange30dPct != null ? <DeltaText value={s.tvlChange30dPct} /> : "—"}
            />
          </div>

          <section className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
            <h2 className="mb-1 text-sm font-semibold text-neutral-700 dark:text-neutral-200">Per-source price</h2>
            <p className="mb-3 text-xs text-neutral-500 dark:text-neutral-400">
              {s?.gatingReason ?? "No snapshot yet — run a refresh."}
            </p>
            <div className="grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
              <SourcePrice label="CoinGecko" value={s?.priceCoingecko ?? null} />
              <SourcePrice label="DexScreener" value={s?.priceDexscreener ?? null} />
              <SourcePrice label="Binance" value={s?.priceBinance ?? null} />
              <SourcePrice label="MEXC" value={s?.priceMexc ?? null} />
            </div>
            {s?.assessableHorizons && s.assessableHorizons.length > 0 && (
              <div className="mt-3 flex flex-wrap gap-1.5">
                {s.assessableHorizons.map((h) => (
                  <span
                    key={h}
                    className="rounded-full bg-neutral-100 px-2 py-0.5 text-xs text-neutral-600 dark:bg-neutral-800 dark:text-neutral-300"
                  >
                    {h.replace("_", " ")}
                  </span>
                ))}
              </div>
            )}
          </section>

          {token.clusterSiblings.length > 0 && (
            <section className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
              <h2 className="mb-2 text-sm font-semibold text-neutral-700 dark:text-neutral-200">
                Cluster: {token.cluster}
              </h2>
              <p className="mb-2 text-xs text-neutral-500 dark:text-neutral-400">
                These tokens don't move independently — a read on one is a read on the cluster.
              </p>
              <ul className="flex flex-wrap gap-4 text-sm">
                {token.clusterSiblings.map((sib) => (
                  <li key={sib.id}>
                    <Link to={`/tokens/${sib.id}`} className="font-medium hover:underline">
                      {sib.ticker}
                    </Link>{" "}
                    <DeltaText value={sib.latestSnapshot?.change24hPct} />
                  </li>
                ))}
              </ul>
            </section>
          )}

          <section className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
            <h2 className="mb-2 text-sm font-semibold text-neutral-700 dark:text-neutral-200">Labels</h2>
            <div className="flex flex-wrap gap-2">
              {labels?.map((l) => {
                const active = token.labels.some((tl) => tl.name === l.name);
                return (
                  <button
                    key={l.id}
                    onClick={() => toggleLabel(l.name)}
                    className={`rounded-full border px-2.5 py-1 text-xs font-medium ${
                      active
                        ? "border-transparent bg-neutral-900 text-white dark:bg-neutral-100 dark:text-neutral-900"
                        : "border-neutral-300 text-neutral-500 dark:border-neutral-700"
                    }`}
                  >
                    {l.name}
                  </button>
                );
              })}
              {(!labels || labels.length === 0) && <p className="text-sm text-neutral-400">No labels yet.</p>}
            </div>
            <div className="mt-3 flex items-end gap-2">
              <div className="flex-1">
                <label className="mb-1 block text-xs text-neutral-500 dark:text-neutral-400">New label</label>
                <input
                  value={newLabel}
                  onChange={(e) => setNewLabel(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") {
                      e.preventDefault();
                      addNewLabel();
                    }
                  }}
                  className="w-full rounded-md border border-neutral-200 bg-white px-2 py-1.5 text-sm text-neutral-900 dark:border-neutral-800 dark:bg-neutral-950 dark:text-neutral-100"
                />
              </div>
              <button
                onClick={addNewLabel}
                className="rounded-md border border-neutral-300 px-3 py-1.5 text-xs font-medium text-neutral-900 dark:border-neutral-700 dark:text-neutral-100"
              >
                Add
              </button>
            </div>
          </section>

          <section className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
            <h2 className="mb-2 text-sm font-semibold text-neutral-700 dark:text-neutral-200">Notes</h2>
            <textarea
              value={notes}
              onChange={(e) => setNotesDraft(e.target.value)}
              onBlur={saveNotes}
              rows={3}
              className="w-full rounded-md border border-neutral-200 bg-white px-2 py-1.5 text-sm text-neutral-900 dark:border-neutral-800 dark:bg-neutral-950 dark:text-neutral-100"
            />
          </section>

          <CatalystSection ticker={token.ticker} catalysts={token.catalysts} />
        </>
      )}

      {tab === "Technical analysis" &&
        (analysisLoading ? (
          <p className="text-sm text-neutral-500">Loading technical analysis…</p>
        ) : analysis ? (
          <TechnicalAnalysisPanel analysis={analysis} interval={chartInterval} onIntervalChange={setChartInterval} />
        ) : null)}

      {tab === "Insight" &&
        (insightLoading ? (
          <p className="text-sm text-neutral-500">Loading insight…</p>
        ) : insight ? (
          <InsightPanel insight={insight} />
        ) : null)}
    </div>
  );
}

function Metric({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3 dark:border-neutral-800 dark:bg-neutral-900">
      <div className="text-xs text-neutral-500 dark:text-neutral-400">{label}</div>
      <div className="mt-0.5 text-base font-semibold tabular-nums">{value}</div>
    </div>
  );
}

function SourcePrice({ label, value }: { label: string; value: number | null }) {
  return (
    <div>
      <div className="text-xs text-neutral-500 dark:text-neutral-400">{label}</div>
      <div className="tabular-nums">{value != null ? `$${value}` : "—"}</div>
    </div>
  );
}

function CatalystSection({ ticker, catalysts }: { ticker: string; catalysts: Catalyst[] }) {
  const createCatalyst = useCreateCatalyst();
  const deleteCatalyst = useDeleteCatalyst();
  const [form, setForm] = useState<{ eventDate: string; eventType: Catalyst["eventType"]; description: string }>({
    eventDate: "",
    eventType: "unlock",
    description: "",
  });

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!form.eventDate || !form.description) return;
    await createCatalyst.mutateAsync({
      ticker,
      eventDate: form.eventDate,
      eventType: form.eventType,
      description: form.description,
    });
    setForm({ eventDate: "", eventType: "unlock", description: "" });
  }

  return (
    <section className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
      <h2 className="mb-2 text-sm font-semibold text-neutral-700 dark:text-neutral-200">Catalysts</h2>
      <ul className="mb-3 space-y-1.5 text-sm">
        {catalysts.length === 0 && <li className="text-neutral-400">None recorded.</li>}
        {catalysts.map((c) => (
          <li key={c.id} className="flex items-center justify-between gap-2">
            <span>
              <span className="tabular-nums text-neutral-500 dark:text-neutral-400">
                {new Date(c.eventDate).toLocaleDateString()}
              </span>{" "}
              <span className="rounded bg-neutral-100 px-1.5 py-0.5 text-xs dark:bg-neutral-800">
                {c.eventType}
              </span>{" "}
              {c.description}
              {c.sizePctOfSupply != null && ` (${c.sizePctOfSupply}% of supply)`}
            </span>
            <button
              onClick={() => deleteCatalyst.mutate(c.id)}
              className="shrink-0 text-xs text-neutral-400 hover:underline"
            >
              remove
            </button>
          </li>
        ))}
      </ul>
      <form onSubmit={handleSubmit} className="flex flex-wrap items-end gap-2 text-sm">
        <div>
          <label className="mb-1 block text-xs text-neutral-500 dark:text-neutral-400">Date</label>
          <input
            type="date"
            value={form.eventDate}
            onChange={(e) => setForm((f) => ({ ...f, eventDate: e.target.value }))}
            className="rounded-md border border-neutral-200 bg-white px-2 py-1.5 text-neutral-900 dark:border-neutral-800 dark:bg-neutral-950 dark:text-neutral-100"
          />
        </div>
        <div>
          <label className="mb-1 block text-xs text-neutral-500 dark:text-neutral-400">Type</label>
          <select
            value={form.eventType}
            onChange={(e) => setForm((f) => ({ ...f, eventType: e.target.value as Catalyst["eventType"] }))}
            className="rounded-md border border-neutral-200 bg-white px-2 py-1.5 text-neutral-900 dark:border-neutral-800 dark:bg-neutral-950 dark:text-neutral-100"
          >
            <option value="unlock">Unlock</option>
            <option value="listing">Listing</option>
            <option value="governance">Governance</option>
            <option value="launch">Launch</option>
            <option value="other">Other</option>
          </select>
        </div>
        <div className="min-w-[10rem] flex-1">
          <label className="mb-1 block text-xs text-neutral-500 dark:text-neutral-400">Description</label>
          <input
            value={form.description}
            onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
            className="w-full rounded-md border border-neutral-200 bg-white px-2 py-1.5 text-neutral-900 dark:border-neutral-800 dark:bg-neutral-950 dark:text-neutral-100"
          />
        </div>
        <button
          type="submit"
          className="rounded-md bg-neutral-900 px-3 py-1.5 font-medium text-white dark:bg-neutral-100 dark:text-neutral-900"
        >
          Add
        </button>
      </form>
    </section>
  );
}

function formatUsd(v: number): string {
  const abs = Math.abs(v);
  if (abs >= 1_000_000_000) return `$${(v / 1_000_000_000).toFixed(2)}B`;
  if (abs >= 1_000_000) return `$${(v / 1_000_000).toFixed(2)}M`;
  if (abs >= 1_000) return `$${(v / 1_000).toFixed(1)}K`;
  return `$${v.toFixed(2)}`;
}
