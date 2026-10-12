import { cn } from "@uziy/ui";

interface SectionProps {
  id?: string;
  title: string;
  lead?: string;
  className?: string;
  children: React.ReactNode;
}

/** Shared frame of every landing section: centred column, heading, lead text. */
export function Section({ id, title, lead, className, children }: SectionProps) {
  return (
    <section id={id} className={cn("px-4 py-16 sm:px-6 sm:py-24", className)}>
      <div className="mx-auto max-w-6xl">
        <h2 className="max-w-2xl text-2xl font-semibold tracking-tight sm:text-4xl">
          {title}
        </h2>
        {lead ? (
          <p className="mt-3 max-w-2xl text-base text-[var(--color-text-secondary)]">
            {lead}
          </p>
        ) : null}
        <div className="mt-10">{children}</div>
      </div>
    </section>
  );
}
