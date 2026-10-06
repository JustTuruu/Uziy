import type { ButtonHTMLAttributes, ReactNode } from "react";
import { cn } from "./cn";

interface Props extends ButtonHTMLAttributes<HTMLButtonElement> {
  /** Required: icon-only buttons have no text for screen readers. */
  label: string;
  children: ReactNode;
  tone?: "neutral" | "danger";
}

/** Square icon-only button (delete, close, …). */
export function IconButton({
  label,
  tone = "neutral",
  className,
  children,
  ...rest
}: Props) {
  return (
    <button
      type="button"
      {...rest}
      aria-label={label}
      title={label}
      className={cn(
        "inline-flex h-8 w-8 items-center justify-center rounded-md text-[var(--color-text-muted)] transition-colors hover:bg-[var(--color-surface-elevated)]",
        tone === "danger"
          ? "hover:text-[var(--color-danger)]"
          : "hover:text-[var(--color-text-primary)]",
        className,
      )}
    >
      {children}
    </button>
  );
}
