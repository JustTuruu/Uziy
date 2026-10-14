import {
  Target,
  MessageCircle,
  Clock3,
  ShieldCheck,
  ArrowUpRight,
} from "lucide-react";
import { BENEFITS } from "@/lib/content";
const icons = {
  target: Target,
  message: MessageCircle,
  timer: Clock3,
  shield: ShieldCheck,
};
export function Benefits() {
  return (
    <section id="benefits" className="benefits-section">
      <div className="container benefits-layout">
        <div className="benefits-intro">
          <p className="eyebrow">ЯАГААД UZIY ГЭЖ?</p>
          <h2>
            Танд хамаатай.
            <br />
            Танаас эхтэй.
          </h2>
          <p>
            Таны өдөр тутмын сонголт брэндүүдэд илүү сайн шийдвэр гаргахад
            тусална.
          </p>
          <div className="opinion-art" aria-hidden>
            <span>“</span>
            <p>Миний бодлоор...</p>
            <ArrowUpRight size={42} />
          </div>
        </div>
        <div className="benefit-list">
          {BENEFITS.map((b) => {
            const Icon = icons[b.icon];
            return (
              <article key={b.title}>
                <span className="benefit-icon">
                  <Icon size={22} />
                </span>
                <div>
                  <h3>{b.title}</h3>
                  <p>{b.text}</p>
                </div>
              </article>
            );
          })}
        </div>
      </div>
    </section>
  );
}
