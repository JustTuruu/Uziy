import { cn } from "@/lib/utils";
import type { ReactNode } from "react";
import { Card } from "@/components/ui/card";

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
    <Card className={cn("p-5", className)}>
      <div className="flex items-start justify-between">
        <div className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-secondary)]">
          {label}
        </div>
        {icon && <div className="text-[var(--color-text-muted)]">{icon}</div>}
      </div>
      <div className="mt-2 text-2xl font-extrabold tracking-tight text-[var(--color-text-primary)]">
        {value}
      </div>
      {(hint || trend) && (
        <div className="mt-2 flex items-center gap-2 text-xs text-[var(--color-text-secondary)]">
          {trend && (
            <span
              className={cn(
                "inline-flex items-center gap-1 font-semibold",
                trend.direction === "up"
                  ? "text-[var(--color-success)]"
                  : "text-[var(--color-danger)]",
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
