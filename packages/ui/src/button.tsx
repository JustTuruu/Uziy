import { cn } from "./cn";
import type { ButtonHTMLAttributes, ReactNode } from "react";

type Variant = "primary" | "secondary" | "ghost" | "danger" | "success";
type Size = "sm" | "md" | "lg";

interface Props extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
  leftIcon?: ReactNode;
  rightIcon?: ReactNode;
}

const variants: Record<Variant, string> = {
  primary:
    "bg-[var(--color-primary)] text-[#14110a] shadow-[0_1px_0_rgb(255_255_255/0.35)_inset,0_1px_2px_rgb(0_0_0/0.4)] hover:bg-[var(--color-primary-dark)] disabled:bg-[var(--color-surface-elevated)] disabled:text-[var(--color-text-muted)]",
  secondary:
    "bg-[var(--color-surface-elevated)] text-[var(--color-text-primary)] hover:bg-[var(--color-surface-hover)] border border-[var(--color-border-strong)]",
  ghost:
    "bg-transparent text-[var(--color-text-primary)] hover:bg-[var(--color-surface-elevated)]",
  danger:
    "bg-[var(--color-danger)] text-white hover:brightness-110 disabled:opacity-40",
  success:
    "bg-[var(--color-success)] text-[#04120c] hover:brightness-110 disabled:opacity-40",
};

const sizes: Record<Size, string> = {
  sm: "h-7 px-2.5 text-xs rounded-md",
  md: "h-9 px-3.5 text-[13px] rounded-lg",
  lg: "h-11 px-5 text-sm rounded-lg",
};

export function Button({
  variant = "primary",
  size = "md",
  leftIcon,
  rightIcon,
  className,
  children,
  ...rest
}: Props) {
  return (
    <button
      {...rest}
      className={cn(
        "inline-flex items-center justify-center gap-2 font-semibold transition-colors",
        "focus:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-primary)] focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--color-background)]",
        "disabled:cursor-not-allowed",
        variants[variant],
        sizes[size],
        className,
      )}
    >
      {leftIcon}
      {children}
      {rightIcon}
    </button>
  );
}
