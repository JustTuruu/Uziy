import { FOOTER } from "@/lib/content";

export function SiteFooter({ year }: { year: number }) {
  return (
    <footer className="border-t border-[var(--color-divider)] px-4 py-10 sm:px-6">
      <div className="mx-auto flex max-w-6xl flex-col gap-2 text-sm text-[var(--color-text-muted)] sm:flex-row sm:justify-between">
        <p>{FOOTER.tagline}</p>
        <p>
          © {year} Uziy. {FOOTER.rights}
        </p>
      </div>
    </footer>
  );
}
