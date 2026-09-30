import { cn } from "@/lib/utils";
import type { ReactNode } from "react";

export type BadgeTone =
  | "neutral"
  | "success"
  | "danger"
  | "warning"
  | "info"
  | "primary";

const tones: Record<BadgeTone, string> = {
  neutral:
    "bg-[var(--color-surface-elevated)] text-[var(--color-text-secondary)] border-[var(--color-divider)]",
  success:
    "bg-[color-mix(in_oklab,var(--color-success)_15%,transparent)] text-[var(--color-success)] border-[color-mix(in_oklab,var(--color-success)_35%,transparent)]",
  danger:
    "bg-[color-mix(in_oklab,var(--color-danger)_15%,transparent)] text-[var(--color-danger)] border-[color-mix(in_oklab,var(--color-danger)_35%,transparent)]",
  warning:
    "bg-[color-mix(in_oklab,var(--color-warning)_15%,transparent)] text-[var(--color-warning)] border-[color-mix(in_oklab,var(--color-warning)_35%,transparent)]",
  info: "bg-[color-mix(in_oklab,var(--color-accent)_15%,transparent)] text-[var(--color-accent)] border-[color-mix(in_oklab,var(--color-accent)_35%,transparent)]",
  primary:
    "bg-[color-mix(in_oklab,var(--color-primary)_15%,transparent)] text-[var(--color-primary)] border-[color-mix(in_oklab,var(--color-primary)_35%,transparent)]",
};

export function Badge({
  tone = "neutral",
  children,
  className,
}: {
  tone?: BadgeTone;
  children: ReactNode;
  className?: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold",
        tones[tone],
        className,
      )}
    >
      {children}
    </span>
  );
}
