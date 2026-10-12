import { HERO } from "@/lib/content";
import type { SiteLinks } from "@/lib/links";
import { PhoneMock } from "./phone-mock";
import { StoreButtons } from "./store-buttons";

export function Hero({ links }: { links: SiteLinks }) {
  return (
    <section id="top" className="px-4 pb-16 pt-14 sm:px-6 sm:pb-24 sm:pt-24">
      <div className="mx-auto grid max-w-6xl items-center gap-12 lg:grid-cols-[1.2fr_1fr]">
        <div>
          <span className="inline-block rounded-full border border-[var(--color-border-strong)] px-3 py-1 text-xs text-[var(--color-text-secondary)]">
            {HERO.badge}
          </span>
          <h1 className="mt-5 text-4xl font-semibold leading-[1.1] tracking-tight sm:text-6xl">
            {HERO.title}
          </h1>
          <p className="mt-5 max-w-xl text-lg text-[var(--color-text-secondary)]">
            {HERO.subtitle}
          </p>
          <div className="mt-8">
            <StoreButtons links={links} />
          </div>
        </div>
        <PhoneMock />
      </div>
    </section>
  );
}
