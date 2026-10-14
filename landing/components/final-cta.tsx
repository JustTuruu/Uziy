import { ArrowUpRight } from "lucide-react";
import type { SiteLinks } from "@/lib/links";
import { StoreButtons } from "./store-buttons";
export function FinalCta({ links }: { links: SiteLinks }) {
  return (
    <section id="download" className="download-section">
      <div className="container download-inner">
        <div>
          <p className="eyebrow">ДАРААГИЙН САЙН САНАА ТАНААС</p>
          <h2>
            Үзье. Бодъё.
            <br />
            Хуваалцъя.
            <ArrowUpRight aria-hidden />
          </h2>
        </div>
        <div className="download-copy">
          <p>
            Танд хамаатай брэндүүдийг
            <br />
            Uziy-тай хамт нээгээрэй.
          </p>
          <StoreButtons links={links} />
          {!links.appStore && !links.playStore && (
            <small>Апп дэлгүүрүүдэд удахгүй нээгдэнэ.</small>
          )}
        </div>
      </div>
    </section>
  );
}
