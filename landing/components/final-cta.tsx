import { FINAL_CTA } from "@/lib/content";
import type { SiteLinks } from "@/lib/links";
import { StoreButtons } from "./store-buttons";

/** Closing call to action with the store buttons repeated. */
export function FinalCta({ links }: { links: SiteLinks }) {
  return (
    <section className="relative overflow-hidden px-4 py-24 text-center sm:px-6 sm:py-32">
      <div
        aria-hidden
        className="absolute inset-x-0 bottom-0 -z-10 h-[420px] bg-[radial-gradient(ellipse_60%_100%_at_50%_100%,rgb(245_197_24/0.16),transparent)]"
      />
      <div className="reveal mx-auto max-w-3xl">
        <h2 className="font-display text-4xl font-semibold leading-tight sm:text-6xl">
          {FINAL_CTA.title}
        </h2>
        <p className="mx-auto mt-5 max-w-xl text-lg text-[var(--color-text-secondary)]">
          {FINAL_CTA.text}
        </p>
        <div className="mt-9 flex justify-center">
          <StoreButtons links={links} />
        </div>
      </div>
    </section>
  );
}
