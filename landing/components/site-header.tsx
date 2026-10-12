import Image from "next/image";
import { ButtonLink } from "@uziy/ui";
import { NAV_LINKS } from "@/lib/content";

export function SiteHeader({ companyPanelUrl }: { companyPanelUrl: string }) {
  return (
    <header className="sticky top-0 z-20 border-b border-[var(--color-divider)] bg-[color-mix(in_oklab,var(--color-background)_85%,transparent)] backdrop-blur">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-4 px-4 sm:px-6">
        <a href="#top" className="flex items-center gap-2 font-semibold">
          <Image src="/logo.png" alt="" width={28} height={28} />
          Uziy
        </a>
        <nav aria-label="Үндсэн цэс" className="hidden gap-6 md:flex">
          {NAV_LINKS.map((link) => (
            <a
              key={link.href}
              href={link.href}
              className="text-sm text-[var(--color-text-secondary)] transition-colors hover:text-[var(--color-text-primary)]"
            >
              {link.label}
            </a>
          ))}
        </nav>
        <ButtonLink href={companyPanelUrl} variant="secondary" size="md">
          Компаниудад
        </ButtonLink>
      </div>
    </header>
  );
}
