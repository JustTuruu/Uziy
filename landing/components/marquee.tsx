import { MARQUEE_WORDS } from "@/lib/content";

/** Endless ribbon of the page's promises; the list is doubled so the loop is seamless. */
export function Marquee() {
  const loop = [...MARQUEE_WORDS, ...MARQUEE_WORDS];
  return (
    <div
      aria-hidden
      className="overflow-hidden border-y border-[var(--color-divider)] bg-[var(--color-surface)] py-5"
    >
      <div className="marquee-track flex w-max items-center gap-10 whitespace-nowrap">
        {loop.map((word, index) => (
          <span key={index} className="flex items-center gap-10">
            <span className="font-display text-2xl italic text-[var(--color-text-secondary)] sm:text-3xl">
              {word}
            </span>
            <span className="size-2 rotate-45 bg-[var(--color-primary)]" />
          </span>
        ))}
      </div>
    </div>
  );
}
