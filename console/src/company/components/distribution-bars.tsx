import { formatPercent, share, sliceTotal } from "@company/lib/analytics";
import type { AnalyticsSlice } from "@company/lib/api";
import { formatNumber } from "@company/lib/utils";

const NO_DATA = "Өгөгдөл алга.";

/**
 * A ranking of labelled counts as horizontal bars with the value written
 * out beside each — a gender split, age bands, cities, the answers to a
 * question. The rows differ by name, not by colour, so a single hue is used.
 *
 * The share is of the list's own total unless `total` is given (a question's
 * `answered`, where a multi-choice list adds up to more than 100%).
 *
 * Bars are drawn against the largest row (`scale="widest"`, a ranking) or as
 * the share itself (`scale="share"`, so 40% fills 40% of the track — what a
 * question's answers need, or a lone answer would look like everyone's).
 */
export function DistributionBars({
  title,
  slices,
  total,
  showTitle = true,
  formatLabel = (label) => label,
  emptyText = NO_DATA,
  scale = "widest",
}: {
  /** Names the list; also its accessible name when [showTitle] is false. */
  title: string;
  /** False when a heading right above already says it (a question's prompt). */
  showTitle?: boolean;
  slices: readonly AnalyticsSlice[];
  total?: number;
  formatLabel?: (label: string) => string;
  /** Said instead of the bars when there are none (e.g. why they are withheld). */
  emptyText?: string;
  scale?: "widest" | "share";
}) {
  const base = total ?? sliceTotal(slices);
  const widest = Math.max(1, ...slices.map((s) => s.count));
  const fill = (count: number) =>
    scale === "share" ? Math.min(100, share(count, base)) : (count / widest) * 100;

  return (
    <section aria-label={title}>
      {showTitle && (
        <h3 className="mb-3 text-xs font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
          {title}
        </h3>
      )}
      {slices.length === 0 ? (
        <p className="text-sm text-[var(--color-text-muted)]">{emptyText}</p>
      ) : (
        <ul className="space-y-3">
          {slices.map((s) => (
            <li key={s.label}>
              <div className="mb-1 flex items-baseline justify-between gap-3 text-sm">
                <span className="truncate text-[var(--color-text-primary)]">
                  {formatLabel(s.label)}
                </span>
                <span className="shrink-0 font-mono text-xs tabular-nums text-[var(--color-text-secondary)]">
                  {formatNumber(s.count)} · {formatPercent(share(s.count, base))}
                </span>
              </div>
              <div className="h-2 rounded-full bg-[var(--color-surface-elevated)]">
                <div
                  className="h-2 rounded-full bg-[var(--color-primary)]"
                  style={{ width: `${fill(s.count)}%` }}
                />
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
