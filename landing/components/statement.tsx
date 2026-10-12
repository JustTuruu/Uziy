import { STATEMENT } from "@/lib/content";

/** One big editorial sentence between the practical sections. */
export function Statement() {
  return (
    <section className="relative overflow-hidden px-4 py-24 sm:px-6 sm:py-36">
      <div
        aria-hidden
        className="absolute left-1/2 top-1/2 -z-10 size-[560px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-[radial-gradient(closest-side,rgb(245_197_24/0.09),transparent)]"
      />
      <p className="reveal font-display mx-auto max-w-4xl text-center text-4xl font-medium leading-[1.15] sm:text-6xl">
        {STATEMENT.lead} <span className="accent">{STATEMENT.accent}</span>{" "}
        {STATEMENT.tail}
      </p>
    </section>
  );
}
