import { Plus } from "lucide-react";
import { FAQS } from "@/lib/content";

/** Native <details>: keyboard and screen-reader friendly with no client JS. */
export function FaqList() {
  return (
    <section id="faq" className="px-4 py-20 sm:px-6 sm:py-28">
      <div className="mx-auto grid max-w-6xl gap-12 lg:grid-cols-[1fr_1.6fr]">
        <div className="reveal lg:sticky lg:top-28 lg:self-start">
          <p className="mb-4 flex items-center gap-3 text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-primary)]">
            <span className="h-px w-8 bg-[var(--color-primary)]" />
            Асуулт хариулт
          </p>
          <h2 className="font-display text-3xl font-semibold leading-tight sm:text-5xl">
            Түгээмэл асуулт
          </h2>
        </div>
        <div className="border-t border-[var(--color-divider)]">
          {FAQS.map((faq) => (
            <details key={faq.question} className="reveal group border-b border-[var(--color-divider)]">
              <summary className="flex cursor-pointer list-none items-center justify-between gap-6 py-6 text-lg font-medium transition-colors hover:text-[var(--color-primary)] [&::-webkit-details-marker]:hidden">
                {faq.question}
                <span className="grid size-8 shrink-0 place-items-center rounded-full border border-[var(--color-border-strong)] transition-all group-open:rotate-45 group-open:border-[var(--color-primary)] group-open:text-[var(--color-primary)]">
                  <Plus size={16} aria-hidden />
                </span>
              </summary>
              <p className="max-w-2xl pb-6 text-[var(--color-text-secondary)]">{faq.answer}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
