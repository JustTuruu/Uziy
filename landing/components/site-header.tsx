import Image from "next/image";
import { ArrowUpRight } from "lucide-react";
import { NAV_LINKS } from "@/lib/content";
export function SiteHeader({ companyPanelUrl }: { companyPanelUrl: string }) {
  return (
    <header className="site-header">
      <div className="container header-inner">
        <a className="brand" href="#top" aria-label="Uziy нүүр">
          <Image src="/logo.png" alt="" width={34} height={34} />
          <span>
            uziy<span className="brand-dot">.</span>
          </span>
        </a>
        <nav aria-label="Үндсэн цэс">
          {NAV_LINKS.map((l) => (
            <a key={l.href} href={l.href}>
              {l.label}
            </a>
          ))}
        </nav>
        <a
          className="button button-quiet header-company"
          href={companyPanelUrl}
        >
          Компанийн самбар <ArrowUpRight size={16} aria-hidden />
        </a>
      </div>
    </header>
  );
}
