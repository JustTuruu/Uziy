import { MessageSquareText, Shield, Target, Timer } from "lucide-react";
import { BENEFITS, type Benefit } from "@/lib/content";
import { Section } from "./section";

const ICONS: Record<Benefit["icon"], typeof Target> = {
  target: Target,
  message: MessageSquareText,
  timer: Timer,
  shield: Shield,
};

export function Benefits() {
  return (
    <Section id="benefits" title="Яагаад Uziy вэ?" className="bg-[var(--color-surface)]">
      <ul className="grid gap-6 sm:grid-cols-2">
        {BENEFITS.map((benefit) => {
          const Icon = ICONS[benefit.icon];
          return (
            <li key={benefit.title} className="flex gap-4">
              <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-[var(--color-surface-elevated)] text-[var(--color-primary)]">
                <Icon size={22} aria-hidden />
              </span>
              <div>
                <h3 className="font-semibold">{benefit.title}</h3>
                <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
                  {benefit.text}
                </p>
              </div>
            </li>
          );
        })}
      </ul>
    </Section>
  );
}
