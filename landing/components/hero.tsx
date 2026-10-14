import { ArrowDown, ArrowUpRight, Check } from "lucide-react";
import type { SiteLinks } from "@/lib/links";
import { PhoneDemo } from "./phone-demo";
export function Hero({ links }: { links: SiteLinks }) {
  const available = Boolean(links.appStore || links.playStore);
  return (
    <section id="top" className="hero container">
      <div className="hero-copy">
        <p className="eyebrow">
          <span className="status-dot" /> ТАНЫ САНАЛ. ШИНЭ БОЛОМЖ.
        </p>
        <h1>
          Зүгээр үзээд
          <br />
          өнгөрөх үү?
          <br />
          <span>
            Санал бодлоо
            <br />
            хуваалцаарай.
          </span>
        </h1>
        <p className="hero-description">
          Сонирхолтой брэндүүдтэй танилцаж, богино асуултад хариулаарай. Илүү
          сайн бүтээгдэхүүн таны саналаас эхэлнэ.
        </p>
        <div className="hero-actions">
          <a className="button button-primary" href="#download">
            {available ? "Uziy апп татах" : "Апптай танилцах"}
            <ArrowUpRight size={19} />
          </a>
          <a className="text-link" href="#how">
            Хэрхэн ажилладаг вэ? <ArrowDown size={16} />
          </a>
        </div>
        <p className="hero-note">
          <Check size={15} /> Богино видео <span>·</span> 2–3 асуулт{" "}
          <span>·</span> Таны бодит санал
        </p>
      </div>
      <div className="hero-stage">
        <div className="stage-orbit" aria-hidden />
        <span className="stage-label">БРЭНД ↔ ТА</span>
        <PhoneDemo />
        <div className="stage-caption">
          <span>01 — ҮЗ. ХАРИУЛ. НӨЛӨӨЛ.</span>
          <span>UZIY EXPERIENCE</span>
        </div>
      </div>
    </section>
  );
}
