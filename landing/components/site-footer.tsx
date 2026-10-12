import Image from "next/image";
import { FOOTER } from "@/lib/content";

export function SiteFooter({ year }: { year: number }) {
  return (
    <footer className="border-t border-[var(--color-divider)] px-4 py-12 sm:px-6">
      <div className="mx-auto flex max-w-6xl flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-3">
          <Image src="/logo.png" alt="" width={28} height={28} />
          <p className="max-w-xs text-sm text-[var(--color-text-secondary)]">{FOOTER.tagline}</p>
        </div>
        <p className="text-sm text-[var(--color-text-muted)]">
          © {year} Uziy. {FOOTER.rights}
        </p>
      </div>
    </footer>
  );
}
