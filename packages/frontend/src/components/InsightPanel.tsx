import type { TokenInsightResult } from "@crypto-analyzer/shared";

// CoinGecko's "plain text" description field still carries a few stray HTML
// entities (observed live: literal "&nbsp;") -- decode the small known set
// rather than rendering as HTML, so there's no injection surface.
const HTML_ENTITIES: Record<string, string> = {
  "&nbsp;": " ",
  "&amp;": "&",
  "&quot;": '"',
  "&#39;": "'",
  "&lt;": "<",
  "&gt;": ">",
};

function decodeEntities(text: string): string {
  return text.replace(/&nbsp;|&amp;|&quot;|&#39;|&lt;|&gt;/g, (m) => HTML_ENTITIES[m]);
}

function hostname(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return url;
  }
}

function formatCount(n: number | null): string {
  if (n == null) return "—";
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return String(n);
}

export function InsightPanel({ insight }: { insight: TokenInsightResult }) {
  if (!insight.available) {
    return (
      <section className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
        <h2 className="mb-2 text-sm font-semibold text-neutral-700 dark:text-neutral-200">Insight</h2>
        <p className="text-sm text-neutral-500 dark:text-neutral-400">{insight.reason}</p>
      </section>
    );
  }

  const allLinks = [
    ...insight.links.homepage.map((url) => ({ label: hostname(url), url })),
    insight.links.twitter && { label: "Twitter / X", url: insight.links.twitter },
    insight.links.telegram && { label: "Telegram", url: insight.links.telegram },
    insight.links.subreddit && { label: "Reddit", url: insight.links.subreddit },
    ...insight.links.chat.map((url) => ({ label: hostname(url), url })),
    ...insight.links.github.map((url) => ({ label: hostname(url) + url.replace(/^https?:\/\/github\.com/, ""), url })),
  ].filter((l): l is { label: string; url: string } => Boolean(l));

  const hasDeveloperData =
    insight.developer.stars != null ||
    insight.developer.forks != null ||
    insight.developer.commitCount4Weeks != null;
  const hasCommunityData =
    insight.community.redditSubscribers != null || insight.community.telegramUserCount != null;
  const hasSentiment = insight.sentimentUpPct != null && insight.sentimentDownPct != null;

  return (
    <section className="space-y-4">
      <div className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
        <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
          <h2 className="text-sm font-semibold text-neutral-700 dark:text-neutral-200">Insight</h2>
          <span className="text-xs text-neutral-400">Sourced from CoinGecko's public project data</span>
        </div>

        {insight.description && (
          <p className="mb-3 whitespace-pre-line text-sm text-neutral-700 dark:text-neutral-300">
            {decodeEntities(insight.description)}
          </p>
        )}

        {insight.categories.length > 0 && (
          <div className="mb-3 flex flex-wrap gap-1.5">
            {insight.categories.slice(0, 12).map((c) => (
              <span
                key={c}
                className="rounded-full bg-neutral-100 px-2 py-0.5 text-xs text-neutral-600 dark:bg-neutral-800 dark:text-neutral-300"
              >
                {c}
              </span>
            ))}
          </div>
        )}

        {allLinks.length > 0 && (
          <div className="flex flex-wrap gap-x-4 gap-y-1.5 text-sm">
            {allLinks.map((l) => (
              <a
                key={l.url}
                href={l.url}
                target="_blank"
                rel="noreferrer noopener"
                className="text-blue-600 hover:underline dark:text-blue-400"
              >
                {l.label}
              </a>
            ))}
          </div>
        )}
      </div>

      {(hasSentiment || insight.marketCapRank != null || insight.genesisDate) && (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
          {insight.marketCapRank != null && <Stat label="Market cap rank" value={`#${insight.marketCapRank}`} />}
          {insight.genesisDate && (
            <Stat label="Genesis date" value={new Date(insight.genesisDate).toLocaleDateString()} />
          )}
          {hasSentiment && (
            <Stat
              label="Community sentiment"
              value={`${insight.sentimentUpPct}% up`}
              sub={`${insight.sentimentDownPct}% down`}
            />
          )}
        </div>
      )}

      {(hasCommunityData || hasDeveloperData) && (
        <div className="rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
          <h3 className="mb-2 text-xs font-semibold uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
            Community &amp; developer activity
          </h3>
          <div className="grid grid-cols-2 gap-4 text-sm sm:grid-cols-4">
            {insight.community.redditSubscribers != null && (
              <Stat label="Reddit subscribers" value={formatCount(insight.community.redditSubscribers)} compact />
            )}
            {insight.community.telegramUserCount != null && (
              <Stat label="Telegram members" value={formatCount(insight.community.telegramUserCount)} compact />
            )}
            {insight.developer.stars != null && (
              <Stat label="GitHub stars" value={formatCount(insight.developer.stars)} compact />
            )}
            {insight.developer.forks != null && (
              <Stat label="GitHub forks" value={formatCount(insight.developer.forks)} compact />
            )}
            {insight.developer.pullRequestContributors != null && (
              <Stat label="Contributors" value={formatCount(insight.developer.pullRequestContributors)} compact />
            )}
            {insight.developer.commitCount4Weeks != null && (
              <Stat label="Commits (4wk)" value={formatCount(insight.developer.commitCount4Weeks)} compact />
            )}
          </div>
        </div>
      )}
    </section>
  );
}

function Stat({ label, value, sub, compact }: { label: string; value: string; sub?: string; compact?: boolean }) {
  return (
    <div className={compact ? "" : "rounded-lg border border-neutral-200 bg-white p-3 dark:border-neutral-800 dark:bg-neutral-900"}>
      <div className="text-xs text-neutral-500 dark:text-neutral-400">{label}</div>
      <div className="mt-0.5 text-base font-semibold tabular-nums text-neutral-900 dark:text-neutral-50">
        {value}
      </div>
      {sub && <div className="text-xs text-neutral-400">{sub}</div>}
    </div>
  );
}
