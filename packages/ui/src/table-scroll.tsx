import { cn } from "./cn";
import type { HTMLAttributes } from "react";

/**
 * Holds a data table. A table wider than its card scrolls sideways inside the card instead of widening the whole
 * page (on a 1024px laptop the users table pushed the page 130px wide, 2026-10-22). Focusable and named so a
 * keyboard user can scroll it too.
 */
export function TableScroll({
  className,
  children,
  "aria-label": label = "Хүснэгт",
  ...rest
}: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      {...rest}
      role="region"
      aria-label={label}
      tabIndex={0}
      className={cn("overflow-x-auto focus-visible:outline-2 focus-visible:outline-[var(--color-primary)]", className)}
    >
      {children}
    </div>
  );
}
