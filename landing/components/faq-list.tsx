import { ChevronDown } from "lucide-react";
import { FAQS } from "@/lib/content";
import { Section } from "./section";

/** Native <details>: keyboard and screen-reader friendly with no client JS. */
export function FaqList() {
  return (
    <Section id="faq" title="Түгээмэл асуулт">
      <div className="max-w-3xl divide-y divide-[var(--color-divider)] rounded-xl border border-[var(--color-divider)] bg-[var(--color-surface)]">
        {FAQS.map((faq) => (
          <details key={faq.question} className="group px-5 py-4">
            <summary className="flex cursor-pointer list-none items-center justify-between gap-4 font-medium [&::-webkit-details-marker]:hidden">
              {faq.question}
              <ChevronDown
                size={18}
                aria-hidden
                className="shrink-0 text-[var(--color-text-muted)] transition-transform group-open:rotate-180"
              />
            </summary>
            <p className="mt-3 text-sm text-[var(--color-text-secondary)]">
              {faq.answer}
            </p>
          </details>
        ))}
      </div>
    </Section>
  );
}
