import { STEPS } from "@/lib/content";
import { Section } from "./section";

export function HowItWorks() {
  return (
    <Section
      id="how"
      title="Хэрхэн ажилладаг вэ?"
      lead="Бүртгүүлээд, танд хамаатай танилцуулгыг үзэж, санал бодлоо хэлэхэд хэдхэн минут л хангалттай."
    >
      <ol className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {STEPS.map((step, index) => (
          <li
            key={step.title}
            className="rounded-xl border border-[var(--color-divider)] bg-[var(--color-surface)] p-5"
          >
            <span className="grid size-8 place-items-center rounded-lg bg-[var(--color-surface-elevated)] text-sm font-semibold text-[var(--color-primary)]">
              {index + 1}
            </span>
            <h3 className="mt-4 font-semibold">{step.title}</h3>
            <p className="mt-2 text-sm text-[var(--color-text-secondary)]">
              {step.text}
            </p>
          </li>
        ))}
      </ol>
    </Section>
  );
}
