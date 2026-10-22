import { ArrowUp } from "lucide-react";
import { FOOTER } from "@/lib/content";

export function SiteFooter({ year }: { year: number }) {
  return (
    <footer className="container site-footer">
      <div>
        <a className="brand" href="#top">
          uziy<span className="brand-dot">.</span>
        </a>
        <p>{FOOTER.tagline}</p>
      </div>
      <div className="footer-right">
        <a href="#top">
          {FOOTER.backToTop} <ArrowUp size={14} aria-hidden />
        </a>
        <p>
          © {year} Uziy. {FOOTER.rights}
        </p>
      </div>
    </footer>
  );
}
