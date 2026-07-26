import { useState, type ReactNode } from "react";
import { useNavigate } from "react-router-dom";
import type { Token } from "@crypto-analyzer/shared";
import { DataQualityBadge } from "./DataQualityBadge";
import { DeltaText } from "./DeltaText";
import { LabelChip } from "./LabelChip";

type SortKey = "ticker" | "price" | "change24h" | "quality";
const QUALITY_RANK: Record<"Good" | "Degraded" | "Poor", number> = { Good: 0, Degraded: 1, Poor: 2 };

export function TokenTable({
  tokens,
  onEdit,
  onArchive,
  onRestore,
  onRemove,
}: {
  tokens: Token[];
  onEdit?: (token: Token) => void;
  onArchive?: (id: number) => void;
  onRestore?: (id: number) => void;
  onRemove?: (id: number) => void;
}) {
  const navigate = useNavigate();
  const [sortKey, setSortKey] = useState<SortKey>("ticker");
  const [sortDir, setSortDir] = useState<1 | -1>(1);

  const sorted = [...tokens].sort((a, b) => {
    switch (sortKey) {
      case "price":
        return sortDir * ((a.latestSnapshot?.priceCoingecko ?? 0) - (b.latestSnapshot?.priceCoingecko ?? 0));
      case "change24h":
        return sortDir * ((a.latestSnapshot?.change24hPct ?? 0) - (b.latestSnapshot?.change24hPct ?? 0));
      case "quality": {
        const av = a.latestSnapshot?.dataQuality ? QUALITY_RANK[a.latestSnapshot.dataQuality] : 3;
        const bv = b.latestSnapshot?.dataQuality ? QUALITY_RANK[b.latestSnapshot.dataQuality] : 3;
        return sortDir * (av - bv);
      }
      default:
        return sortDir * a.ticker.localeCompare(b.ticker);
    }
  });

  function toggleSort(key: SortKey) {
    if (key === sortKey) setSortDir((d) => (d === 1 ? -1 : 1));
    else {
      setSortKey(key);
      setSortDir(1);
    }
  }

  const showActions = Boolean(onEdit || onArchive || onRestore || onRemove);

  return (
    <div className="overflow-x-auto rounded-lg border border-neutral-200 dark:border-neutral-800">
      <table className="w-full text-sm">
        <thead className="bg-neutral-50 text-left text-xs uppercase tracking-wide text-neutral-500 dark:bg-neutral-900 dark:text-neutral-400">
          <tr>
            <Th onClick={() => toggleSort("ticker")}>Token</Th>
            <Th onClick={() => toggleSort("price")} align="right">
              Price
            </Th>
            <Th onClick={() => toggleSort("change24h")} align="right">
              24h
            </Th>
            <Th align="right">7d</Th>
            <Th onClick={() => toggleSort("quality")}>Data quality</Th>
            <Th>Cluster</Th>
            <Th>Labels</Th>
            {showActions && <Th>Actions</Th>}
          </tr>
        </thead>
        <tbody className="divide-y divide-neutral-100 dark:divide-neutral-800">
          {sorted.map((t) => (
            <tr
              key={t.id}
              onClick={() => navigate(`/tokens/${t.id}`)}
              className="cursor-pointer hover:bg-neutral-50 dark:hover:bg-neutral-900/60"
            >
              <td className="px-3 py-2">
                <span className="font-medium">{t.ticker}</span>
                {t.collisionWarning && (
                  <span
                    title={t.collisionWarning}
                    className="ml-1.5 cursor-help text-xs"
                    style={{ color: "var(--status-warning)" }}
                  >
                    ⚠
                  </span>
                )}
                <div className="text-xs text-neutral-500 dark:text-neutral-400">{t.projectName}</div>
              </td>
              <td className="px-3 py-2 text-right tabular-nums">
                {t.latestSnapshot?.priceCoingecko != null ? `$${formatPrice(t.latestSnapshot.priceCoingecko)}` : "—"}
              </td>
              <td className="px-3 py-2 text-right">
                <DeltaText value={t.latestSnapshot?.change24hPct} />
              </td>
              <td className="px-3 py-2 text-right">
                <DeltaText value={t.latestSnapshot?.change7dPct} />
              </td>
              <td className="px-3 py-2">
                <DataQualityBadge quality={t.latestSnapshot?.dataQuality} />
              </td>
              <td className="px-3 py-2 text-neutral-600 dark:text-neutral-300">{t.cluster ?? "—"}</td>
              <td className="px-3 py-2">
                <div className="flex flex-wrap gap-1">
                  {t.labels.map((l) => (
                    <LabelChip key={l.id} name={l.name} color={l.color} />
                  ))}
                </div>
              </td>
              {showActions && (
                <td className="px-3 py-2" onClick={(e) => e.stopPropagation()}>
                  <div className="flex gap-2 text-xs">
                    {onEdit && (
                      <button onClick={() => onEdit(t)} className="text-neutral-500 hover:underline">
                        Edit
                      </button>
                    )}
                    {t.status === "active" && onArchive && (
                      <button onClick={() => onArchive(t.id)} className="text-neutral-500 hover:underline">
                        Archive
                      </button>
                    )}
                    {t.status === "archived" && onRestore && (
                      <button onClick={() => onRestore(t.id)} className="text-neutral-500 hover:underline">
                        Restore
                      </button>
                    )}
                    {onRemove && (
                      <button
                        onClick={() => {
                          if (confirm(`Remove ${t.ticker} from your watchlist?`)) onRemove(t.id);
                        }}
                        className="hover:underline"
                        style={{ color: "var(--delta-down)" }}
                      >
                        Remove
                      </button>
                    )}
                  </div>
                </td>
              )}
            </tr>
          ))}
          {sorted.length === 0 && (
            <tr>
              <td colSpan={showActions ? 8 : 7} className="px-3 py-6 text-center text-neutral-400">
                No tokens.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}

function Th({
  children,
  onClick,
  align = "left",
}: {
  children: ReactNode;
  onClick?: () => void;
  align?: "left" | "right";
}) {
  return (
    <th
      className={`px-3 py-2 font-medium ${align === "right" ? "text-right" : "text-left"} ${onClick ? "cursor-pointer select-none" : ""}`}
      onClick={onClick}
    >
      {children}
    </th>
  );
}

function formatPrice(v: number): string {
  if (v >= 1) return v.toFixed(2);
  if (v >= 0.01) return v.toFixed(4);
  return v.toPrecision(3);
}
