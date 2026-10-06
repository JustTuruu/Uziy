import { cn } from "./cn";

export interface SegmentOption<T extends string> {
  value: T;
  label: string;
}

/** Compact single-choice toggle group (filters, gender, …). */
export function SegmentedControl<T extends string>({
  options,
  value,
  onChange,
  label,
  className,
}: {
  options: readonly SegmentOption<T>[];
  value: T;
  onChange: (value: T) => void;
  /** Accessible name of the group. */
  label?: string;
  className?: string;
}) {
  return (
    <div
      role="radiogroup"
      aria-label={label}
      className={cn(
        "inline-flex gap-1 rounded-lg border border-[var(--color-divider)] bg-[var(--color-surface)] p-1",
        className,
      )}
    >
      {options.map((o) => {
        const selected = o.value === value;
        return (
          <button
            key={o.value}
            type="button"
            role="radio"
            aria-checked={selected}
            onClick={() => onChange(o.value)}
            className={cn(
              "rounded-md px-3 py-1.5 text-xs font-semibold transition-colors",
              selected
                ? "bg-[var(--color-primary)] text-[#14110a]"
                : "text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]",
            )}
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}
