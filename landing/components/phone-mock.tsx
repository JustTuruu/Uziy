import { Check } from "lucide-react";

const OPTIONS = ["Тийм, сонирхож байна", "Магадгүй", "Үгүй"];
const SELECTED_OPTION = 0;

/** Decorative phone showing one survey question; drawn in CSS so no screenshot goes stale. */
export function PhoneMock() {
  return (
    <div
      aria-hidden
      className="relative mx-auto w-[260px] rounded-[2.5rem] border border-[var(--color-border-strong)] bg-[var(--color-surface)] p-3 shadow-[0_30px_80px_rgb(0_0_0/0.55),0_0_80px_rgb(245_197_24/0.12)]"
    >
      <div className="flex flex-col gap-4 rounded-[2rem] bg-[var(--color-background)] px-5 pb-8 pt-8">
        <div>
          <p className="text-[11px] text-[var(--color-text-muted)]">
            Асуулт 2 / 3
          </p>
          <div className="mt-2 h-1 rounded-full bg-[var(--color-surface-elevated)]">
            <div className="h-1 w-2/3 rounded-full bg-[var(--color-primary)]" />
          </div>
        </div>
        <p className="text-base font-semibold leading-snug">
          Энэ шинэ бүтээгдэхүүнийг найздаа санал болгох уу?
        </p>
        <ul className="flex flex-col gap-2">
          {OPTIONS.map((option, index) => {
            const selected = index === SELECTED_OPTION;
            return (
              <li
                key={option}
                className={
                  selected
                    ? "flex items-center justify-between gap-2 rounded-xl border-[1.6px] border-[var(--color-primary)] bg-[var(--color-surface-elevated)] px-3 py-2.5 text-sm"
                    : "rounded-xl border border-[var(--color-divider)] bg-[var(--color-surface)] px-3 py-2.5 text-sm text-[var(--color-text-secondary)]"
                }
              >
                {option}
                {selected ? (
                  <Check
                    size={16}
                    strokeWidth={3}
                    className="text-[var(--color-primary)]"
                  />
                ) : null}
              </li>
            );
          })}
        </ul>
      </div>
    </div>
  );
}
