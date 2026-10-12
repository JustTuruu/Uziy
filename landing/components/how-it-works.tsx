import { STEPS } from "@/lib/content";
import { Section } from "./section";

/** Editorial numbered rows: big serif numerals, hairlines, a gold wash on hover. */
export function HowItWorks() {
  return (
    <Section
      id="how"
      eyebrow="Үйл явц"
      title="Хэрхэн ажилладаг вэ?"
      lead="Бүртгүүлээд, танд хамаатай танилцуулгыг үзэж, санал бодлоо хэлэхэд хэдхэн минут л хангалттай."
    >
      <ol className="border-t border-[var(--color-divider)]">
        {STEPS.map((step, index) => (
          <li
            key={step.title}
            className="reveal group grid items-baseline gap-x-8 gap-y-2 border-b border-[var(--color-divider)] px-2 py-8 transition-colors hover:bg-[linear-gradient(90deg,rgb(245_197_24/0.07),transparent_70%)] sm:grid-cols-[7rem_1fr_1.4fr] sm:px-6"
          >
            <span className="font-display text-5xl font-medium italic text-[var(--color-border-strong)] transition-colors group-hover:text-[var(--color-primary)] sm:text-6xl">
              {String(index + 1).padStart(2, "0")}
            </span>
            <h3 className="font-display text-2xl font-semibold sm:text-3xl">{step.title}</h3>
            <p className="max-w-md text-[var(--color-text-secondary)]">{step.text}</p>
          </li>
        ))}
      </ol>
    </Section>
  );
}
