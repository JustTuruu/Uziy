"use client";
import { useEffect } from "react";
import { MOTION_ATTRIBUTE, REVEAL_SELECTOR, REVEALED_CLASS } from "@/lib/reveal";

/** Reveal when the top of a part is about 90 % of the way down the screen. */
const REVEAL_MARGIN = "0px 0px -10% 0px";

/** Marks every entry now on screen as revealed and stops watching it: each part arrives once. */
export function revealIntersecting(entries: IntersectionObserverEntry[], observer: IntersectionObserver) {
  for (const entry of entries) {
    if (!entry.isIntersecting) continue;
    entry.target.classList.add(REVEALED_CLASS);
    observer.unobserve(entry.target);
  }
}

function prefersReducedMotion(): boolean {
  return typeof window.matchMedia === "function" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

/**
 * Pattern: Observer — section parts marked `data-reveal` rise into place as they scroll into view. Motion is
 * switched on here, by script, so a failed script or a reduced-motion visitor sees the finished page.
 */
export function MotionLayer() {
  useEffect(() => {
    if (prefersReducedMotion() || typeof IntersectionObserver === "undefined") return;
    const root = document.documentElement;
    root.setAttribute(MOTION_ATTRIBUTE, "on");
    const observer = new IntersectionObserver(revealIntersecting, { rootMargin: REVEAL_MARGIN });
    document.querySelectorAll(REVEAL_SELECTOR).forEach((el) => observer.observe(el));
    return () => {
      observer.disconnect();
      root.removeAttribute(MOTION_ATTRIBUTE);
    };
  }, []);
  return null;
}
