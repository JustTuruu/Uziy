import { HERO } from "@/lib/content";
import type { SiteLinks } from "@/lib/links";
import { PhoneDemo } from "./phone-demo";
import { StoreButtons } from "./store-buttons";

/** Splits the headline so the accent phrase can be set in gold italics. */
function Headline({ title, accent }: { title: string; accent: string }) {
  const [before, after = ""] = title.split(accent);
  return (
    <>
      {before}
      <span className="accent">{accent}</span>
      {after}
    </>
  );
}

export function Hero({ links }: { links: SiteLinks }) {
  return (
    <section id="top" className="relative overflow-hidden px-4 pb-20 pt-12 sm:px-6 sm:pb-28 sm:pt-20">
      <div aria-hidden className="grid-backdrop absolute inset-0 -z-10" />
      <div
        aria-hidden
        className="absolute -right-40 -top-40 -z-10 size-[640px] rounded-full bg-[radial-gradient(closest-side,rgb(245_197_24/0.13),transparent)]"
      />
      <div className="mx-auto grid max-w-6xl items-center gap-16 lg:grid-cols-[1.25fr_1fr]">
        <div>
          <span
            className="rise inline-flex items-center gap-2 rounded-full border border-[var(--color-border-strong)] bg-[var(--color-surface)]/70 px-3.5 py-1.5 text-xs text-[var(--color-text-secondary)] backdrop-blur"
            style={{ "--d": "0s" } as React.CSSProperties}
          >
            <span className="size-1.5 rounded-full bg-[var(--color-primary)] shadow-[0_0_10px_var(--color-primary)]" />
            {HERO.badge}
          </span>
          <h1
            className="rise font-display mt-6 text-[2.6rem] font-semibold leading-[1.06] sm:text-6xl lg:text-[4.4rem]"
            style={{ "--d": "0.1s" } as React.CSSProperties}
          >
            <Headline title={HERO.title} accent={HERO.accent} />
          </h1>
          <p
            className="rise mt-6 max-w-xl text-lg leading-relaxed text-[var(--color-text-secondary)]"
            style={{ "--d": "0.22s" } as React.CSSProperties}
          >
            {HERO.subtitle}
          </p>
          <div className="rise mt-9" style={{ "--d": "0.34s" } as React.CSSProperties}>
            <StoreButtons links={links} />
          </div>
        </div>
        <div className="rise" style={{ "--d": "0.25s" } as React.CSSProperties}>
          <PhoneDemo />
        </div>
      </div>
    </section>
  );
}
