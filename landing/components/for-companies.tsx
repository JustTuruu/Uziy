import { ArrowRight, Check } from "lucide-react";
import { ButtonLink } from "@uziy/ui";
import { COMPANIES } from "@/lib/content";

const RESULT_BARS = [
  { label: "Тийм", width: "78%" },
  { label: "Магадгүй", width: "46%" },
  { label: "Үгүй", width: "22%" },
];

/** Illustrative result card: shape of the company dashboard, no real figures. */
function ResultsMock() {
  return (
    <div
      aria-hidden
      className="rounded-2xl border border-[var(--color-border-strong)] bg-[var(--color-background)] p-6 shadow-[0_30px_70px_rgb(0_0_0/0.5)]"
    >
      <p className="text-[11px] uppercase tracking-widest text-[var(--color-text-muted)]">
        Хариултын хуваарилалт
      </p>
      <div className="mt-5 space-y-4">
        {RESULT_BARS.map((bar, index) => (
          <div key={bar.label}>
            <p className="mb-1.5 text-xs text-[var(--color-text-secondary)]">{bar.label}</p>
            <div className="h-2.5 rounded-full bg-[var(--color-surface-elevated)]">
              <div
                style={{ width: bar.width }}
                className={
                  index === 0
                    ? "h-full rounded-full bg-[image:var(--gradient-gold)]"
                    : "h-full rounded-full bg-[var(--color-surface-hover)]"
                }
              />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

export function ForCompanies({ companyPanelUrl }: { companyPanelUrl: string }) {
  return (
    <section id="companies" className="px-4 py-20 sm:px-6 sm:py-28">
      <div className="reveal relative mx-auto max-w-6xl overflow-hidden rounded-[2rem] border border-[var(--color-border-strong)] bg-[var(--color-surface)] p-8 sm:p-14">
        <div
          aria-hidden
          className="absolute -left-32 -top-32 size-[420px] rounded-full bg-[radial-gradient(closest-side,rgb(245_197_24/0.14),transparent)]"
        />
        <div className="relative grid items-center gap-12 lg:grid-cols-[1.2fr_1fr]">
          <div>
            <p className="mb-4 flex items-center gap-3 text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-primary)]">
              <span className="h-px w-8 bg-[var(--color-primary)]" />
              Компаниудад
            </p>
            <h2 className="font-display text-3xl font-semibold leading-tight sm:text-5xl">
              {COMPANIES.title}
            </h2>
            <p className="mt-5 max-w-xl text-[var(--color-text-secondary)]">{COMPANIES.text}</p>
            <ul className="mt-7 space-y-3">
              {COMPANIES.points.map((point) => (
                <li key={point} className="flex items-start gap-3 text-sm">
                  <span className="mt-0.5 grid size-5 shrink-0 place-items-center rounded-full bg-[rgb(52_211_153/0.15)] text-[var(--color-success)]">
                    <Check size={12} strokeWidth={3} aria-hidden />
                  </span>
                  {point}
                </li>
              ))}
            </ul>
            <ButtonLink
              href={companyPanelUrl}
              size="lg"
              className="mt-9"
              rightIcon={<ArrowRight size={18} aria-hidden />}
            >
              Кампанит ажил эхлүүлэх
            </ButtonLink>
          </div>
          <ResultsMock />
        </div>
      </div>
    </section>
  );
}
