import type { CSSProperties } from "react";

/**
 * Shared by server-rendered sections and the client motion layer. It must not live in the "use client" file: a
 * server component that imports a plain function from there gets a client reference, and calling it fails.
 */
export const MOTION_ATTRIBUTE = "data-motion";
export const REVEAL_SELECTOR = "[data-reveal]";
export const REVEALED_CLASS = "is-revealed";

/** Place of a part inside its section; the CSS turns it into the stagger delay. */
export function revealOrder(order: number): CSSProperties {
  return { "--reveal-order": order } as CSSProperties;
}
