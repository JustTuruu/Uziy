import { clsx, type ClassValue } from "clsx";
import { extendTailwindMerge } from "tailwind-merge";

/**
 * Font-size steps theme.css adds to Tailwind's scale (`text-2xs`, `text-ui`, …).
 * tailwind-merge must know them as SIZES: otherwise it takes `text-ui` for a
 * colour and drops it next to `text-[var(--color-…)]`.
 */
export const EXTRA_TEXT_SIZES = ["4xs", "3xs", "2xs", "ui"];

const twMerge = extendTailwindMerge({
  extend: { theme: { text: EXTRA_TEXT_SIZES } },
});

/** Joins class names and resolves conflicting Tailwind utilities. */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
