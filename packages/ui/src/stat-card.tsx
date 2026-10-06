import { cn } from "./cn";
import type { ReactNode } from "react";
import { Card } from "./card";

export function StatCard({
  label,
  value,
  hint,
  icon,
  trend,
  className,
}: {
  label: string;
  value: ReactNode;
  hint?: ReactNode;
  icon?: ReactNode;
  trend?: { direction: "up" | "down"; value: string };
  className?: string;
}) {
  return (
    <Card className={cn("relative overflow-hidden p-5", className)}>
      {/* hairline accent along the top edge */}
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-[color-mix(in_oklab,var(--color-primary)_45%,transparent)] to-transparent" />
      <div className="flex items-center justify-between">
        <div className="text-xs font-medium text-[var(--color-text-secondary)]">
          {label}
        </div>
        {icon && (
          <div className="flex h-7 w-7 items-center justify-center rounded-md border border-[var(--color-divider)] bg-[var(--color-surface-elevated)] text-[var(--color-text-secondary)]">
            {icon}
          </div>
        )}
      </div>
      <div className="mt-3 text-[28px] font-semibold leading-none tracking-tight tabular-nums text-[var(--color-text-primary)]">
        {value}
      </div>
      {(hint || trend) && (
        <div className="mt-3 flex items-center gap-2 text-xs text-[var(--color-text-muted)]">
          {trend && (
            <span
              className={cn(
                "inline-flex items-center gap-1 rounded px-1.5 py-0.5 font-semibold",
                trend.direction === "up"
                  ? "bg-[color-mix(in_oklab,var(--color-success)_12%,transparent)] text-[var(--color-success)]"
                  : "bg-[color-mix(in_oklab,var(--color-danger)_12%,transparent)] text-[var(--color-danger)]",
              )}
            >
              {trend.direction === "up" ? "↑" : "↓"} {trend.value}
            </span>
          )}
          {hint}
        </div>
      )}
    </Card>
  );
}
