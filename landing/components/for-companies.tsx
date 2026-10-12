import { ArrowRight, Check } from "lucide-react";
import { ButtonLink } from "@uziy/ui";
import { COMPANIES } from "@/lib/content";

export function ForCompanies({ companyPanelUrl }: { companyPanelUrl: string }) {
  return (
    <section id="companies" className="px-4 py-16 sm:px-6 sm:py-24">
      <div className="mx-auto max-w-6xl rounded-2xl border border-[var(--color-border-strong)] bg-[var(--color-surface)] p-8 sm:p-12">
        <h2 className="max-w-2xl text-2xl font-semibold tracking-tight sm:text-4xl">
          {COMPANIES.title}
        </h2>
        <p className="mt-4 max-w-2xl text-[var(--color-text-secondary)]">
          {COMPANIES.text}
        </p>
        <ul className="mt-6 space-y-2">
          {COMPANIES.points.map((point) => (
            <li key={point} className="flex items-start gap-2 text-sm">
              <Check
                size={18}
                aria-hidden
                className="mt-0.5 shrink-0 text-[var(--color-success)]"
              />
              {point}
            </li>
          ))}
        </ul>
        <ButtonLink
          href={companyPanelUrl}
          size="lg"
          className="mt-8"
          rightIcon={<ArrowRight size={18} aria-hidden />}
        >
          Кампанит ажил эхлүүлэх
        </ButtonLink>
      </div>
    </section>
  );
}
