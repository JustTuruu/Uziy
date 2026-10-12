import { Play } from "lucide-react";

const OPTIONS = ["Тийм, сонирхож байна", "Магадгүй", "Үгүй"];

/**
 * Decorative phone that loops the whole experience in 12 s: watch an
 * introduction, answer a question, done. Pure CSS keyframes (see globals.css),
 * so it costs no JavaScript; under reduce-motion it rests on the finished state.
 */
export function PhoneDemo() {
  return (
    <div aria-hidden className="relative mx-auto w-[272px] sm:w-[292px]">
      <div className="glow-pulse absolute -inset-16 -z-10 rounded-full bg-[radial-gradient(closest-side,rgb(245_197_24/0.28),transparent)] blur-2xl" />

      <div className="rounded-[2.75rem] border border-[var(--color-border-strong)] bg-gradient-to-b from-[#1b1f27] to-[#0d0f13] p-[10px] shadow-[0_40px_90px_rgb(0_0_0/0.6),0_0_0_1px_rgb(255_255_255/0.04)_inset]">
        <div className="relative h-[540px] overflow-hidden rounded-[2.2rem] bg-[var(--color-background)]">
          <div className="absolute left-1/2 top-2.5 z-10 h-[22px] w-[86px] -translate-x-1/2 rounded-full bg-black" />

          {/* 1 · introduction video */}
          <div className="demo-screen-video absolute inset-0 flex flex-col px-5 pb-7 pt-14">
            <div className="relative grid flex-1 place-items-center overflow-hidden rounded-2xl border border-[var(--color-divider)] bg-[radial-gradient(circle_at_30%_20%,rgb(245_197_24/0.35),transparent_55%),linear-gradient(160deg,#1d222b,#0e1015)]">
              <div className="absolute size-44 rounded-full border border-[rgb(245_197_24/0.25)]" />
              <div className="absolute size-28 rounded-full border border-[rgb(245_197_24/0.4)]" />
              <span className="grid size-14 place-items-center rounded-full bg-[var(--color-primary)] text-[#14110a] shadow-[0_0_40px_rgb(245_197_24/0.5)]">
                <Play size={22} fill="currentColor" />
              </span>
            </div>
            <div className="mt-4">
              <p className="text-[11px] uppercase tracking-widest text-[var(--color-text-muted)]">
                Танилцуулга
              </p>
              <p className="mt-1 text-sm font-semibold">Шинэ бүтээгдэхүүн</p>
              <div className="mt-3 h-1 overflow-hidden rounded-full bg-[var(--color-surface-elevated)]">
                <div className="demo-progress h-full rounded-full bg-[var(--color-primary)]" />
              </div>
            </div>
          </div>

          {/* 2 · survey question */}
          <div className="demo-screen-question absolute inset-0 flex flex-col gap-4 px-5 pb-7 pt-14">
            <div>
              <p className="text-[11px] text-[var(--color-text-muted)]">Асуулт 2 / 3</p>
              <div className="mt-2 h-1 rounded-full bg-[var(--color-surface-elevated)]">
                <div className="h-1 w-2/3 rounded-full bg-[var(--color-primary)]" />
              </div>
            </div>
            <p className="font-display text-xl font-semibold leading-snug">
              Энэ бүтээгдэхүүнийг найздаа санал болгох уу?
            </p>
            <ul className="flex flex-col gap-2.5">
              {OPTIONS.map((option, index) => (
                <li
                  key={option}
                  className={
                    index === 0
                      ? "demo-pick rounded-xl border border-[var(--color-divider)] px-3.5 py-3 text-sm"
                      : "rounded-xl border border-[var(--color-divider)] bg-[var(--color-surface)] px-3.5 py-3 text-sm text-[var(--color-text-secondary)]"
                  }
                >
                  {option}
                </li>
              ))}
            </ul>
          </div>

          {/* 3 · done */}
          <div className="demo-screen-done absolute inset-0 flex flex-col items-center justify-center gap-6 px-6 text-center">
            <span className="demo-badge grid size-20 place-items-center rounded-3xl border-[1.6px] border-[var(--color-primary)] bg-[var(--color-surface-elevated)] shadow-[0_0_48px_rgb(245_197_24/0.4)]">
              <svg viewBox="0 0 64 64" className="size-full" fill="none">
                <path
                  className="demo-check"
                  pathLength={1}
                  d="M18 33 L28 43 L46 23"
                  stroke="var(--color-primary)"
                  strokeWidth="4.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </span>
            <div>
              <p className="font-display text-2xl font-semibold">Баярлалаа!</p>
              <p className="mt-2 text-sm text-[var(--color-text-secondary)]">
                Таны санал компанид хүрлээ
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Floating targeting chips: who the introduction is for. */}
      <span className="float-a absolute -left-14 top-24 hidden rounded-full border border-[var(--color-border-strong)] bg-[var(--color-surface-elevated)]/90 px-3.5 py-1.5 text-xs shadow-xl backdrop-blur sm:block">
        Нас <b className="text-[var(--color-primary)]">18–24</b>
      </span>
      <span className="float-b absolute -right-12 top-52 hidden rounded-full border border-[var(--color-border-strong)] bg-[var(--color-surface-elevated)]/90 px-3.5 py-1.5 text-xs shadow-xl backdrop-blur sm:block">
        Улаанбаатар
      </span>
      <span className="float-c absolute -left-10 bottom-28 hidden rounded-full border border-[var(--color-border-strong)] bg-[var(--color-surface-elevated)]/90 px-3.5 py-1.5 text-xs shadow-xl backdrop-blur sm:block">
        2–3 асуулт
      </span>
    </div>
  );
}
