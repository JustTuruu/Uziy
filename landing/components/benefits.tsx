import { Check, Lock } from "lucide-react";
import { BENEFITS, type Benefit } from "@/lib/content";
import { cn } from "@uziy/ui";
import { Section } from "./section";

const CHIPS = [
  { label: "Нас 18–24", on: true },
  { label: "Эмэгтэй", on: true },
  { label: "Улаанбаатар", on: true },
  { label: "Нас 45+", on: false },
  { label: "Дархан", on: false },
];

const BARS = [72, 44, 28];

/** Little illustrations, one per benefit; decorative, so hidden from assistive tech. */
const VISUALS: Record<Benefit["icon"], () => React.ReactNode> = {
  target: () => (
    <div className="flex flex-wrap gap-2">
      {CHIPS.map((chip) => (
        <span
          key={chip.label}
          className={cn(
            "rounded-full border px-3 py-1.5 text-xs",
            chip.on
              ? "border-[var(--color-primary)] bg-[rgb(245_197_24/0.12)] text-[var(--color-primary)]"
              : "border-[var(--color-divider)] text-[var(--color-text-muted)]",
          )}
        >
          {chip.label}
        </span>
      ))}
    </div>
  ),
  message: () => (
    <div className="flex h-24 items-end gap-3">
      {BARS.map((height, index) => (
        <div
          key={height}
          style={{ height: `${height}%` }}
          className={cn(
            "w-10 rounded-t-lg",
            index === 0
              ? "bg-[image:var(--gradient-gold)]"
              : "bg-[var(--color-surface-hover)]",
          )}
        />
      ))}
    </div>
  ),
  timer: () => (
    <p className="font-display text-5xl font-semibold italic text-[var(--color-primary)]">
      0:30<span className="px-2 text-[var(--color-border-strong)]">–</span>2:00
    </p>
  ),
  shield: () => (
    <div className="flex items-center gap-3">
      <span className="grid size-12 place-items-center rounded-2xl border border-[var(--color-primary)] bg-[var(--color-surface-elevated)] text-[var(--color-primary)] shadow-[0_0_28px_rgb(245_197_24/0.25)]">
        <Check size={22} strokeWidth={3} />
      </span>
      <span className="grid size-12 place-items-center rounded-2xl border border-[var(--color-divider)] text-[var(--color-text-muted)]">
        <Lock size={20} />
      </span>
    </div>
  ),
};

/** Wide tiles sit on the diagonal so the grid reads as a bento, not a table. */
const TILE_SPAN: Record<Benefit["icon"], string> = {
  target: "lg:col-span-2",
  message: "",
  timer: "",
  shield: "lg:col-span-2",
};

export function Benefits() {
  return (
    <Section
      id="benefits"
      eyebrow="Давуу тал"
      title="Яагаад Uziy вэ?"
      className="bg-[var(--color-surface)]"
    >
      <ul className="grid gap-5 lg:grid-cols-3">
        {BENEFITS.map((benefit) => (
          <li
            key={benefit.title}
            className={cn(
              "reveal group relative flex flex-col justify-between gap-10 overflow-hidden rounded-3xl border border-[var(--color-divider)] bg-[var(--color-background)] p-7 transition-colors hover:border-[var(--color-border-strong)] sm:p-9",
              TILE_SPAN[benefit.icon],
            )}
          >
            <div
              aria-hidden
              className="pointer-events-none absolute -right-24 -top-24 size-64 rounded-full bg-[radial-gradient(closest-side,rgb(245_197_24/0.10),transparent)] opacity-0 transition-opacity duration-500 group-hover:opacity-100"
            />
            <div aria-hidden>{VISUALS[benefit.icon]()}</div>
            <div>
              <h3 className="font-display text-2xl font-semibold">{benefit.title}</h3>
              <p className="mt-2 max-w-md text-[var(--color-text-secondary)]">{benefit.text}</p>
            </div>
          </li>
        ))}
      </ul>
    </Section>
  );
}
