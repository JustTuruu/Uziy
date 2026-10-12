import { cn } from "@uziy/ui";

interface SectionProps {
  id?: string;
  eyebrow?: string;
  title: string;
  lead?: string;
  className?: string;
  children: React.ReactNode;
}

/** Shared frame of every landing section: eyebrow, serif heading, lead text, content. */
export function Section({ id, eyebrow, title, lead, className, children }: SectionProps) {
  return (
    <section id={id} className={cn("px-4 py-20 sm:px-6 sm:py-28", className)}>
      <div className="mx-auto max-w-6xl">
        <div className="reveal max-w-2xl">
          {eyebrow ? (
            <p className="mb-4 flex items-center gap-3 text-xs font-semibold uppercase tracking-[0.2em] text-[var(--color-primary)]">
              <span className="h-px w-8 bg-[var(--color-primary)]" />
              {eyebrow}
            </p>
          ) : null}
          <h2 className="font-display text-3xl font-semibold leading-tight sm:text-5xl">
            {title}
          </h2>
          {lead ? (
            <p className="mt-4 text-lg text-[var(--color-text-secondary)]">{lead}</p>
          ) : null}
        </div>
        <div className="mt-14">{children}</div>
      </div>
    </section>
  );
}
