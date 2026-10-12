import { formatPercent, share, sliceTotal } from "@/lib/analytics";
import type { AnalyticsSlice } from "@/lib/api";
import { formatNumber } from "@/lib/utils";

/**
 * A ranking of labelled counts as horizontal bars with the value written
 * out beside each — a gender split, age bands, cities, the answers to a
 * question. The rows differ by name, not by colour, so a single hue is used.
 *
 * The share is of the list's own total unless `total` is given (a question's
 * `answered`, where a multi-choice list adds up to more than 100%).
 */
export function DistributionBars({
  title,
  slices,
  total,
  showTitle = true,
  formatLabel = (label) => label,
}: {
  /** Names the list; also its accessible name when [showTitle] is false. */
  title: string;
  /** False when a heading right above already says it (a question's prompt). */
  showTitle?: boolean;
  slices: readonly AnalyticsSlice[];
  total?: number;
  formatLabel?: (label: string) => string;
}) {
  const base = total ?? sliceTotal(slices);
  const widest = Math.max(1, ...slices.map((s) => s.count));

  return (
    <section aria-label={title}>
      {showTitle && (
        <h3 className="mb-3 text-xs font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
          {title}
        </h3>
      )}
      {slices.length === 0 ? (
        <p className="text-sm text-[var(--color-text-muted)]">Өгөгдөл алга.</p>
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
                  style={{ width: `${(s.count / widest) * 100}%` }}
                />
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
