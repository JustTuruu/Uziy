import { cn } from "./cn";
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
    "bg-[color-mix(in_oklab,var(--color-success)_10%,transparent)] text-[var(--color-success)] border-[color-mix(in_oklab,var(--color-success)_22%,transparent)]",
  danger:
    "bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] text-[var(--color-danger)] border-[color-mix(in_oklab,var(--color-danger)_22%,transparent)]",
  warning:
    "bg-[color-mix(in_oklab,var(--color-warning)_10%,transparent)] text-[var(--color-warning)] border-[color-mix(in_oklab,var(--color-warning)_22%,transparent)]",
  info: "bg-[color-mix(in_oklab,var(--color-accent)_10%,transparent)] text-[var(--color-accent)] border-[color-mix(in_oklab,var(--color-accent)_22%,transparent)]",
  primary:
    "bg-[color-mix(in_oklab,var(--color-primary)_10%,transparent)] text-[var(--color-primary)] border-[color-mix(in_oklab,var(--color-primary)_22%,transparent)]",
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
        "inline-flex items-center gap-1.5 rounded-md border px-2 py-0.5 text-[11px] font-semibold leading-5 before:h-1.5 before:w-1.5 before:rounded-full before:bg-current before:opacity-80 before:content-['']",
        tones[tone],
        className,
      )}
    >
      {children}
    </span>
  );
}
