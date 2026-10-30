/** One labelled horizontal bar: [label] … [value], filled to [fraction] (0..1). */
export function ShareBar({
  label,
  value,
  fraction,
}: {
  label: string;
  value: string;
  fraction: number | null;
}) {
  const width = fraction === null ? 0 : Math.max(0, Math.min(1, fraction));
  return (
    <div className="space-y-1">
      <div className="flex items-baseline justify-between gap-3 text-sm">
        <span className="truncate text-[var(--color-text-primary)]">{label}</span>
        <span className="shrink-0 tabular-nums text-[var(--color-text-secondary)]">
          {value}
        </span>
      </div>
      <div className="h-2 overflow-hidden rounded-full bg-[var(--color-surface-elevated)]">
        <div
          className="h-full rounded-full bg-[var(--color-primary)]"
          style={{ width: `${width * 100}%` }}
        />
      </div>
    </div>
  );
}
