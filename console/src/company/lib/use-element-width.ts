import { useEffect, useRef, useState } from "react";

/**
 * The pixel width of an element, kept up to date as it resizes. Charts draw
 * at this width so their text stays its real size on a wide screen instead of
 * scaling up with the picture. `fallback` is used until the first measurement
 * (and where ResizeObserver does not exist).
 */
export function useElementWidth<T extends HTMLElement>(fallback: number) {
  const ref = useRef<T>(null);
  const [width, setWidth] = useState(fallback);

  useEffect(() => {
    const el = ref.current;
    if (!el || typeof ResizeObserver === "undefined") return;
    const observer = new ResizeObserver(([entry]) => {
      const w = Math.round(entry.contentRect.width);
      if (w > 0) setWidth(w);
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return { ref, width };
}
